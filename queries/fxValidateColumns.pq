/*
fxValidateColumns
Перевірка наявності обов’язкових колонок у таблиці.
*/

(tbl as table, requiredCols as list, sourceName as text) as table =>
let
    Missing = List.Difference(requiredCols, Table.ColumnNames(tbl))
in
    if List.IsEmpty(Missing) then
        tbl
    else
        error Error.Record(
            "НемаОбовязковихКолонок",
            "У джерелі «" & sourceName & "» відсутні обов’язкові колонки: " & Text.Combine(Missing, ", ") & "."
        )