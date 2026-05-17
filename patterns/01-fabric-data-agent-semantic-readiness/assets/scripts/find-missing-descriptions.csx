// Tabular Editor 2/3 Advanced Script.
// Lists all visible objects missing a description.
// Usage: open .pbip in Tabular Editor → Advanced Scripting → paste → F5.

var missing = new System.Text.StringBuilder();
int count = 0;

foreach (var t in Model.Tables.Where(x => !x.IsHidden))
{
    if (string.IsNullOrWhiteSpace(t.Description)) { missing.AppendLine($"TABLE   {t.Name}"); count++; }
    foreach (var c in t.Columns.Where(x => !x.IsHidden))
        if (string.IsNullOrWhiteSpace(c.Description)) { missing.AppendLine($"COLUMN  {t.Name}[{c.Name}]"); count++; }
    foreach (var m in t.Measures)
        if (string.IsNullOrWhiteSpace(m.Description)) { missing.AppendLine($"MEASURE {t.Name}[{m.Name}]"); count++; }
}

if (count == 0) Info("All visible objects have descriptions. ✅");
else            Info($"{count} objects missing descriptions:\n\n{missing}");
