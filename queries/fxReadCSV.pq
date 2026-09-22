/*
fxReadCSV
Уніфікований зчитувач CSV-файлів за завантаженим вмістом та шаблоном.
*/

(filePurpose as text, templateTable as table) as table =>
let
    Source = ЗавантаженіФайли,
    FileRow = Table.SelectRows(Source, each [Призначення] = filePurpose),
    Content = if Table.IsEmpty(FileRow) then null else FileRow{0}[Content],
    
    RawData = 
        if Content = null then
            templateTable
        else
            let
                Attempt = try Csv.Document(Content, [Delimiter = cfgSettings[CsvDelimiter], Encoding = cfgSettings[CsvEncoding]])
            in
                if Attempt[HasError] then
                    error Error.Record("ПомилкаЧитанняCSV", "Не вдалося прочитати CSV-файл для " & filePurpose, Attempt[Error][Message])
                else
                    Table.PromoteHeaders(Attempt[Value], [PromoteAllScalars = true]),

    ExpectedCols = Table.ColumnNames(templateTable),
    Validated = fxValidateColumns(RawData, ExpectedCols, filePurpose),
    
    NonEmpty = Table.SelectRows(
        Validated,
        (row) => List.MatchesAny(Record.FieldValues(row), (v) => v <> null and Text.Trim(Text.From(v)) <> "")
    ),

    TemplateFields = Type.RecordFields(Type.TableRow(Value.Type(templateTable))),
    TypesList = List.Transform(Record.FieldNames(TemplateFields), (col) => { col, Record.Field(TemplateFields, col)[Type] }),
    // Можемо вказати культуру uk-UA для коректного розпізнавання дат і чисел
    Typed = Table.TransformColumnTypes(NonEmpty, TypesList) //, "uk-UA")
in
    Typed