let
    Джерело = Excel.CurrentWorkbook(){[Name="tblRegistryPath"]}[Content],
    #"Видалено пусті" = Table.SelectRows(
        Джерело, 
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

/*
let
    Джерело = Excel.CurrentWorkbook(){[Name="tblRegistryPath"]}[Content],
    #"Видалено пусті" = Table.SelectRows(
        Джерело, 
        each [Шлях] <> null and [Шлях] <> ""
    ),
    
    #"Додано вміст" = Table.AddColumn(
        #"Видалено пусті", 
        "Content", 
        each File.Contents(Text.Trim([Шлях])), 
        type binary
    )
    
in
    #"Додано вміст"
*/