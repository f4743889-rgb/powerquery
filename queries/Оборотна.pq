let
    Cols = cfgSchema[ОСВ],
    Settings = cfgSettings,

    // Зчитування CSV (Джерело CSV)
    TypedData = fxReadCSV("Оборотна відомість", ШаблонОСВ),

    // Захищені обробники значень
    SafeBeforeDelimiter = (v as any, delim as text) as nullable text =>
        if v = null then
            null
        else
            try Text.BeforeDelimiter(Text.From(v), delim) otherwise null,
    SafeStart = (v as any, len as number) as nullable text =>
        if v = null then
            null
        else
            try Text.Start(Text.From(v), len) otherwise null,
    SafeDateFromText = (v as any, len as number) as nullable date =>
        if v = null then
            null
        else
            try Date.FromText(Text.Start(Text.From(v), len)) otherwise null,

    // Очищення та фільтрація
    Cleaned = Table.TransformColumns(
        TypedData,
        { { Cols[Найменування], each fxCleanText(_), type text } }
    ),
    NonZero = Table.SelectRows(Cleaned, each Record.Field(_, Cols[ЗалишокКін]) <> 0),

    // Додавання розрахункових колонок
    WithSupplier = Table.AddColumn(
        NonZero,
        Cols[Постачальник],
        each SafeBeforeDelimiter(Record.Field(_, Cols[Аналітика5]), ";"),
        type text
    ),
    WithShortAcc = Table.AddColumn(
        WithSupplier,
        Cols[РахунокКороткий],
        each SafeStart(Record.Field(_, Cols[Рахунок]), Settings[AccountLength]),
        type text
    ),
    WithPartyDate = Table.AddColumn(
        WithShortAcc,
        Cols[ДатаПартії],
        each SafeDateFromText(Record.Field(_, Cols[НомерПартії]), Settings[PartyDateLength]),
        type date
    ),

    // Валідація наявності дат партій
    ValidatedDates =
        let
            Parties = List.RemoveNulls(Table.Column(WithPartyDate, Cols[НомерПартії])),
            Dates = List.RemoveNulls(Table.Column(WithPartyDate, Cols[ДатаПартії]))
        in
            if not List.IsEmpty(Parties) and List.IsEmpty(Dates) then
                error Error.Record("ДатиПартійНеРозпізнано", "Жодну дату партії не вдалося розпізнати.")
            else
                WithPartyDate,

    // Фільтрація за винесеним параметром pReportDate
    FilteredResult =
        if pReportDate = null then
            ValidatedDates
        else
            Table.SelectRows(
                ValidatedDates,
                each Record.Field(_, Cols[ДатаПартії]) = null or Record.Field(_, Cols[ДатаПартії]) < pReportDate
            )
in
    FilteredResult
