let
    Cols = cfgSchema[Реєстр],
    Settings = cfgSettings,
    Content = fxGetSingleFileContent("Файл користувача"),

    WorkbookData = 
        if Content = null then ШаблонРеєстр else Table.SelectRows(Excel.Workbook(Content, null, true), each [Kind] = "Table"),

    // Вибір таблиці за структурою
    SelectedTable = 
        if Content = null then 
            WorkbookData 
        else 
            let
                Expected = Table.ColumnNames(ШаблонРеєстр),
                Matching = Table.SelectRows(WorkbookData, each List.ContainsAll(Table.ColumnNames([Data]), Expected))
            in
                if Table.RowCount(Matching) = 1 then Matching{0}[Data]
                else error Error.Record("ПомилкаТаблиці", "Не знайдено або знайдено кілька відповідних таблиць у файлі."),

    // Спочатку перевіряємо структуру та типи, а вже потім звертаємося до поля назви.
    // Так помилка про відсутню колонку буде зрозумілою та прив’язаною до джерела.
    Typed = fxApplyTemplateTypes(SelectedTable, ШаблонРеєстр, "Файл користувача"),
    CleanText = Table.TransformColumns(Typed, {{ Cols[Назва], each fxCleanText(_), type text }}),
    
    // Рядки проміжних підсумків містять текст у «№ з/п» і після типізації є помилковими.
    // Їх виключення є погодженим правилом бізнес-розрахунку, а не помилкою джерела.
    NoErrors = Table.RemoveRowsWithErrors(CleanText, { Cols[Номер] }),
    NonEmpty = Table.SelectRows(
        NoErrors,
        (r) => List.MatchesAny(Record.FieldValues(r), (v) => v <> null and Text.Trim(Text.From(v)) <> "")
    ),
    
    RoundedPrice = Table.TransformColumns(NonEmpty, {{ Cols[Ціна], each fxSafeNumberRound(_, Settings[PriceRoundDigits]), type nullable number }}),

    Grouped = Table.Group(
        RoundedPrice,
        { Cols[Номер], Cols[Назва], Cols[Номенклатура], Cols[Ціна], Cols[Дата] },
        {
            { Cols[Кількість], each List.Sum(Table.Column(_, Cols[Кількість])), type number },
            { cfgSchema[Вихід][Сума], each List.Sum(Table.Column(_, Cols[Сума])), type number }
        }
    ),

    Sorted = Table.Sort(Grouped, List.Transform({ Cols[Номер], Cols[Назва], Cols[Номенклатура], Cols[Ціна], Cols[Дата] }, each { _, Order.Ascending })),

    Renamed = Table.RenameColumns(Sorted, {{ Cols[Номенклатура], cfgSchema[Вихід][Номенклатура] }})
in
    Renamed
