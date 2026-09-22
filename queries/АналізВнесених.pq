let
    Cols = cfgSchema[Внесені],
    
    // Зчитування та базове очищення через централізовану функцію
    TypedData = fxReadCSV("Внесені документи", ШаблонВнесені),

    // Очищення текстових полів ролей
    TextColsToClean = { Cols[Найменування], Cols[Префікс], Cols[ТипДокумента], Cols[Постачальник], Cols[Номер] },
    CleanedData = Table.TransformColumns(
        TypedData,
        List.Transform(TextColsToClean, (col) => { col, each Text.Trim(Text.Clean(_)), type text })
    )
in
    CleanedData