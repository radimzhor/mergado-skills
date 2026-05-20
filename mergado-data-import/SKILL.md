---
name: mergado-data-import
description: >
  Reference pro vytváření pravidla Import datového souboru (data_import) v Mergadu přes API —
  typ pravidla, struct formát, CSV auto-mapování sloupců, párování podle výstupních hodnot,
  known bugs (matchByInputValues nelze patčovat), Google Sheets jako zdroj. Použij vždy, když
  uživatel chce importovat externí data (CSV, XML) do Mergado projektu přes pravidlo.
---

# Mergado — Data Import Rule (`data_import`)

Rule type for **Import datového souboru (CSV / XML)** — enriches existing products with external data.
Covers CSV end-to-end. XML import not yet tested.

---

## Rule type

```
type: data_import
```

Not listed in `/rules/definitions/` — discovered by inspecting existing rules.

---

## CSV — How column mapping works

- Mergado **auto-maps CSV columns to elements by exact name match** — no explicit mapping needed
- `$ep` must be `[]` (empty array) for CSV
- The **pairing column** (e.g. `g:id`) matches products — header must exactly match an element name
- All other columns are written to elements of the same name if they exist in the project
- **XML imports require explicit mapping** — different behavior, not yet tested

---

## Pre-flight checklist

1. **Target elements exist** in the project — create via `POST /projects/{id}/elements/` if not
2. **CSV column headers** exactly match element names (`g:id`, `test`, etc.)
3. **Check if pairing element has input or output values** — determines `matchByInputValues` setting
4. **CSV file is publicly accessible** — Mergado fetches it server-side, no auth allowed

### Check if pairing element has input values

```bash
TOKEN="mergado_pat_..."
PROJECT_ID="..."

curl -s -X POST "https://mcp.mergado.com/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"element_values_post\",\"arguments\":{\"project_id\":\"$PROJECT_ID\",\"element_path\":\"g:id\",\"is_output\":false}}}" \
  | python3 -c "
import json,sys
r=json.load(sys.stdin)
d=json.loads(r['result']['content'][0]['text'])
print('Input values:', d.get('data',[]))
"
# If all values are empty strings → use matchByInputValues: false (pair by output values)
# Common in Shopify-sourced projects — g:id only has output values, not input
```

---

## Google Sheets as CSV source (recommended)

Google Sheets published to web = stable, auto-refreshing, truly public CSV URL.

### Create Sheet from CSV via Google Drive connector

```python
# create_file WITHOUT disableConversionToGoogleType → auto-converts CSV to Google Sheet
mcp__DRIVE__create_file(
    title="my_import_data",
    contentMimeType="text/csv",
    textContent="g:id,my_element\n12345,value1\n67890,value2\n"
)
# Returns: mimeType: application/vnd.google-apps.spreadsheet, id: "1abc..."
```

⚠️ **Drive connector has no publish/permission tool** — user must publish manually:
> Open the Sheet → **File → Share → Publish to web → Sheet1 → CSV → Publish** → copy the URL

### Published-to-web URL format

```
https://docs.google.com/spreadsheets/d/e/{ENCODED_ID}/pub?gid={GID}&single=true&output=csv
```

Note: `ENCODED_ID` is generated after publishing — different from the regular sheet ID.

---

## Rule data structure (CSV)

```json
{
  "$struct": {
    "caseSensitiveMatching": false,
    "matchByInputValues": false,
    "matchingMode": "$ref.1",
    "forceSourceUrl": "$ref.2",
    "elementPathsToSkip": [],
    "fileType": "$ref.3",
    "fileTypeSpecificSettings": {
      "delimiter": "$ref.4"
    }
  },
  "$ref": {
    "$ref.1": "exact",
    "$ref.2": "https://docs.google.com/spreadsheets/d/e/.../pub?output=csv",
    "$ref.3": "csv",
    "$ref.4": ","
  },
  "$ep": []
}
```

### Key fields

| Field | Values | Notes |
|-------|--------|-------|
| `matchByInputValues` | `false` | Use `false` for Shopify projects — g:id has no input values |
| `matchingMode` | `"exact"` / `"contains"` | `exact` for ID-based pairing |
| `caseSensitiveMatching` | `false` | Default |
| `fileType` | `"csv"` | For CSV |
| `fileTypeSpecificSettings.delimiter` | `","` / `";"` / `"\|"` | Match your CSV |
| `forceSourceUrl` | string | Publicly accessible URL |
| `$ep` | `[]` | Always empty for CSV — auto-mapped by column name |

---

## Create element + rule (full workflow)

```bash
TOKEN="mergado_pat_..."
PROJECT_ID="353906"
ALLPRODUCTS_QUERY_ID="8067172"  # get from list_project_queries, read_only: true

# Step 1: Create target element if it doesn't exist
curl -s -X POST "https://api.mergado.com/projects/$PROJECT_ID/elements/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "my_element", "is_attribute": false, "hidden": false}'

# Step 2: Create rule (disabled for review)
curl -s -X POST "https://api.mergado.com/projects/$PROJECT_ID/rules/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Import from Google Sheet\",
    \"type\": \"data_import\",
    \"applies\": false,
    \"priority\": \"3\",
    \"queries\": [{\"id\": \"$ALLPRODUCTS_QUERY_ID\"}],
    \"element_path\": null,
    \"data\": {
      \"\$struct\": {
        \"caseSensitiveMatching\": false,
        \"matchByInputValues\": false,
        \"matchingMode\": \"\$ref.1\",
        \"forceSourceUrl\": \"\$ref.2\",
        \"elementPathsToSkip\": [],
        \"fileType\": \"\$ref.3\",
        \"fileTypeSpecificSettings\": {\"delimiter\": \"\$ref.4\"}
      },
      \"\$ref\": {
        \"\$ref.1\": \"exact\",
        \"\$ref.2\": \"https://docs.google.com/spreadsheets/d/e/.../pub?output=csv\",
        \"\$ref.3\": \"csv\",
        \"\$ref.4\": \",\"
      },
      \"\$ep\": []
    }
  }"

# Step 3: Fix matchByInputValues in UI if needed (see bug below)

# Step 4: Enable rule
curl -s -X PATCH "https://api.mergado.com/rules/{RULE_ID}/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"applies": true}'
```

---

## Known bugs

### `matchByInputValues: false` cannot be set via API

**Symptom:** PATCH or POST with `"matchByInputValues": false` in `data` is silently ignored — field stays `true`.

**Workaround:** Open the rule in Mergado UI → uncheck **"Párovat podle vstupních hodnot" / "Pair by input values"** manually and save. This is the only reliable way.

**Impact:** If left as `true` and the pairing element has no input values (common in Shopify-sourced projects where `g:id` is output-only), the import matches nothing and no values are written.

### `element_values_post` MCP tool output schema bug

Use direct JSON-RPC (not MCP tool directly) — MCP tool throws schema validation error. See `mergado-mcp` skill for the JSON-RPC pattern.

---

## Verify import after rebuild

```bash
curl -s -X POST "https://mcp.mergado.com/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"element_values_post\",\"arguments\":{\"project_id\":\"$PROJECT_ID\",\"element_path\":\"my_element\",\"is_output\":true}}}" \
  | python3 -c "
import json,sys
r=json.load(sys.stdin)
d=json.loads(r['result']['content'][0]['text'])
print(json.dumps(d, indent=2))
"
# Expect: value counts matching your CSV rows
```

Rebuild: **Mergado UI → Rules → Regenerate changed** (API rebuild endpoint doesn't exist).

---

## XML import

Not yet tested. Pairing element syntax differs (e.g. `@id` attribute notation). Explicit column→element mapping likely required (unlike CSV auto-mapping). Update this skill after XML import test.
