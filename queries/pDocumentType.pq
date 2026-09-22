/*
pDocumentType
Окремий запит для зчитування типу документа з Excel.
Ізольований від джерел CSV для уникнення Formula.Firewall.
*/
let
    Val = fxReadNamedCell(cfgSettings[NameDocumentType])
in
    Val
