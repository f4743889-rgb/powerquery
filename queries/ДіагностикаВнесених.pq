let
    Settings = cfgSettings,
    InCols = cfgSchema[Внесені],
    BalCols = cfgSchema[Вихід],

    // Безпечне завантаження табличних джерел
    LoadSource = (srcVal, srcName) =>
        let
            Attempt = try srcVal
        in
            if Attempt[HasError] then
                [ Data = #table({}, {}), Error = "Зверніть увагу: запит «" & srcName & "» завершився помилкою: " & Attempt[Error][Message] ]
            else
                [ Data = Attempt[Value], Error = null ],

    // Безпечне завантаження скалярних параметрів
    LoadParam = (srcVal, srcName) =>
        let
            Attempt = try srcVal
        in
            if Attempt[HasError] then
                [ Value = null, Error = "Зверніть увагу: параметр «" & srcName & "» завершився помилкою: " & Attempt[Error][Message] ]
            else
                [ Value = Attempt[Value], Error = null ],

    InSrc = LoadSource(АналізВнесених, "АналізВнесених"),
    BalSrc = LoadSource(Залишок, "Залишок"),
    DiffSrc = LoadSource(РозбіжностіВнесених, "РозбіжностіВнесених"),

    DocTypeSrc = LoadParam(pDocumentType, "pDocumentType"),
    MVOSrc = LoadParam(pMVO, "pMVO"),
    ReportDateRawSrc = LoadParam(pReportDateRaw, "pReportDateRaw"),
    ReportDateSrc = LoadParam(pReportDate, "pReportDate"),

    // Перевірка єдиного значення через параметри
    CheckSingleValue = (paramVal, actualList, desc, cellName) =>
        if paramVal = null then
            "У книзі не заповнено іменований діапазон «" & cellName & "»."
        else if List.IsEmpty(actualList) then
            "У файлі не вдалося визначити " & desc & "."
        else if not List.Contains(actualList, paramVal) then
            "У файлі немає рядків зі значенням " & desc & " = «" & Text.From(paramVal) & "»."
        else
            null,

    // Безпечне читання колонок
    SafeTableColumn = (tbl as any, colName as text) as list =>
        if tbl = null then
            {}
        else if Table.IsEmpty(tbl) then
            {}
        else
            try Table.Column(tbl, colName) otherwise {},

    // Аналіз
    InUniqueDoc = List.Distinct(List.RemoveNulls(List.Transform(SafeTableColumn(InSrc[Data], InCols[ТипДокумента]), Text.From))),
    InUniqueMVO = List.Distinct(List.RemoveNulls(List.Transform(SafeTableColumn(InSrc[Data], InCols[Постачальник]), Text.From))),

    MsgType =
        if InSrc[Error] <> null then
            null
        else if DocTypeSrc[Error] <> null then
            DocTypeSrc[Error]
        else
            CheckSingleValue(DocTypeSrc[Value], InUniqueDoc, "тип документа", Settings[NameDocumentType]),

    MsgMVO =
        if InSrc[Error] <> null then
            null
        else if MVOSrc[Error] <> null then
            MVOSrc[Error]
        else
            CheckSingleValue(MVOSrc[Value], InUniqueMVO, "МВО", Settings[NameMVO]),

    NegBalCount =
        if BalSrc[Error] <> null or BalSrc[Data] = null then
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
            "У запиті «Залишок» знайдено від’ємні значення (" & Text.From(NegBalCount) & " рядк.)."
        else
            null,

    NotesCount =
        if BalSrc[Error] <> null or BalSrc[Data] = null then
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
            "У запиті «Залишок» є " & Text.From(NotesCount) & " рядк. із заповненою приміткою."
        else
            null,

    DiffCount =
        if DiffSrc[Error] <> null or DiffSrc[Data] = null then
            0
        else
            Table.RowCount(DiffSrc[Data]),

    MsgDiff =
        if DiffCount > 0 then
            "Знайдено " & Text.From(DiffCount) & " розбіжностей у «РозбіжностіВнесених»."
        else
            null,

    // Розрізнення "клітинка порожня" від "клітинка містить значення, яке не вдалось розпізнати як дату";
    // у другому випадку pReportDate теж повертає null, і фільтр за датою звіту в Оборотна.pq мовчки вимикається
    RawReportDate = ReportDateRawSrc[Value],
    MsgReportDate =
        if ReportDateRawSrc[Error] <> null then
            ReportDateRawSrc[Error]
        else if ReportDateSrc[Error] <> null then
            ReportDateSrc[Error]
        else if RawReportDate <> null and ReportDateSrc[Value] = null then
            "У клітинці «" & Settings[NameReportDate] & "» вказано значення («" & RawReportDate & "»), але його не вдалося розпізнати як дату."
        else
            null,

    AllMessages = List.RemoveNulls({ InSrc[Error], BalSrc[Error], DiffSrc[Error], MsgType, MsgMVO, MsgNeg, MsgNotes, MsgDiff, MsgReportDate })
in
    #table(type table [Повідомлення = text], List.Transform(AllMessages, each { _ }))
