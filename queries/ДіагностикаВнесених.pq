let
    Settings = cfgSettings,
    InCols = cfgSchema[Внесені],
    BalCols = cfgSchema[Вихід],

    // Безпечне завантаження джерел
    LoadSource = (srcVal, srcName) =>
        let
            Attempt = try srcVal
        in
            if Attempt[HasError] then [ Data = #table({}, {}), Error = "Зверніть увагу: запит «" & srcName & "» завершився помилкою: " & Attempt[Error][Message] ]
            else [ Data = Attempt[Value], Error = null ],

    InSrc = LoadSource(АналізВнесених, "АналізВнесених"),
    BalSrc = LoadSource(Залишок, "Залишок"),
    DiffSrc = LoadSource(РозбіжностіВнесених, "РозбіжностіВнесених"),

    // Перевірка єдиного значення через параметри
    CheckSingleValue = (paramVal, actualList, desc, cellName) =>
        if paramVal = null then "У книзі не заповнено іменований діапазон «" & cellName & "»."
        else if List.IsEmpty(actualList) then "У файлі не вдалося визначити " & desc & "."
        else if not List.Contains(actualList, paramVal) then "У файлі немає рядків зі значенням " & desc & " = «" & Text.From(paramVal) & "»."
        else null,

    // Аналіз
    InUniqueDoc = List.Distinct(List.RemoveNulls(List.Transform(Table.Column(InSrc[Data], InCols[ТипДокумента]) ?? {}, Text.From))),
    InUniqueMVO = List.Distinct(List.RemoveNulls(List.Transform(Table.Column(InSrc[Data], InCols[Постачальник]) ?? {}, Text.From))),

    MsgType = if InSrc[Error] <> null then null else CheckSingleValue(pDocumentType, InUniqueDoc, "тип документа", Settings[NameDocumentType]),
    MsgMVO = if InSrc[Error] <> null then null else CheckSingleValue(pMVO, InUniqueMVO, "МВО", Settings[NameMVO]),

    NegBalCount = Table.RowCount(Table.SelectRows(BalSrc[Data], each Record.Field(_, BalCols[Залишок]) <> null and Record.Field(_, BalCols[Залишок]) < 0)),
    MsgNeg = if NegBalCount > 0 then "У запиті «Залишок» знайдено від’ємні значення (" & Text.From(NegBalCount) & " рядк.)." else null,

    NotesCount = Table.RowCount(Table.SelectRows(BalSrc[Data], each Record.Field(_, BalCols[Примітка]) <> null and Text.Trim(Text.From(Record.Field(_, BalCols[Примітка]))) <> "")),
    MsgNotes = if NotesCount > 0 then "У запиті «Залишок» є " & Text.From(NotesCount) & " рядк. із заповненою приміткою." else null,

    DiffCount = Table.RowCount(DiffSrc[Data]),
    MsgDiff = if DiffCount > 0 then "Знайдено " & Text.From(DiffCount) & " розбіжностей у «РозбіжностіВнесених»." else null,

    // Розрізнення "клітинка порожня" від "клітинка містить значення, яке не вдалось розпізнати як дату";
    // pReportDate у другому випадку теж повертає null, і фільтр за датою звіту в Оборотна.pq мовчки вимикається.
    // Значення береться з ізольованого запиту pReportDateRaw (не напряму з fxReadNamedCell),
    // щоб не поєднувати пряме звернення до Excel.CurrentWorkbook з посиланнями на CSV-джерела в цьому ж запиті (Formula.Firewall)
    RawReportDate = pReportDateRaw,
    MsgReportDate = if RawReportDate <> null and pReportDate = null then
        "У клітинці «" & Settings[NameReportDate] & "» вказано значення («" & RawReportDate & "»), але його не вдалося розпізнати як дату. Фільтр за датою звіту в «Оборотна» буде проігноровано."
    else null,

    AllMessages = List.RemoveNulls({ InSrc[Error], BalSrc[Error], DiffSrc[Error], MsgType, MsgMVO, MsgNeg, MsgNotes, MsgDiff, MsgReportDate })
in
    #table(type table [Повідомлення = text], List.Transform(AllMessages, each { _ }))