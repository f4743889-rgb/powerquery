/*
fxDiagnosticsTable
Перетворення списку стандартизованих діагностичних записів у таблицю для виводу.
*/

(diagnostics as list) as table =>
let
    ValidDiagnostics = List.Select(
        diagnostics,
        each _ <> null and Value.Is(_, type record)
    ),
    Rows = List.Transform(
        ValidDiagnostics,
        each {
            Record.FieldOrDefault(_, "Severity", "Info"),
            Record.FieldOrDefault(_, "Code", "Unknown"),
            Record.FieldOrDefault(_, "Source", ""),
            Record.FieldOrDefault(_, "Message", ""),
            Record.FieldOrDefault(_, "Detail", null)
        }
    )
in
    #table(
        type table [
            Рівень = text,
            Код = text,
            Джерело = text,
            Повідомлення = text,
            Деталі = nullable text
        ],
        Rows
    )
