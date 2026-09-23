let
    Джерело = Excel.CurrentWorkbook(){[Name="tblRegistryPath"]}[Content],
    ПеревіреніКолонки = fxValidateColumns(Джерело, {"Шлях", "Призначення"}, "tblRegistryPath"),
    #"Видалено пусті" = Table.SelectRows(
        ПеревіреніКолонки,
        each [Шлях] <> null and Text.Trim(Text.From([Шлях])) <> ""
    ),
    #"Додано вміст" = Table.AddColumn(
        #"Видалено пусті",
        "FileResult",
        each
            let
                Path = Text.Trim(Text.From([Шлях])),
                Attempt = try File.Contents(Path)
            in
                if Attempt[HasError] then
                    [
                        Content = null,
                        ErrorCode = "ПомилкаЧитанняФайлу",
                        ErrorMessage = "Не вдалося прочитати файл для «" & Text.From([Призначення]) & "» за шляхом «" & Path & "».",
                        ErrorDetail = Attempt[Error][Message]
                    ]
                else
                    [
                        Content = Attempt[Value],
                        ErrorCode = null,
                        ErrorMessage = null,
                        ErrorDetail = null
                    ],
        type record
    ),
    #"Розгорнуто результат" = Table.ExpandRecordColumn(
        #"Додано вміст",
        "FileResult",
        {"Content", "ErrorCode", "ErrorMessage", "ErrorDetail"},
        {"Content", "ErrorCode", "ErrorMessage", "ErrorDetail"}
    )
in
    #"Розгорнуто результат"