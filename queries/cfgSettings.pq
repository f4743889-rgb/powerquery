/*
cfgSettings
Централізовані параметри обробки та глобальні константи.
*/

let
    Settings = [
        // Параметри CSV
        CsvDelimiter = ";",
        CsvEncoding = 1251,

        // Маски та маркери
        ConfirmationAccountStart = "1815",
        ConfirmationAccountEnd = "5600",
        MarkerInvoice = "Накладна; ",

        // Формати та довжини
        DateFormat = "dd.MM.yyyy",
        AccountLength = 4,
        PartyDateLength = 8,

        // Округлення
        PriceRoundDigits = 2,
        QtyRoundDigits = 3,
        AmountRoundDigits = 2,

        // Іменовані клітинки Excel
        NameDocumentType = "ТипДокумента",
        NameMVO = "МВО",
        NameReportDate = "ДатаЗвіту",

        // Діагностика
        DiagnosticSeverity = [
            Error = "Error",
            Warning = "Warning",
            Info = "Info"
        ],
        DiagnosticSeverityOrder = [
            Error = 1,
            Warning = 2,
            Info = 3
        ]
    ]
in
    Settings
