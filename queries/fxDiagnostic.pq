/*
fxDiagnostic
Створення стандартизованого діагностичного повідомлення.
*/

(severity as text, code as text, source as text, message as text, optional detail as nullable text) as record =>
[
    Severity = severity,
    Code = code,
    Source = source,
    Message = message,
    Detail = if detail = null then null else detail
]
