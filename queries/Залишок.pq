let
    ColsOSV = cfgSchema[ОСВ],
    ColsReg = cfgSchema[Реєстр],
    Out = cfgSchema[Вихід],
    Settings = cfgSettings,

    ParseFields = [ Valid = "IsValid", N1 = "Num1", N2 = "Num2", N3 = "Num3", Date = "DateValue" ],
    ParseColsList = Record.FieldValues(ParseFields),

    OSVData = fxValidateColumns(Оборотна, Record.FieldValues(ColsOSV), "Оборотна"),
    RegData = fxValidateColumns(РеєстрЗведений, {ColsReg[Назва], Out[Номенклатура], ColsReg[Ціна], ColsReg[Дата], ColsReg[Кількість]}, "РеєстрЗведений"),

    // Сортування FIFO
    FifoOrder = {
        { ColsOSV[ДатаПартії], Order.Ascending },
        { ParseFields[Date], Order.Ascending },
        { ParseFields[N1], Order.Ascending },
        { ParseFields[N2], Order.Ascending },
        { ParseFields[N3], Order.Ascending },
        { ColsOSV[НомерПартії], Order.Ascending }
    },

    PartyCols = List.Distinct({ ColsOSV[Номенклатура], ColsOSV[ОдиницяВиміру], ColsOSV[Ціна], ColsOSV[Постачальник], ColsOSV[РахунокКороткий], ColsOSV[НомерПартії], ColsOSV[ДатаПартії], Out[КількістьОблік], Out[Накладна] } & ParseColsList & List.Transform(FifoOrder, each _{0})),

    // Накопичувальна сума за один прохід (O(n)) замість List.FirstN+List.Sum на кожному рядку (O(n^2))
    fnRunningSum = (lst as list) as list =>
        let
            n = List.Count(lst)
        in
            if n = 0 then {}
            else List.Generate(
                () => [i = 0, s = lst{0}],
                each [i] < n,
                each [i = [i] + 1, s = [s] + (if [i] + 1 < n then lst{[i] + 1} else 0)],
                each [s]
            ),

    // Локальна функція розрахунку позиції
    ProcessPosition = (posRows as table) as table =>
        let
            Docs = Table.Sort(Table.Distinct(Table.SelectColumns(Table.SelectRows(posRows, each Record.Field(_, Out[ДатаДокумента]) <> null), { Out[ДатаДокумента], Out[КількістьСписанняРядка] })), {{ Out[ДатаДокумента], Order.Ascending }}),
            TotalWriteOff = List.Sum(Table.Column(Docs, Out[КількістьСписанняРядка])) ?? 0,

            Parties = Table.Sort(Table.Distinct(Table.SelectColumns(posRows, PartyCols)), FifoOrder),
            PartiesIndexed = Table.AddIndexColumn(Parties, "Idx", 0, 1),
            LastIdx = Table.RowCount(PartiesIndexed) - 1,
            QtyRunning = List.Buffer(fnRunningSum(Table.Column(PartiesIndexed, Out[КількістьОблік]))),
            QtyAcc = Table.AddColumn(PartiesIndexed, "AccQty", each QtyRunning{[Idx]}, type number),

            PartiesWriteOff = Table.AddColumn(QtyAcc, Out[КількістьСписання], each 
                let 
                    qAcc = Record.Field(_, Out[КількістьОблік]),
                    rem = TotalWriteOff - ([AccQty] - qAcc)
                in 
                    if rem <= 0 then 0 
                    else if [Idx] = LastIdx then rem 
                    else if rem >= qAcc then qAcc 
                    else rem, type number
            ),

            PartiesRem = Table.AddColumn(PartiesWriteOff, Out[Залишок], each Record.Field(_, Out[КількістьОблік]) - Record.Field(_, Out[КількістьСписання]), type number),

            DocsIndexed = Table.AddIndexColumn(Docs, "DocIdx", 0, 1),
            DocQtyRunning = List.Buffer(fnRunningSum(Table.Column(DocsIndexed, Out[КількістьСписанняРядка]))),
            DocsAcc = Table.AddColumn(DocsIndexed, "AccDocQty", each DocQtyRunning{[DocIdx]}, type number),

            WORunning = List.Buffer(fnRunningSum(Table.Column(PartiesRem, Out[КількістьСписання]))),
            PartiesNote = Table.AddColumn(PartiesRem, Out[Примітка], (p) =>
                let
                    pDate = Record.Field(p, ColsOSV[ДатаПартії]),
                    pWO = Record.Field(p, Out[КількістьСписання]),
                    prevWO = WORunning{p[Idx]} - pWO,
                    
                    TargetDocs = Table.SelectRows(DocsAcc, each [AccDocQty] > prevWO and ([AccDocQty] - Record.Field(_, Out[КількістьСписанняРядка])) < (prevWO + pWO)),
                    EarlyDates = if pDate = null then {} else List.Select(Table.Column(TargetDocs, Out[ДатаДокумента]), each _ < pDate)
                in
                    if pWO = 0 or List.IsEmpty(EarlyDates) then null
                    else "Дата видачі (" & Text.Combine(List.Transform(EarlyDates, each Date.ToText(_, Settings[DateFormat])), ", ") & ") менша за дату отримання (" & Date.ToText(pDate, Settings[DateFormat]) & ")",
                type text
            )
        in
            Table.RemoveColumns(PartiesNote, {"Idx", "AccQty"}),

    // Підготовка даних
    PrepOSV = Table.RenameColumns(OSVData, {{ ColsOSV[КількістьКін], Out[КількістьОблік] }}),
    WithInvoice = Table.AddColumn(PrepOSV, Out[Накладна], each Text.AfterDelimiter(Record.Field(_, ColsOSV[Аналітика5]), Settings[MarkerInvoice]), type text),
    WithParse = Table.ExpandRecordColumn(Table.AddColumn(WithInvoice, "_Parse", each fnParseCode(Record.Field(_, Out[Накладна]))), "_Parse", ParseColsList, ParseColsList),
    TypedParse = Table.TransformColumnTypes(WithParse, {{ ParseFields[Date], type date }, { ParseFields[N1], Int64.Type }, { ParseFields[N2], Int64.Type }, { ParseFields[N3], Int64.Type }}),

    JoinedReg = Table.NestedJoin(TypedParse, { ColsOSV[Номенклатура], ColsOSV[Найменування], ColsOSV[Ціна] }, RegData, { Out[Номенклатура], ColsReg[Назва], ColsReg[Ціна] }, "_Reg", JoinKind.LeftOuter),
    ExpandedReg = Table.ExpandTableColumn(JoinedReg, "_Reg", { ColsReg[Кількість], ColsReg[Дата] }, { Out[КількістьСписанняРядка], Out[ДатаДокумента] }),
    ZeroReg = Table.ReplaceValue(ExpandedReg, null, 0, Replacer.ReplaceValue, { Out[КількістьСписанняРядка] }),

    SortedForFifo = Table.Sort(ZeroReg, { { ColsOSV[Найменування], Order.Ascending }, { ColsOSV[Номенклатура], Order.Ascending } } & FifoOrder),
    GroupedFifo = Table.Group(SortedForFifo, { ColsOSV[Номенклатура], ColsOSV[Найменування], ColsOSV[Ціна] }, {{ "_Data", ProcessPosition, type table }}),
    
    ExpandCols = { ColsOSV[ОдиницяВиміру], ColsOSV[Постачальник], Out[Накладна], ColsOSV[РахунокКороткий], ColsOSV[ДатаПартії], Out[КількістьОблік], Out[КількістьСписання], Out[Залишок], Out[Примітка] } & ParseColsList,
    ExpandedResult = Table.ExpandTableColumn(GroupedFifo, "_Data", ExpandCols),
    CleanedZero = Table.ReplaceValue(ExpandedResult, 0, null, Replacer.ReplaceValue, { Out[КількістьСписання] }),

    // Фінальне сортування
    InvalidInv = Table.SelectRows(CleanedZero, each Record.Field(_, ParseFields[Valid]) <> true),
    ValidInv = Table.Sort(Table.SelectRows(CleanedZero, each Record.Field(_, ParseFields[Valid]) = true), { { ParseFields[Date], Order.Ascending }, { ParseFields[N1], Order.Ascending }, { ParseFields[N2], Order.Ascending }, { ParseFields[N3], Order.Ascending }, { ColsOSV[Найменування], Order.Ascending } }),
    
    Combined = Table.Combine({ InvalidInv, ValidInv }),
    FinalCols = { ColsOSV[Постачальник], Out[Накладна], ColsOSV[РахунокКороткий], ColsOSV[Найменування], ColsOSV[Номенклатура], ColsOSV[ОдиницяВиміру], ColsOSV[Ціна], ColsOSV[ДатаПартії], Out[КількістьОблік], Out[КількістьСписання], Out[Залишок], Out[Примітка] }
in
    Table.ReorderColumns(Table.RemoveColumns(Combined, ParseColsList), FinalCols)