/*
fxGetSingleFileContent
Повертає вміст єдиного файлу за його призначенням або null, якщо файл не задано.
*/

(filePurpose as text) as nullable binary =>
let
    Source = fxValidateColumns(
        ЗавантаженіФайли,
        {"Призначення", "Content", "ErrorCode", "ErrorMessage", "ErrorDetail"},
        "ЗавантаженіФайли"
    ),
    FileRows = Table.SelectRows(Source, each [Призначення] = filePurpose),
    FileCount = Table.RowCount(FileRows),
    FileRow = if FileCount = 1 then FileRows{0} else null
in
    if FileCount > 1 then
        error Error.Record(
            "ДубльованеПризначенняФайлу",
            "Для призначення «" & filePurpose & "» знайдено кілька файлів.",
            FileCount
        )
    else if FileCount = 0 then
        null
    else if FileRow[ErrorCode] <> null then
        error Error.Record(
            FileRow[ErrorCode],
            FileRow[ErrorMessage],
            FileRow[ErrorDetail]
        )
    else
        FileRow[Content]