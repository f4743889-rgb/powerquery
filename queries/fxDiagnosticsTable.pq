/*
fxDiagnosticsTable
Перетворення списку стандартизованих діагностичних записів у таблицю для виводу.
*/

(diagnostics as list) as table =>
let
    SeverityMap = cfgSettings[DiagnosticSeverity],
    SeverityOrder = cfgSettings[DiagnosticSeverityOrder],

    ValidDiagnostics = List.Select(diagnostics, each _ <> null and Value.Is(_, type record)),

    Normalized = List.Transform(
        ValidDiagnostics,
        each
            let
                r = _,
                RawSeverity = Record.FieldOrDefault(r, "Severity", SeverityMap[Info]),
                RawCode = Record.FieldOrDefault(r, "Code", "UNKNOWN"),
                RawSource = Record.FieldOrDefault(r, "Source", ""),
                RawMessage = Record.FieldOrDefault(r, "Message", ""),
                RawDetail = Record.FieldOrDefault(r, "Detail", null),
                SeverityText = if RawSeverity = null then SeverityMap[Info] else Text.Trim(Text.From(RawSeverity)),
                Severity = if List.Contains(Record.FieldValues(SeverityMap), SeverityText) then SeverityText else SeverityMap[Info],
                Code = if RawCode = null then "UNKNOWN" else Text.Trim(Text.From(RawCode)),
                Source = if RawSource = null then "" else Text.Trim(Text.From(RawSource)),
                Message = if RawMessage = null then "" else Text.Trim(Text.From(RawMessage)),
                Detail = if RawDetail = null then null else Text.Trim(Text.From(RawDetail))
            in
                [
                    Severity = Severity,
                    Code = Code,
                    Source = Source,
                    Message = Message,
                    Detail = Detail
                ]
    ),

    // Не використовуємо власний компаратор: Excel Power Query не підтримує
    // його в цьому контексті для List.Distinct/List.Sort.
    NormalizedTable = Table.FromRecords(
        Normalized,
        type table [
            Severity = text,
            Code = text,
            Source = text,
            Message = text,
            Detail = nullable text
        ]
    ),
    Deduped = Table.Distinct(NormalizedTable, {"Severity", "Code", "Source", "Message"}),
    WithSortOrder = Table.AddColumn(
        Deduped,
        "__SeverityOrder",
        each Record.FieldOrDefault(SeverityOrder, [Severity], 99),
        Int64.Type
    ),
    Sorted = Table.Sort(WithSortOrder, {{"__SeverityOrder", Order.Ascending}}),
    Rows = List.Transform(
        Table.ToRecords(Table.RemoveColumns(Sorted, {"__SeverityOrder"})),
        each {
            [Severity],
            [Code],
            [Source],
            [Message],
            [Detail]
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
