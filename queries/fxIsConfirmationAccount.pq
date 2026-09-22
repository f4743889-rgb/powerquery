/*
fxIsConfirmationAccount
Перевірка, чи належить рахунок до категорій підтвердження.
*/

(account as nullable text) as logical =>
    account <> null 
    and Text.StartsWith(account, cfgSettings[ConfirmationAccountStart]) 
    and Text.EndsWith(account, cfgSettings[ConfirmationAccountEnd])