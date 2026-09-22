/*
fxApplyTemplateTypes
Перевіряє структуру таблиці та застосовує типи, визначені шаблоном.
*/

(tbl as table, templateTable as table, sourceName as text) as table =>
let
    ExpectedCols = Table.ColumnNames(templateTable),
    Validated = fxValidateColumns(tbl, ExpectedCols, sourceName),
    TemplateFields = Type.RecordFields(Type.TableRow(Value.Type(templateTable))),
    TypesList = List.Transform(
        Record.FieldNames(TemplateFields),
        (col) => { col, Record.Field(TemplateFields, col)[Type] }
    )
in
    Table.TransformColumnTypes(Validated, TypesList)
