/*
fxIsConfirmationAccount
Перевірка, чи належить рахунок до категорій підтвердження.
Бізнес-правило: у вхідних даних рахунок має 16 символів; він є
підтверджуючим, лише якщо одночасно починається з 1815 та закінчується на 5600.
*/

(account as nullable text) as logical =>
    account <> null 
    and Text.StartsWith(account, cfgSettings[ConfirmationAccountStart]) 
    and Text.EndsWith(account, cfgSettings[ConfirmationAccountEnd])
