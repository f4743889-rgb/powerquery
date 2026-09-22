/*
pMVO
Окремий запит для зчитування МВО з Excel.
Ізольований від джерел CSV для уникнення Formula.Firewall.
*/
let
    Val = fxReadNamedCell(cfgSettings[NameMVO])
in
    Val
