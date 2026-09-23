let
    Джерело = Excel.CurrentWorkbook(){[Name="tblRegistryPath"]}[Content],
    ПеревіреніКолонки = fxValidateColumns(Джерело, {"Шлях", "Призначення"}, "tblRegistryPath"),
    #"Видалено пусті" = Table.SelectRows(
        ПеревіреніКолонки,
        each [Шлях] <> null and [Шлях] <> ""
    ),
    #"Додано вміст" = Table.AddColumn(
        #"Видалено пусті",
        "Content",
        each
            let
                Path = Text.Trim([Шлях]),
                Attempt = try File.Contents(Path)
            in
                if Attempt[HasError] then
                    error Error.Record(
                        "ПомилкаЧитанняФайлу",
                        "Не вдалося прочитати файл для «" & Text.From([Призначення]) & "» за шляхом «" & Path & "».",
                        Attempt[Error][Message]
                    )
                else
                    Attempt[Value],
        type binary
    )
in
    #"Додано вміст"
