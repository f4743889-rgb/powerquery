/*
pReportDateRaw
Сире (нерозпізнане) значення клітинки ДатаЗвіту — лише для діагностики.
Ізольований від джерел CSV, як і інші p*-запити (уникнення Formula.Firewall).
*/
let
    Val = fxReadNamedCell(cfgSettings[NameReportDate])
in
    Val