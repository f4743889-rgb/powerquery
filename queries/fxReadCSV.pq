/*
fxReadCSV
Уніфікований зчитувач CSV-файлів за завантаженим вмістом та шаблоном.
*/

(filePurpose as text, templateTable as table) as table =>
let
    Source = ЗавантаженіФайли,
    FileRows = Table.SelectRows(Source, each [Призначення] = filePurpose),
    FileCount = Table.RowCount(FileRows),

    _ValidateFileCount =
        if FileCount > 1 then
            error Error.Record(
                "ДубльованеПризначенняФайлу",
                "Для призначення «" & filePurpose & "» знайдено кілька файлів.",
                FileCount
            )
        else
            null,

    Content = if FileCount = 0 then null else FileRows{0}[Content],

    RawData =
        if Content = null then
            templateTable
        else
            let
                Attempt = try Csv.Document(
                    Content,
                    [Delimiter = cfgSettings[CsvDelimiter], Encoding = cfgSettings[CsvEncoding]]
                )
            in
                if Attempt[HasError] then
                    error Error.Record(
                        "ПомилкаЧитанняCSV",
                        "Не вдалося прочитати CSV-файл для " & filePurpose,
                        Attempt[Error][Message]
                    )
                else
                    Table.PromoteHeaders(Attempt[Value], [PromoteAllScalars = true]),

    ExpectedCols = Table.ColumnNames(templateTable),
    Validated = fxValidateColumns(RawData, ExpectedCols, filePurpose),

    NonEmpty = Table.SelectRows(
        Validated,
        (row) =>
            List.MatchesAny(
                Record.FieldValues(row),
                (v) => v <> null and Text.Trim(Text.From(v)) <> ""
            )
    ),

    TemplateFields = Type.RecordFields(Type.TableRow(Value.Type(templateTable))),
    TypesList = List.Transform(
        Record.FieldNames(TemplateFields),
        (col) => { col, Record.Field(TemplateFields, col)[Type] }
    ),
    Typed = Table.TransformColumnTypes(NonEmpty, TypesList)
in
    Typed
