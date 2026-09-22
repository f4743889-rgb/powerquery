let
    Settings = cfgSettings,
    InCols = cfgSchema[Внесені],
    BalCols = cfgSchema[Вихід],

    // Стандартизоване створення діагностичних записів
    Diagnostic = fxDiagnostic,

    // Безпечне завантаження табличних джерел.
    // Помилка не втрачається: вона перетворюється на структурований запис.
    LoadSource = (srcVal, srcName) =>
        let
            Attempt = try srcVal
        in
            if Attempt[HasError] then
                [
                    Data = null,
                    Diagnostic = Diagnostic(
                        "Error",
                        "SOURCE_QUERY_FAILED",
                        srcName,
                        "Запит «" & srcName & "» завершився помилкою.",
                        Attempt[Error][Message]
                    )
                ]
            else
                [ Data = Attempt[Value], Diagnostic = null ],

    // Безпечне завантаження скалярних параметрів.
    LoadParam = (srcVal, srcName) =>
        let
            Attempt = try srcVal
        in
            if Attempt[HasError] then
                [
                    Value = null,
                    Diagnostic = Diagnostic(
                        "Error",
                        "PARAMETER_READ_FAILED",
                        srcName,
                        "Не вдалося прочитати параметр «" & srcName & "».",
                        Attempt[Error][Message]
                    )
                ]
            else
                [ Value = Attempt[Value], Diagnostic = null ],

    InSrc = LoadSource(АналізВнесених, "АналізВнесених"),
    BalSrc = LoadSource(Залишок, "Залишок"),
    DiffSrc = LoadSource(РозбіжностіВнесених, "РозбіжностіВнесених"),

    DocTypeSrc = LoadParam(pDocumentType, "pDocumentType"),
    MVOSrc = LoadParam(pMVO, "pMVO"),
    ReportDateRawSrc = LoadParam(pReportDateRaw, "pReportDateRaw"),
    ReportDateSrc = LoadParam(pReportDate, "pReportDate"),

    CheckSingleValue = (paramVal, actualList, desc, cellName) =>
        if paramVal = null then
            Diagnostic(
                "Warning",
                "PARAMETER_EMPTY",
                cellName,
                "У книзі не заповнено іменований діапазон «" & cellName & "».",
                null
            )
        else if List.IsEmpty(actualList) then
            Diagnostic(
                "Warning",
                "VALUE_NOT_FOUND",
                "АналізВнесених",
                "У файлі не вдалося визначити " & desc & ".",
                null
            )
        else if not List.Contains(actualList, paramVal) then
            Diagnostic(
                "Warning",
                "PARAMETER_VALUE_NOT_FOUND",
                "АналізВнесених",
                "У файлі немає рядків зі значенням " & desc & " = «" & Text.From(paramVal) & "».",
                null
            )
        else
            null,

    SafeTableColumn = (tbl as any, colName as text) as list =>
        if tbl = null then
            {}
        else
            try Table.Column(tbl, colName) otherwise {},

    InUniqueDoc = List.Distinct(
        List.RemoveNulls(
            List.Transform(SafeTableColumn(InSrc[Data], InCols[ТипДокумента]), Text.From)
        )
    ),
    InUniqueMVO = List.Distinct(
        List.RemoveNulls(
            List.Transform(SafeTableColumn(InSrc[Data], InCols[Постачальник]), Text.From)
        )
    ),

    MsgType =
        if InSrc[Diagnostic] <> null then null
        else if DocTypeSrc[Diagnostic] <> null then DocTypeSrc[Diagnostic]
        else CheckSingleValue(DocTypeSrc[Value], InUniqueDoc, "тип документа", Settings[NameDocumentType]),

    MsgMVO =
        if InSrc[Diagnostic] <> null then null
        else if MVOSrc[Diagnostic] <> null then MVOSrc[Diagnostic]
        else CheckSingleValue(MVOSrc[Value], InUniqueMVO, "МВО", Settings[NameMVO]),

    NegBalCount =
        if BalSrc[Data] = null then
            0
        else
            Table.RowCount(
                Table.SelectRows(
                    BalSrc[Data],
                    each
                        let
                            v = try Record.Field(_, BalCols[Залишок]) otherwise null
                        in
                            v <> null and v < 0
                )
            ),
    MsgNeg =
        if NegBalCount > 0 then
            Diagnostic(
                "Warning",
                "NEGATIVE_BALANCE",
                "Залишок",
                "У запиті «Залишок» знайдено від’ємні значення (" & Text.From(NegBalCount) & " рядк.).",
                null
            )
        else null,

    NotesCount =
        if BalSrc[Data] = null then
            0
        else
            Table.RowCount(
                Table.SelectRows(
                    BalSrc[Data],
                    each
                        let
                            v = try Record.Field(_, BalCols[Примітка]) otherwise null
                        in
                            v <> null and Text.Trim(Text.From(v)) <> ""
                )
            ),
    MsgNotes =
        if NotesCount > 0 then
            Diagnostic(
                "Info",
                "BALANCE_NOTES_PRESENT",
                "Залишок",
                "У запиті «Залишок» є " & Text.From(NotesCount) & " рядк. із заповненою приміткою.",
                null
            )
        else null,

    DiffCount =
        if DiffSrc[Data] = null then 0 else Table.RowCount(DiffSrc[Data]),
    MsgDiff =
        if DiffCount > 0 then
            Diagnostic(
                "Warning",
                "REGISTER_DIFFERENCES",
                "РозбіжностіВнесених",
                "Знайдено " & Text.From(DiffCount) & " розбіжностей у «РозбіжностіВнесених».",
                null
            )
        else null,

    RawReportDate = ReportDateRawSrc[Value],
    MsgReportDate =
        if ReportDateRawSrc[Diagnostic] <> null then
            ReportDateRawSrc[Diagnostic]
        else if ReportDateSrc[Diagnostic] <> null then
            ReportDateSrc[Diagnostic]
        else if RawReportDate <> null and ReportDateSrc[Value] = null then
            Diagnostic(
                "Warning",
                "REPORT_DATE_INVALID",
                Settings[NameReportDate],
                "У клітинці «" & Settings[NameReportDate] & "» вказано значення («" & Text.From(RawReportDate) & "»), але його не вдалося розпізнати як дату.",
                null
            )
        else null,

    AllDiagnostics = List.RemoveNulls({
        InSrc[Diagnostic],
        BalSrc[Diagnostic],
        DiffSrc[Diagnostic],
        MsgType,
        MsgMVO,
        MsgNeg,
        MsgNotes,
        MsgDiff,
        MsgReportDate
    })
in
    fxDiagnosticsTable(AllDiagnostics)
