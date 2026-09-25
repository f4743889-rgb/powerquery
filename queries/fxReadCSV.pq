/*
fxReadCSV
Уніфікований зчитувач CSV-файлів за завантаженим вмістом та шаблоном.
*/

(filePurpose as text, templateTable as table) as table =>
let
    Content = fxGetSingleFileContent(filePurpose),

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

    Validated = fxValidateColumns(RawData, Table.ColumnNames(templateTable), filePurpose),
    TemplateOnly = Table.SelectColumns(Validated, Table.ColumnNames(templateTable)),

    NonEmpty = Table.SelectRows(
        TemplateOnly,
        (row) =>
            List.MatchesAny(
                Record.FieldValues(row),
                (v) => v <> null and Text.Trim(Text.From(v)) <> ""
            )
    ),

    Typed = fxApplyTemplateTypes(NonEmpty, templateTable, filePurpose)
in
    Typed
