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
            // List.Distinct з двопараметричним компаратором (a, b) => ... тут не підтримується
            // ("настроюваний засіб порівняння"). Замість цього — функція-селектор ключа (1 параметр).
            Unique = List.Distinct(
                Collected,
                each Text.Combine({ [Severity], [Code], [Source], [Message] }, "||")
            )
in
            Unique
