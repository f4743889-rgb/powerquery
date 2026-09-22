let
    Джерело = Excel.CurrentWorkbook(){[Name="ШаблонОСВ"]}[Content],
    #"Змінений тип" = Table.TransformColumnTypes(Джерело,{{"Рахунок", type text}, {"Ан 5 (найменування)", type text}, {"Номенклатура", type text}, {"Найменування", type text}, {"Од.вим.", type text}, {"Номер партії", type text}, {"Кількість кін.", type number}, {"Ціна", type number}, {"Залишок кін.", type number}, {"Контрагент", type text}})
in
    #"Змінений тип"