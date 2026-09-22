let
    Джерело = Excel.CurrentWorkbook(){[Name="Реєстр"]}[Content],
    #"Змінений тип" = Table.TransformColumnTypes(Джерело,{{"№ з/п", type number}, {"Тип документа", type text}, {"№ документа", type text}, {"Дата документа", type date}, {"Підрозділ", type text}, {"Найменування об’єкта", type text}, {"Номенклатурний номер", type text}, {"Од.вим.", type text}, {"Ціна, грн.", type number}, {"Кількість", type number}, {"Сума, грн.", type number}, {"Примітки", type text}}),
    #"Видалені помилки" = Table.RemoveRowsWithErrors(#"Змінений тип", {"№ з/п"})
in
    #"Видалені помилки"