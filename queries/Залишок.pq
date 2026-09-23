let
    ColsOSV = cfgSchema[ОСВ],
    ColsReg = cfgSchema[Реєстр],
    Out = cfgSchema[Вихід],
    Settings = cfgSettings,

    ParseFields = [ Valid = "IsValid", N1 = "Num1", N2 = "Num2", N3 = "Num3", Date = "DateValue" ],
    ParseColsList = Record.FieldValues(ParseFields),

    OSVData = fxValidateColumns(Оборотна, Record.FieldValues(ColsOSV), "Оборотна"),
    RegData = fxValidateColumns(РеєстрЗведений, { ColsReg[Номер], ColsReg[Назва], Out[Номенклатура], ColsReg[Ціна], ColsReg[Дата], ColsReg[Кількість] }, "РеєстрЗведений"),

    FifoColumns = {
        ColsOSV[ДатаПартії],
        ParseFields[Date],
        ParseFields[N1],
        ParseFields[N2],
        ParseFields[N3],
        ColsOSV[НомерПартії]
    },

    PartyCols = List.Distinct({
        ColsOSV[Номенклатура],
        ColsOSV[ОдиницяВиміру],
        ColsOSV[Ціна],
        ColsOSV[Постачальник],
        ColsOSV[РахунокКороткий],
        ColsOSV[Найменування],
        ColsOSV[ДатаПартії],
        ColsOSV[НомерПартії],
        Out[КількістьОблік]
    } & ParseColsList),

    SortByAvailableColumns = (tbl as table, columnNames as list) as table =>
        let
            Available = List.Select(
                columnNames,
                each Value.Is(_, type text) and List.Contains(Table.ColumnNames(tbl), _)
            ),
            Criteria = List.Transform(Available, each { _, Order.Ascending })
        in
            if List.IsEmpty(Criteria) then tbl else Table.Sort(tbl, Criteria),

    fnRunningSum = (lst as list) as list =>
        let
            n = List.Count(lst)
        in
            if n = 0 then
                {}
            else
                List.Generate(
                    () => [i = 0, s = lst{0}],
                    each [i] < n,
                    each [i = [i] + 1, s = [s] + (if [i] + 1 < n then lst{[i] + 1} else 0)],
                    each [s]
                ),

    ProcessPosition = (posRows as table) as table =>
        let
            DocsRaw = Table.Distinct(
                Table.SelectColumns(
                    Table.SelectRows(posRows, each Record.Field(_, Out[ДатаДокумента]) <> null),
                    { ColsReg[Номер], Out[ДатаДокумента], Out[КількістьСписанняРядка] }
                )
            ),
            Docs = SortByAvailableColumns(DocsRaw, { Out[ДатаДокумента], ColsReg[Номер] }),
            TotalWriteOff = List.Sum(Table.Column(Docs, Out[КількістьСписанняРядка])) ?? 0,

            PartiesRaw = Table.Distinct(Table.SelectColumns(posRows, PartyCols)),
            Parties = SortByAvailableColumns(PartiesRaw, FifoColumns),
            PartiesIndexed = Table.AddIndexColumn(Parties, "Idx", 0, 1),
            LastIdx = Table.RowCount(PartiesIndexed) - 1,
            QtyRunning = List.Buffer(fnRunningSum(Table.Column(PartiesIndexed, Out[КількістьОблік]))),
            QtyAcc = Table.AddColumn(PartiesIndexed, "AccQty", each QtyRunning{[Idx]}, type number),

            PartiesWriteOff = Table.AddColumn(
                QtyAcc,
                Out[КількістьСписання],
                each
                    let
                        qAcc = Record.Field(_, Out[КількістьОблік]),
                        rem = TotalWriteOff - ([AccQty] - qAcc)
                    in
                        if rem <= 0 then 0
                        else if [Idx] = LastIdx then rem
                        else if rem >= qAcc then qAcc
                        else rem,
                type number
            ),

            PartiesRem = Table.AddColumn(
                PartiesWriteOff,
                Out[Залишок],
                each Record.Field(_, Out[КількістьОблік]) - Record.Field(_, Out[КількістьСписання]),
                type number
            ),

            DocsIndexed = Table.AddIndexColumn(Docs, "DocIdx", 0, 1),
            DocQtyRunning = List.Buffer(fnRunningSum(Table.Column(DocsIndexed, Out[КількістьСписанняРядка]))),
            DocsAcc = Table.AddColumn(DocsIndexed, "AccDocQty", each DocQtyRunning{[DocIdx]}, type number),

            WORunning = List.Buffer(fnRunningSum(Table.Column(PartiesRem, Out[КількістьСписання]))),
            PartiesNote = Table.AddColumn(
                PartiesRem,
                Out[Примітка],
                (p) =>
                    let
                        pDate = Record.Field(p, ColsOSV[ДатаПартії]),
                        pWO = Record.Field(p, Out[КількістьСписання]),
                        prevWO = WORunning{p[Idx]} - pWO,
                        TargetDocs = Table.SelectRows(
                            DocsAcc,
                            each [AccDocQty] > prevWO and ([AccDocQty] - Record.Field(_, Out[КількістьСписанняРядка])) < (prevWO + pWO)
                        ),
                        EarlyDates = if pDate = null then {} else List.Select(Table.Column(TargetDocs, Out[ДатаДокумента]), each _ < pDate)
                    in
                        if pWO = 0 or List.IsEmpty(EarlyDates) then
                            null
                        else
                            "Дата видачі (" & Text.Combine(List.Transform(EarlyDates, each Date.ToText(_, Settings[DateFormat])), ", ") & ") менша за дату отримання (" & Text.From(pDate) & ").",
                type text
            )
        in
            Table.RemoveColumns(PartiesNote, { "Idx", "AccQty" }),

    PrepOSV = Table.RenameColumns(OSVData, { { ColsOSV[КількістьКін], Out[КількістьОблік] } }),
    SafeAfterDelimiter = (v as any, delim as text) as nullable text =>
        if v = null then null else try Text.AfterDelimiter(Text.From(v), delim) otherwise null,
    WithInvoice = Table.AddColumn(
        PrepOSV,
        Out[Накладна],
        each SafeAfterDelimiter(Record.Field(_, ColsOSV[Аналітика5]), Settings[MarkerInvoice]),
        type nullable text
    ),
    WithParse = Table.ExpandRecordColumn(
        Table.AddColumn(WithInvoice, "_Parse", each fnParseCode(Record.Field(_, Out[Накладна]))),
        "_Parse",
        ParseColsList,
        ParseColsList
    ),
    TypedParse = Table.TransformColumnTypes(
        WithParse,
        { { ParseFields[Date], type date }, { ParseFields[N1], Int64.Type }, { ParseFields[N2], Int64.Type }, { ParseFields[N3], Int64.Type } }
    ),

    JoinedReg = Table.NestedJoin(
        TypedParse,
        { ColsOSV[Номенклатура], ColsOSV[Найменування], ColsOSV[Ціна] },
        RegData,
        { Out[Номенклатура], ColsReg[Назва], ColsReg[Ціна] },
        "_Reg",
        JoinKind.LeftOuter
    ),
    ExpandedReg = Table.ExpandTableColumn(
        JoinedReg,
        "_Reg",
        { ColsReg[Номер], ColsReg[Кількість], ColsReg[Дата] },
        { ColsReg[Номер], Out[КількістьСписанняРядка], Out[ДатаДокумента] }
    ),
    ZeroReg = Table.ReplaceValue(ExpandedReg, null, 0, Replacer.ReplaceValue, { Out[КількістьСписанняРядка] }),

    SortedForFifo = SortByAvailableColumns(
        ZeroReg,
        { ColsOSV[Найменування], ColsOSV[Номенклатура] } & FifoColumns
    ),
    GroupedFifo = Table.Group(
        SortedForFifo,
        { ColsOSV[Номенклатура], ColsOSV[Найменування], ColsOSV[Ціна] },
        { { "_Data", ProcessPosition, type table } }
    ),

    // IsValid та інші технічні поля розгортаються до фільтрації.
    ExpandCols = List.Distinct({
        ColsOSV[ОдиницяВиміру],
        ColsOSV[Постачальник],
        Out[Накладна],
        ColsOSV[РахунокКороткий],
        ColsOSV[ДатаПартії],
        Out[КількістьСписання],
        Out[Залишок],
        Out[Примітка]
    } & ParseColsList),
    ExpandedResult = Table.ExpandTableColumn(GroupedFifo, "_Data", ExpandCols),
    CleanedZero = Table.ReplaceValue(ExpandedResult, 0, null, Replacer.ReplaceValue, { Out[КількістьСписання] }),

    InvalidInv = Table.SelectRows(CleanedZero, each Record.Field(_, ParseFields[Valid]) <> true),
    ValidInv = SortByAvailableColumns(
        Table.SelectRows(CleanedZero, each Record.Field(_, ParseFields[Valid]) = true),
        { ParseFields[Date], ParseFields[N1], ParseFields[N2], ParseFields[N3] }
    ),
    Combined = Table.Combine({ InvalidInv, ValidInv }),
    FinalCols = {
        ColsOSV[Постачальник],
        Out[Накладна],
        ColsOSV[РахунокКороткий],
        ColsOSV[Найменування],
        ColsOSV[Номенклатура],
        ColsOSV[ОдиницяВиміру],
        ColsOSV[ДатаПартії],
        Out[КількістьОблік],
        Out[КількістьСписання],
        Out[Залишок],
        Out[Примітка]
    }
in
    Table.ReorderColumns(Table.RemoveColumns(Combined, ParseColsList), FinalCols)
