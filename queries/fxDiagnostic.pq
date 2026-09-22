/*
fxDiagnostic
Створення стандартизованого діагностичного повідомлення.
*/

(severity as text, code as text, source as text, message as text, optional detail as nullable text) as record =>
let
    SeverityMap = cfgSettings[DiagnosticSeverity],
    NormalizedSeverity =
        if severity = null then
            SeverityMap[Info]
        else
            let
                s = Text.Trim(Text.From(severity))
            in
                if List.Contains(Record.FieldValues(SeverityMap), s) then
                    s
                else
                    SeverityMap[Info],
    NormalizedCode = if code = null then "UNKNOWN" else Text.Trim(Text.From(code)),
    NormalizedSource = if source = null then "" else Text.Trim(Text.From(source)),
    NormalizedMessage = if message = null then "" else Text.Trim(Text.From(message)),
    NormalizedDetail = if detail = null then null else Text.Trim(Text.From(detail))
in
    [
        Severity = NormalizedSeverity,
        Code = NormalizedCode,
        Source = NormalizedSource,
        Message = NormalizedMessage,
        Detail = NormalizedDetail
    ]
