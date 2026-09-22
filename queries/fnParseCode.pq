/*
fnParseCode
Парсер номера та дати з текстового коду.
*/

(txt as any) as record =>
let
    t = if txt = null then "" else Text.Trim(Text.From(txt)),
    parts = Text.Split(t, ";"),
    okParts = List.Count(parts) = 2,

    numPart  = if okParts then Text.Trim(parts{0}) else null,
    datePart = if okParts then Text.Trim(parts{1}) else null,

    slashParts = if numPart <> null then Text.Split(numPart, "/") else null,
    okSlash    = slashParts <> null and List.Count(slashParts) = 2,

    leftPart  = if okSlash then slashParts{0} else null,
    rightRaw  = if okSlash then slashParts{1} else null,
    rightPart = if rightRaw <> null then Text.Remove(rightRaw, {"-"}) else null,

    dashParts = if leftPart <> null then Text.Split(leftPart, "-") else null,
    okDash    = dashParts <> null and List.Count(dashParts) = 2,

    n1Text = if okDash then dashParts{0} else null,
    n2Text = if okDash then dashParts{1} else null,
    n3Text = rightPart,

    isDigits = (s as nullable text) as logical =>
        s <> null and Text.Length(s) > 0 and Text.Select(s, {"0".."9"}) = s,

    okNums = okDash and isDigits(n1Text) and isDigits(n2Text) and isDigits(n3Text),
    dateVal = try Date.FromText(datePart, "uk-UA") otherwise (try Date.FromText(datePart) otherwise null),
    isValid = okParts and okSlash and okDash and okNums and dateVal <> null
in
    [
        IsValid   = isValid,
        Num1      = if isValid then Number.FromText(n1Text) else null,
        Num2      = if isValid then Number.FromText(n2Text) else null,
        Num3      = if isValid then Number.FromText(n3Text) else null,
        DateValue = if isValid then dateVal else null
    ]