let
    Settings = cfgSettings,
    InCols = cfgSchema[Внесені],
    BalCols = cfgSchema[Вихід],

    // Внутрішня оболонка для створення записів
    Diagnostic = fxDiagnostic,

    // Визначаємо шаблонний режим для ключових файлів
    MissingFileDiagnostics = {
        if Table.RowCount(Table.SelectRows(ЗавантаженіФайли, each [Призначення] = "Внесені документи")) = 0 then
            Diagnostic(
                Settings[DiagnosticSeverity][Info],
                "TEMPLATE_USED",
                "АналізВнесених",
                "Для «Внесені документи» використано шаблон, оскільки реальний файл не задано.",
                null
            )
        else null,

        if Table.RowCount(Table.SelectRows(ЗавантаженіФайли, each [Призначення] = "Оборотна відомість")) = 0 then
            Diagnostic(
                Settings[DiagnosticSeverity][Info],
                "TEMPLATE_USED",
                "Оборотна",
                "Для «Оборотна відомість» використано шаблон, оскільки реальний файл не задано.",
                null
            )
        else null
    },

    // Безпечне завантаження табличних джерел
    LoadSource = (srcVal, srcName) =>
        let
            Attempt = try srcVal
        in
            if Attempt[HasError] then
                [
                    Data = null,
                    Diagnostic = Diagnostic(
                        Settings[DiagnosticSeverity][Error],
                        "SOURCE_QUERY_FAILED",
                        srcName,
                        "Запит «" & srcName & "» завершився помилкою.",
                        Attempt[Error][Message]
                    )
                ]
            else
                [ Data = Attempt[Value], Diagnostic = null ],

    // Безпечне завантаження параметрів
    LoadParam = (srcVal, srcName) =>
        let
            Attempt = try srcVal
        in
            if Attempt[HasError] then
                [
                    Value = null,
                    Diagnostic = Diagnostic(
                        Settings[DiagnosticSeverity][Error],
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
                Settings[DiagnosticSeverity][Warning],
                "PARAMETER_EMPTY",
                cellName,
                "У книзі не заповнено іменований діапазон «" & cellName & "».",
                null
            )
        else if List.IsEmpty(actualList) then
            Diagnostic(
                Settings[DiagnosticSeverity][Warning],
                "VALUE_NOT_FOUND",
                "АналізВнесених",
                "У файлі не вдалося визначити " & desc & ".",
                null
            )
        else if not List.Contains(actualList, paramVal) then
            Diagnostic(
                Settings[DiagnosticSeverity][Warning],
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
                Settings[DiagnosticSeverity][Warning],
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
                Settings[DiagnosticSeverity][Info],
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
                Settings[DiagnosticSeverity][Warning],
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
                Settings[DiagnosticSeverity][Warning],
                "REPORT_DATE_INVALID",
                Settings[NameReportDate],
                "У клітинці «" & Settings[NameReportDate] & "» вказано значення («" & Text.From(RawReportDate) & "»), але його не вдалося розпізнати як дату.",
                null
            )
        else null,

    // Правила якості даних для основних таблиць
    InRules = {
        [
            Severity = Settings[DiagnosticSeverity][Warning],
            Code = "EMPTY_DOC_TYPE",
            Message = "У таблиці є рядки з пустим типом документа.",
            Predicate = each try Record.Field(_, InCols[ТипДокумента]) otherwise null = null
        ],
        [
            Severity = Settings[DiagnosticSeverity][Warning],
            Code = "EMPTY_MVO",
            Message = "У таблиці є рядки з пустим МВО.",
            Predicate = each try Record.Field(_, InCols[Постачальник]) otherwise null = null
        ]
    },
    InQuality = fxCollectDataQualityDiagnostics(АналізВнесених, "АналізВнесених", InRules),

    BalRules = {
        [
            Severity = Settings[DiagnosticSeverity][Warning],
            Code = "NEGATIVE_BALANCE_RULE",
            Message = "Знайдено рядки з від’ємним залишком.",
            Predicate = each try Record.Field(_, BalCols[Залишок]) otherwise null <> null and Record.Field(_, BalCols[Залишок]) < 0
        ],
        [
            Severity = Settings[DiagnosticSeverity][Info],
            Code = "NOTE_PRESENT_RULE",
            Message = "Знайдено рядки з заповненою приміткою.",
            Predicate = each try Record.Field(_, BalCols[Примітка]) otherwise null <> null and Text.Trim(Text.From(Record.Field(_, BalCols[Примітка]))) <> ""
        ]
    },
    BalQuality = if BalSrc[Data] = null then {} else fxCollectDataQualityDiagnostics(BalSrc[Data], "Залишок", BalRules),

    DiffQuality =
        if DiffSrc[Data] = null then {}
        else if Table.RowCount(DiffSrc[Data]) = 0 then {}
        else { Diagnostic(Settings[DiagnosticSeverity][Info], "DIFF_TABLE_HAS_ROWS", "РозбіжностіВнесених", "Таблиця розбіжностей має рядки для перевірки.", null) },

    AllDiagnostics = List.RemoveNulls(List.Combine({
        MissingFileDiagnostics,
        { InSrc[Diagnostic], BalSrc[Diagnostic], DiffSrc[Diagnostic], MsgType, MsgMVO, MsgNeg, MsgNotes, MsgDiff, MsgReportDate },
        InQuality,
        BalQuality,
        DiffQuality
    }))
in
    fxDiagnosticsTable(AllDiagnostics)
