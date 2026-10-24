// Query: upi_apps
let
    Source = Folder.Files(DataFolder),
    Files = Table.SelectRows(Source, each [Extension] = ".xlsx"),
    WithMonth = Table.AddColumn(Files, "month", each Date.FromText(Text.Middle([Name], 9, 7) & "-01"), type date),
    Read = Table.AddColumn(WithMonth, "rows", each fnReadMonth([Content])),
    Expanded = Table.ExpandTableColumn(Table.SelectColumns(Read, {"month", "rows"}), "rows", {"raw_name", "volume_mn", "value_cr"}),
    Typed = Table.TransformColumnTypes(Expanded, {{"raw_name", type text}, {"volume_mn", type number}, {"value_cr", type number}}),
    Joined = Table.NestedJoin(Typed, "raw_name", app_names, "raw_name", "map", JoinKind.LeftOuter),
    Result = Table.ExpandTableColumn(Joined, "map", {"app", "app_type"})
in
    Result

// Query: fnReadMonth
(content as binary) as table =>
let
    sheet = Excel.Workbook(content, null, true){0}[Data],
    allRows = Table.SelectRows(sheet, each (try Number.From([Column1]) otherwise 0) > 0),
    cols = Table.ColumnNames(allRows),
    used = List.Select(List.Positions(cols), (i) => List.NonNullCount(Table.Column(allRows, cols{i})) > 0),
    rows = Table.SelectColumns(allRows, List.FirstN(cols, List.Max(used) + 1)),
    n = Table.ColumnCount(rows),
    toNum = (v) => if v is number then v else try Number.From(Text.Remove(Text.From(v), ","), "en-US") otherwise null,
    parse = (r) =>
        let
            vals = List.Transform(Record.FieldValues(r), toNum),
            total = vals{n - 1},
            parts = if n > 4 then List.Alternate(List.Range(vals, 3, n - 5), 1, 1, 1) else {}
        in
            [
                raw_name = Text.Trim(Text.Remove(Text.From(r[Column2]), {"#", "*"})),
                volume_mn = vals{n - 2},
                value_cr = if total <> null then total else if vals{3} = null then null else List.Sum(List.RemoveNulls(parts))
            ]
in
    Table.FromRecords(List.Transform(Table.ToRecords(rows), parse))

// Query: app_names
let
    Source = Csv.Document(File.Contents(DataFolder & "\app_names.csv"), [Delimiter = ",", Encoding = 65001]),
    Headers = Table.PromoteHeaders(Source, [PromoteAllScalars = true])
in
    Headers
