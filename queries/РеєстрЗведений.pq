let
    Cols = cfgSchema[Реєстр],
    Settings = cfgSettings,
    Source = ЗавантаженіФайли,

    UserFile = Table.SelectRows(Source, each [Призначення] = "Файл користувача"),
    Content = if Table.IsEmpty(UserFile) then null else UserFile{0}[Content],

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

    // Обробка
    CleanText = Table.TransformColumns(SelectedTable, {{ Cols[Назва], each if _ = null then null else Text.Trim(Text.Clean(Text.From(_))), type text }}),
    TemplateFields = Type.RecordFields(Type.TableRow(Value.Type(ШаблонРеєстр))),
    Typed = Table.TransformColumnTypes(CleanText, List.Transform(Record.FieldNames(TemplateFields), (c) => { c, Record.Field(TemplateFields, c)[Type] })),
    
    NoErrors = Table.RemoveRowsWithErrors(Typed, { Cols[Номер] }),
    NonEmpty = Table.SelectRows(NoErrors, (r) => try List.MatchesAny(Record.FieldValues(r), (v) => v <> null and Text.Trim(Text.From(v)) <> "") otherwise true),
    
    RoundedPrice = Table.TransformColumns(NonEmpty, {{ Cols[Ціна], each if _ = null then null else Number.Round(_, Settings[PriceRoundDigits]), type number }}),

    Grouped = Table.Group(
        RoundedPrice,
        { Cols[Назва], Cols[Номенклатура], Cols[Ціна], Cols[Дата] },
        {
            { Cols[Кількість], each List.Sum(Table.Column(_, Cols[Кількість])), type number },
            { cfgSchema[Вихід][Сума], each List.Sum(Table.Column(_, Cols[Сума])), type number }
        }
    ),

    Sorted = Table.Sort(Grouped, List.Transform({ Cols[Назва], Cols[Номенклатура], Cols[Ціна], Cols[Дата] }, each { _, Order.Ascending })),

    Renamed = Table.RenameColumns(Sorted, {{ Cols[Номенклатура], cfgSchema[Вихід][Номенклатура] }})
in
    Renamed