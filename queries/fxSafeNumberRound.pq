/*
fxSafeNumberRound
Безпечно округлює числове значення; null та значення, що не приводяться до числа,
залишаються null.
*/

(value as any, digits as number) as nullable number =>
    if value = null then
        null
    else
        try Number.Round(Number.From(value), digits) otherwise null
