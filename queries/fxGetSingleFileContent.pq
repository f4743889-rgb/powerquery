/*
fxGetSingleFileContent
Повертає вміст єдиного файлу за його призначенням або null, якщо файл не задано.
*/

(filePurpose as text) as nullable binary =>
let
    Source = fxValidateColumns(ЗавантаженіФайли, { "Призначення", "Content" }, "ЗавантаженіФайли"),
    FileRows = Table.SelectRows(Source, each [Призначення] = filePurpose),
    FileCount = Table.RowCount(FileRows)
in
    if FileCount > 1 then
        error Error.Record(
            "ДубльованеПризначенняФайлу",
            "Для призначення «" & filePurpose & "» знайдено кілька файлів.",
            FileCount
        )
    else if FileCount = 0 then
        null
    else
        FileRows{0}[Content]
