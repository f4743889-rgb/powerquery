/*
fxCollectDataQualityDiagnostics
Збирає лічильники рядків, що відповідають правилам якості даних.
Кожне правило містить Code, Severity, Message і Predicate (функція від рядка).
*/

(tbl as nullable table, sourceName as text, rules as list) as list =>
    if tbl = null then
        {}
    else
        let
            Collected =
                List.RemoveNulls(
                    List.Transform(
                        rules,
                        (rule as record) =>
                            let
                                Count = Table.RowCount(Table.SelectRows(tbl, (row) => try rule[Predicate](row) otherwise false))
                            in
                                if Count = 0 then
                                    null
                                else
                                    fxDiagnostic(
                                        rule[Severity],
                                        rule[Code],
                                        sourceName,
                                        rule[Message] & " (" & Text.From(Count) & " рядк.).",
                                        "Кількість рядків, що відповідають правилу: " & Text.From(Count)
                                    )
                    )
                ),
            Unique = List.Distinct(
                Collected,
                (a, b) =>
                    Text.Combine({ a[Severity], a[Code], a[Source], a[Message] }, "||")
                    =
                    Text.Combine({ b[Severity], b[Code], b[Source], b[Message] }, "||")
            )
in
            Unique
