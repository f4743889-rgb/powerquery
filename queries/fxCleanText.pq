/*
fxCleanText
Єдине безпечне очищення текстових значень із джерел.
*/

(value as any) as nullable text =>
    if value = null then
        null
    else
        Text.Trim(Text.Clean(Text.From(value)))
