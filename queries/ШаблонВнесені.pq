let
    Джерело = Excel.CurrentWorkbook(){[Name="ШаблонВнесені"]}[Content],
    #"Змінений тип" = Table.TransformColumnTypes(Джерело,{{"Фактична кількість", type number}, {"Ціна в еквіваленті", type number}, {"Сума еквівалента", type number}, {"Номенклатура", type text}, {"Найменування номенклатури", type text}, {"Від кого", type text}, {"Кому", type text}, {"Рахунок", type text}, {"Аналітика 5", type text}, {"Аналітика 5 (найменування)", type text}, {"Від кого (найменування)", type text}, {"Кому (найменування)", type text}, {"Тип документа", type text}, {"Префікс номера", type text}, {"Номер документа", type text}, {"Дата документа", type text}, {"Одиниця виміру", type text}, {"Номер партії", type text}, {"Дата господарської операції", type date}})
in
    #"Змінений тип"