// Окремий запит для зчитування типу документа з Excel.
    // Ізольований від джерел CSV.
let
    Val = fxReadNamedCell(cfgSettings[NameDocumentType])
in
    Val