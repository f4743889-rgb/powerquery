let
    Cols = cfgSchema[Внесені],
    Out = cfgSchema[Вихід],
    Settings = cfgSettings,

    SourceData = fxValidateColumns(АналізВнесених, Record.FieldValues(Cols), "АналізВнесених"),

    // Фільтрація підтверджуючих рахунків
    ConfirmRows = Table.SelectRows(SourceData, each fxIsConfirmationAccount(Record.Field(_, Cols[Рахунок]))),

    // Формування поля документа з універсальною обробкою типів дати
    WithDoc = Table.AddColumn(
        ConfirmRows,
        Out[ДокументПідтвердження],
        each 
            let
                RawDate = Record.Field(_, Cols[Дата]),
                FormattedDate = 
                    if RawDate is date then 
                        Date.ToText(RawDate, Settings[DateFormat])
                    else if RawDate is text then 
                        RawDate
                    else if RawDate = null then 
                        ""
                    else 
                        Text.From(RawDate)
            in
                Text.Combine({ 
                    Text.From(Record.Field(_, Cols[ТипДокумента]) ?? ""), 
                    Text.Combine({ Text.From(Record.Field(_, Cols[Префікс]) ?? ""), Text.From(Record.Field(_, Cols[Номер]) ?? "") }, "-"), 
                    FormattedDate 
                }, ";"),
        type text
    ),

    Grouped = Table.Group(
        WithDoc,
        { Cols[Аналітика5Назва], Cols[Аналітика5], Out[ДокументПідтвердження] },
        {{ Out[Сума], each List.Sum(Table.Column(_, Cols[Сума])), type nullable number }}
    ),

    ExtractInvoice = Table.TransformColumns(Grouped, {{ Cols[Аналітика5Назва], each Text.AfterDelimiter(_, Settings[MarkerInvoice]), type text }}),
    Renamed = Table.RenameColumns(ExtractInvoice, {{ Cols[Аналітика5Назва], Out[НакладнаНаПеУ] }}),
    Filtered = Table.SelectRows(Renamed, each Record.Field(_, Out[НакладнаНаПеУ]) <> null and Record.Field(_, Out[НакладнаНаПеУ]) <> "")
in
    Table.Sort(Filtered, {{ Out[НакладнаНаПеУ], Order.Ascending }})