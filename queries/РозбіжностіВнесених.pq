let
    RegCols = cfgSchema[Реєстр],
    InCols = cfgSchema[Внесені],
    Out = cfgSchema[Вихід],
    Settings = cfgSettings,

    RegData = fxValidateColumns(РеєстрЗведений, { Out[Номенклатура], RegCols[Назва], RegCols[Ціна], RegCols[Кількість], Out[Сума] }, "РеєстрЗведений"),
    InData = fxValidateColumns(АналізВнесених, Record.FieldValues(InCols), "АналізВнесених"),

    // Використання ізольованих параметрів
    DocType = pDocumentType,
    MVO = pMVO,

    KeysReg = { Out[Номенклатура], RegCols[Назва], RegCols[Ціна] },
    KeysIn = { InCols[Номенклатура], InCols[Найменування], InCols[Ціна] },

    // Групування реєстру
    RegGrouped = Table.Group(
        Table.TransformColumns(RegData, {{ RegCols[Ціна], each Number.Round(_, Settings[PriceRoundDigits]), type number }}),
        KeysReg,
        {
            { Out[ЗвітКількість], each List.Sum(Table.Column(_, RegCols[Кількість])), type number },
            { Out[ЗвітСума], each List.Sum(Table.Column(_, Out[Сума])), type number }
        }
    ),

    // Фільтрація та групування внесених
    InFiltered = Table.SelectRows(InData, each not fxIsConfirmationAccount(Record.Field(_, InCols[Рахунок]))),
    InByType = if DocType = null then InFiltered else Table.SelectRows(InFiltered, each Record.Field(_, InCols[ТипДокумента]) = DocType),
    InByMVO = if MVO = null then InByType else Table.SelectRows(InByType, each Record.Field(_, InCols[Постачальник]) = MVO),
    
    InGrouped = Table.Group(
        Table.TransformColumns(InByMVO, {{ InCols[Ціна], each Number.Round(_, Settings[PriceRoundDigits]), type number }}),
        KeysIn,
        {
            { Out[ВнесеноКількість], each List.Sum(Table.Column(_, InCols[Кількість])), type nullable number },
            { Out[ВнесеноСума], each List.Sum(Table.Column(_, InCols[Сума])), type nullable number }
        }
    ),
    InRenamedKeys = Table.RenameColumns(InGrouped, List.Zip({ KeysIn, KeysReg })),

    // З’єднання та виявлення розбіжностей
    AllKeys = Table.Distinct(Table.Combine({ Table.SelectColumns(RegGrouped, KeysReg), Table.SelectColumns(InRenamedKeys, KeysReg) })),
    
    JoinReg = Table.ExpandTableColumn(Table.NestedJoin(AllKeys, KeysReg, RegGrouped, KeysReg, "_Reg", JoinKind.LeftOuter), "_Reg", { Out[ЗвітКількість], Out[ЗвітСума] }),
    JoinIn = Table.ExpandTableColumn(Table.NestedJoin(JoinReg, KeysReg, InRenamedKeys, KeysReg, "_In", JoinKind.LeftOuter), "_In", { Out[ВнесеноКількість], Out[ВнесеноСума] }),
    
    Zeroed = Table.ReplaceValue(JoinIn, null, 0, Replacer.ReplaceValue, { Out[ЗвітКількість], Out[ЗвітСума], Out[ВнесеноКількість], Out[ВнесеноСума] }),

    WithDiffQty = Table.AddColumn(Zeroed, Out[РозбіжністьКількість], each Number.Round(Record.Field(_, Out[ВнесеноКількість]) - Record.Field(_, Out[ЗвітКількість]), Settings[QtyRoundDigits]), type number),
    WithDiffAmt = Table.AddColumn(WithDiffQty, Out[РозбіжністьСума], each Number.Round(Record.Field(_, Out[ВнесеноСума]) - Record.Field(_, Out[ЗвітСума]), Settings[AmountRoundDigits]), type number),

    DiffsOnly = Table.SelectRows(WithDiffAmt, each Record.Field(_, Out[РозбіжністьКількість]) <> 0 or Record.Field(_, Out[РозбіжністьСума]) <> 0)
in
    Table.Sort(DiffsOnly, List.Transform(KeysReg, each { _, Order.Ascending }))