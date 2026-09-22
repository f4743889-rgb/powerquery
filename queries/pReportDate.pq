let
    // Окремий запит для зчитування дати з Excel.
    // Ізольований від джерел CSV.
    RawValue = fxReadNamedCell(cfgSettings[NameReportDate]),
    ParsedDate = try DateTime.Date(DateTime.From(RawValue)) otherwise null
in
    ParsedDate