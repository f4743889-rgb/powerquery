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

    Deduped = List.Distinct(
        Normalized,
        (a, b) =>
            Text.Combine({ a[Severity], a[Code], a[Source], a[Message] }, "||")
            =
            Text.Combine({ b[Severity], b[Code], b[Source], b[Message] }, "||")
    ),

    // У Power Query немає Number.Compare; компаратор має повертати -1, 0 або 1.
    Sorted = List.Sort(
        Deduped,
        (a, b) =>
            let
                aOrder = Record.FieldOrDefault(SeverityOrder, a[Severity], 99),
                bOrder = Record.FieldOrDefault(SeverityOrder, b[Severity], 99)
            in
                if aOrder < bOrder then -1
                else if aOrder > bOrder then 1
                else 0
    ),

    Rows = List.Transform(
        Sorted,
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
