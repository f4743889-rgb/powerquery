let
    Cols = cfgSchema[Внесені],

    // Зчитування та базове очищення через централізовану функцію
    TypedData = fxReadCSV("Внесені документи", ШаблонВнесені),

    // Очищення текстових полів
    TextColsToClean = { Cols[Найменування], Cols[Префікс], Cols[ТипДокумента], Cols[Постачальник], Cols[Номер] },
    CleanedData = Table.TransformColumns(
        TypedData,
        List.Transform(
            TextColsToClean,
            (col) => {
                col,
                each
                    if _ = null then
                        null
                    else
                        Text.Trim(Text.Clean(Text.From(_))),
                type text
            }
        )
    )
in
    CleanedData
