---
name: mergado-mcp
description: >
  Knowledge base and workflow guide for working with Mergado via MCP (Model Context Protocol)
  and the Mergado REST API. Use this skill whenever the user wants to: connect Claude to Mergado,
  set up mcp-remote for Mergado, work with Mergado eshops/projects/products/elements/rules/queries
  via MCP tools, optimize product feed titles or descriptions, create/update Mergado rules
  (rewriting, batch_rewriting, categories, etc.), debug MCP tool errors with Mergado, or query
  Mergado product data. Also trigger when the user mentions Mergado PAT tokens, Mergado feeds,
  g:title, g:description, Mergado element paths, Mergado audit, or any Mergado-specific operations.
  If the user is doing anything feed-related in a Mergado context, use this skill.
---

# Mergado MCP Skill

## Související skilly

Před prací s Mergadem zkontroluj, jestli není vhodnější použít specializovaný skill:

| Skill | Kdy použít |
|-------|------------|
| **mergado-elements** | Typy elementů (simple/vícenásobné/zanořené/atributové), origin (input/from_rule), hidden, API pro výpis a vytvoření vlastních elementů, syntaxe Element Path |
| **mergado-rules** | Typy pravidel, datové formáty (simple/struct), priority, API workarounds — rewriting, batch_rewriting, categories, batch_param, truncating, tagstripping, hiding |
| **mergado-mql** | MQL výrazy, výběry produktů, operátory (IN, CONTAINS, NOT, SORT BY…), debugging queries |
| **mergado-audit** | Feed audit — čtení výsledků, verdikty, mapování issues na pravidla, opravy condition/availability/HTML/duplicit |
| **mergado-google-shopping** | Povinné elementy, validní hodnoty (availability/condition), Google taxonomy lookup, GMC chyby a opravy pravidly |
| **mergado-products-export** | Načítání hodnot produktů bez přetížení — element_values_post (agregace), list_project_products_post + MQL + values_to_extract (per-produkt), export do CSV |
| **mergado-data-import** | Pravidlo data_import (Import datového souboru) — CSV auto-mapování, Google Sheets jako zdroj, párování podle výstupních hodnot, known bugs |
| **mergado-asistent** | Uživatel mluví jazykem problémů (feed nefunguje, produkty se nezobrazují v Google Shopping) — ne jazykem Mergada |

Tyto skilly použij jako doplněk k tomuto, ne náhradu — tento skill obsahuje API/MCP implementační detaily.

Everything needed to work with Mergado via MCP — setup, known bugs, data model, working
workflows, and the fallback patterns that bypass broken MCP tools and undocumented behavior.

---

## Setup & Configuration

### MCP Server URLs
- **Production:** `https://mcp.mergado.com`
- **Dev:** `https://x-dev-mcp.mergado.com`

### REST API base URLs (cheat sheet)

| Environment | MCP server | REST API |
|-------------|-----------|----------|
| Production | `https://mcp.mergado.com` | `https://api.mergado.com` |
| Dev | `https://x-dev-mcp.mergado.com` | `https://dev.mergado.com/api/` |

API docs: `https://api-docs.mergado.com/?api=mergado-api` (Swagger UI; OpenAPI spec at `?specs=mergado-api`).

### Config file location (macOS)
```
~/Library/Application Support/Claude/claude_desktop_config.json
```

### Config format
```json
{
  "mcpServers": {
    "mergado": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://mcp.mergado.com",
        "--header",
        "Authorization: Bearer mergado_pat_YOUR_TOKEN_HERE"
      ]
    }
  }
}
```

After editing, **restart Claude Desktop** for changes to take effect.

### PAT Tokens
- Format: `mergado_pat_...`
- Production tokens: generated at `app.mergado.com` (works against `https://api.mergado.com/`)
- Dev tokens: generated at `dev.mergado.com` (works against `https://dev.mergado.com/api/`)
- **Dev and prod tokens are NOT interchangeable** — dev token won't authenticate against prod API

---

## Three Layers — Which to Use When

There are three ways to call Mergado. **Reach for the next layer only when the previous one fails.**

### 1. MCP tool (preferred) — fast, native
Call `mcp__mergado__<tool>` like any other tool. Works for simple parameter types (`object`, `string`,
`number`). **Fails for `anyOf: [array, null]` parameters** (e.g. `queries`, `values_to_extract`) because
Claude Code's MCP client stringifies arrays. Fails for output-schema bugs.

### 2. Direct JSON-RPC to MCP server — bypasses client serialization & output schema bugs
When MCP tool fails with:
- "Structured content does not match the tool's output schema" → output schema bug
- "'[...]' is not valid under any of the given schemas" → client stringified array

Call MCP server directly via curl:

```bash
curl -s -X POST "https://mcp.mergado.com/" \
  -H "Authorization: Bearer {TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"TOOL_NAME","arguments":{...}}}'
```

This bypasses Claude Code MCP client serialization, so arrays work correctly. The server returns
results in `result.content[0].text` (JSON string) and `result.structuredContent` (parsed JSON).

### 3. Direct REST API to Mergado — bypasses MCP server entirely
Use when MCP server itself rejects the request. Examples:
- `create_rule` with `data` as array (e.g. for `batch_rewriting`, `batch_param`, `categories`)
- `update_rule` returning HTTP 405 (MCP tool uses wrong HTTP method)

```bash
# Create rule
curl -s -X POST "https://api.mergado.com/projects/{id}/rules/" \
  -H "Authorization: Bearer {TOKEN}" -H "Content-Type: application/json" \
  -d '{...}'

# Update rule (use PATCH, not PUT)
curl -s -X PATCH "https://api.mergado.com/rules/{id}/" \
  -H "Authorization: Bearer {TOKEN}" -H "Content-Type: application/json" \
  -d '{"applies": true}'

# Delete rule
curl -s -X DELETE "https://api.mergado.com/rules/{id}/" \
  -H "Authorization: Bearer {TOKEN}"
```

---

## Known Bugs (verified — kept short; full report in `/Users/radimzhor/Documents/Mergado/MCP/bug-report.md`)

### Server-side bugs in Mergado MCP
- **`create_rule.data` rejects arrays** — schema is `object` but `batch_rewriting`/`batch_param`/`categories` need array. Use REST API directly.
- **`get_current_user` output schema requires `user`** — real response is flat (prod only). Use direct JSON-RPC.
- **`element_values_post` output schema requires `path`** — not in response. Use direct JSON-RPC.
- **`list_defined_rules` output schema requires `total_results`** — not in response. Use direct JSON-RPC.
- **`update_rule` returns HTTP 405** — wrong HTTP method on server. Use REST API PATCH.
- **`update_rule` uses `enabled` not `applies`** — inconsistent naming. REST API uses `applies`.
- **`trigger_project_rebuild` returns HTTP 404** — endpoint doesn't exist. No MCP workaround; user must rebuild in UI.
- **`list_project_products` with `values_to_extract` → HTTP 500** — server crashes. Omit param and fetch values separately.

### Server-side bugs in Mergado REST API
- **`/rules/definitions/` is incomplete** — missing `batch_rewriting`, `batch_param`, `categories`, `batch_rewriting_values` rule types (and possibly more).
- **`batch_rewriting_values` `additional_data` not settable via API** — server silently drops it on POST/PATCH/PUT. Use UI only for this rule type.
- **`POST /projects/{id}/feedaudits/` returns HTTP 500** — server crash on audit creation even with full scope. Read-only access to existing audits works fine.
- **`POST /projects/{id}/variables/` requires `element_path`** — undocumented requirement (and OpenAPI typo: `/project/` singular vs `/projects/` plural).
- **OpenAPI spec is incomplete** — `queries` missing from `/projects/{id}/rules/` POST body schema, `values_to_extract` missing from `/projects/{id}/products` params.
- **No data validation** — API accepts incomplete/wrong `data` for rule types that need structure. Creates broken rules.
- **System-only rules creatable via API** — `format_converter`, `product`, `heurekawatchdog__pairing` should be rejected for user creation. UI doesn't allow them.

### Claude Code MCP client bug (not Mergado's)
- **Stringifies `anyOf: [array, null]` parameters** — affects `queries`, `values_to_extract`, and any boolean-typed parameter passed via Claude Code MCP tool invocation.
- **Workaround:** direct JSON-RPC curl to MCP server.

---

## Data Model

**Hierarchy:** User → Shops (eshops) → Projects (feeds/exports) → Products → Elements

### Elements
- Element paths use `|` as separator: `seo | title`, `variants | title`, `metafields | key`, `g:product_detail | g:attribute_name`
- `origin: "input"` = from source feed (often `hidden: true`, not in output)
- `origin: "from_rule"` = computed by Mergado rules (visible in output)

### Metafields (Shopify-sourced feeds)
Paired key/value sequences — read both, align by order:
- `metafields | key` (e.g. `color-pattern`, `material`)
- `metafields | value` (e.g. `Green`, `Glass, Neoprene`)

### Output values vs. input values
- `is_output=false` — values BEFORE rules are applied (raw from source feed)
- `is_output=true` — values from the **last generated export**, not on-demand. After enabling/disabling rules, the output values won't change until next export. Default export schedule: hourly.

---

## Rule Types — Complete List

Includes types **missing from `/rules/definitions/`** discovered through reverse engineering.

| Type | In definitions? | Data format | Purpose |
|------|-----------------|-------------|---------|
| `rewriting` | ✅ | object: `{new_content: "..."}` | Set single value for all matched products |
| `batch_rewriting` | ❌ undocumented | array: `[{position, query_id, value}, ...]` | Bulk: per-query different values |
| `truncating` | ✅ | object: `{max_length, intelligent, truncate_prepositions, append}` | Truncate string |
| `tagstripping` | ✅ | object: `{}` | Strip HTML tags |
| `remove_diacritics` | ✅ | object: `{}` | Remove accents |
| `hiding` | ✅ | object: `{}` | Hide products from output feed (apply to filter query) |
| `params_remove_by_value` | ✅ | object/struct | Remove sub-elements by value (UI uses struct format) |
| `batch_set_datetime` | ✅ | object/struct | Bulk set datetime fields (UI uses struct format) |
| `categories` | ❌ undocumented | array: `[{position, input, output}, ...]` | **Smart category pairing** — maps source→target category strings |
| `batch_param` | ❌ undocumented (but **works via API ✅**) | struct format with `epParam`/`epParamName`/`epParamValue` mapping | Bulk add/set product parameters (e.g. `g:product_detail`). Tested working with `%variable%` references. |
| `batch_rewriting_values` | ❌ undocumented | array + `additional_data` | **Per-product mapping via element value match.** ⚠️ `additional_data.target_element_path` is REQUIRED but **CANNOT be set via API** — server silently drops it. Use UI only. |
| `format_converter` | ✅ | (system only) | ⚠️ System-managed. Created automatically on project creation. **Do NOT create user-level.** |
| `product` | ✅ | (system only) | ⚠️ "Manual changes to product elements" — created automatically when user edits a product in UI. **Do NOT create user-level.** |
| `heurekawatchdog__pairing` | ✅ | (output format dependent) | Only relevant for Heureka output projects. Form will be empty/broken in Google projects. |

> **Important:** When creating rules via API, prefer the rule types known to be safe for user creation
> (rewriting, batch_rewriting, truncating, tagstripping, remove_diacritics, hiding, categories, batch_param,
> params_remove_by_value, batch_set_datetime). Avoid `format_converter`, `product`, and
> `heurekawatchdog__pairing` unless you specifically know what you're doing.

---

## Mergado Variables — Named Regex Extractions

Variables in Mergado are NOT simple key/value pairs. They are **named regex extractions from an
element's value**. You define a regex on a source element, pick a capture group, name it, and then
use it in rules via `%VARIABLE_NAME%`.

### Create a variable

```bash
POST /projects/{id}/variables/   # plural — works
                                  # NOTE: spec says /project/ singular but that's a typo (Bug #23)
```

Body:
```json
{
  "name": "BRAND_FROM_TITLE",
  "element_path": "g:title",
  "regular_expression": "^(\\S+)",
  "fragment_number": 1,
  "sample_text": null
}
```

| Field | Required | Purpose |
|-------|:---:|---------|
| `name` | ✅ | Variable identifier — used in rules as `%name%` |
| `element_path` | ✅ | Element to extract from (Bug #24: required but missing in docs) |
| `regular_expression` | ✅ | Regex with capture groups |
| `fragment_number` | ✅ | Which capture group (1-based) |
| `sample_text` | optional | Sample for UI testing |

### Manage variables

| Endpoint | Purpose |
|----------|---------|
| `GET /projects/{id}/variables/` | List project variables |
| `GET /variables/{id}/` | Get specific variable |
| `PATCH /variables/{id}/` | Update variable |
| `DELETE /variables/{id}/` | Delete variable |

### Common patterns

| Goal | name | element_path | regex | fragment |
|------|------|--------------|-------|----------|
| First word of title | `FIRST_WORD` | `g:title` | `^(\S+)` | 1 |
| Brand from "Brand Name - Product" | `BRAND` | `g:title` | `^(.*?)\s*-` | 1 |
| First line of description | `FIRST_LINE` | `g:description` | `^([^\n]+)` | 1 |
| Numeric size | `SIZE` | `variants \| title` | `(\d+)` | 1 |

### Use in rules

```json
"newContent": "%BRAND% - %g:title%"
```

When the rule executes, `%BRAND%` is replaced with the variable's extracted value for each product.

---

## Dynamic Variables in Rule Values (%element% syntax)

Rule values (both in `new_content` and `value` fields) support **dynamic references** to other
element values or project variables. This is a key feature for non-hardcoded transformations.

### Syntax

Wrap an element path or variable name in `%`:

```
%g:price% CZK                              → uses current value of g:price + " CZK"
%title% - %vendor%                         → concatenates two element values
%g:product_detail | g:attribute_name%      → references nested element via parent path
%MY_VARIABLE%                              → references a defined project variable
```

### Where it works

- ✅ `rewriting` → `data.new_content` (simple format)
- ✅ `rewriting` → `data.$ref.$ref.X` (struct format, `newContent` field)
- ✅ `batch_rewriting` → `data[].value`
- ✅ `categories` → `data[].output`
- Probably works in `batch_rewriting_values.output_value` and others too

### Example: full struct rule with dynamic variable

```json
{
  "type": "rewriting",
  "applies": true,
  "queries": [{"id": "{ALLPRODUCTS_ID}"}],
  "data": {
    "$struct": {"rows": [{"elementPath": "$ep.1", "newContent": "$ref.1"}]},
    "$ref": {"$ref.1": "%g:sale_price% CZK"},
    "$ep":  {"$ep.1": "g:price"}
  }
}
```

### Useful patterns

| Goal | Value template |
|------|---------------|
| Combine brand + title | `%g:brand% %g:title%` |
| Add suffix | `%g:title% - skladem` |
| Use source price as sale price fallback | `%g:price%` |
| Build SKU from id | `SKU-%g:id%` |
| Reference nested element | `%g:product_detail \| g:attribute_value%` |
| Use stored Mergado variable | `%my_var_name%` |

### Important caveats

- **Execution order matters.** Dynamic variables read the CURRENT value of the referenced element
  at the time the rule executes. If another rule earlier in priority order already modified that
  element, you'll see the MODIFIED value, not the source.
- **For "source value" reference**: there's no built-in way to reference the pre-rule input value.
  If you need original source values, either avoid intermediate rules or use `batch_rewriting`
  with hardcoded values.
- **Element paths in `%...%`** follow the same format as element path elsewhere — use `|` for
  nesting, no XPath-style brackets.

### Priority pattern for reliable source extraction

When using a variable/element reference that should read the SOURCE value (not a transformed one),
give the rule a **low priority** so it runs before transformations.

**Verified pattern (tested in production):**

```
Priority 1   → format_converter (system)
Priority 5   → Your extraction rules (reads g:price = "169 CZK", extracts "169" via variable)
Priority 8   → Other transformations that modify g:price
Priority 200 → Your final rule using extracted value
```

If you reverse this (high priority extraction, low priority transformation), the variable will
extract from the **transformed** value, which is usually not what you want.

**Bonus quirk**: When you PATCH `priority` to a value that already exists, Mergado may auto-bump
to a fractional value (e.g. requesting `"5"` may end up as `"5.5"`). This is rule order
preservation logic.

---

## Rule `data` Format: Simple vs Struct (UI-compatible)

**This is critical.** Mergado has **two `data` formats** for rules. They're not equivalent.

### Simple format — what `/rules/definitions/` documents
```json
{"new_content": "Mergado Test"}
```
- ✅ API accepts it
- ❌ **UI cannot open/edit** rules created with this format — shows empty form or error
- ❌ Some rule types (params_remove_by_value, batch_set_datetime, batch_param) cannot work with this — need struct

### Struct format — what UI uses internally
```json
{
  "$struct": {"rows": [{"elementPath": "$ep.1", "newContent": "$ref.1"}]},
  "$ref":   {"$ref.1": "Mergado Test"},
  "$ep":    {"$ep.1": "g:brand"}
}
```
- ✅ API accepts it (undocumented, but works!)
- ✅ UI opens/edits properly
- ✅ Rule fully functional in UI and in feed
- ⚠️ Not officially documented — could break in a Mergado refactor

**Recommendation:** Use struct format whenever creating rules via API that the user might want to
manage in UI. Use simple format only for headless integrations where UI is not used.

When using struct format:
- `element_path` on top-level is `null` — actual path is in `data.$ep`
- Values deduplicated via `$ref`
- Element paths deduplicated via `$ep`

### Example: rewriting in struct format (proven to work in UI)
```bash
curl -s -X POST "https://api.mergado.com/projects/{PROJECT_ID}/rules/" \
  -H "Authorization: Bearer {TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Set g:brand",
    "type": "rewriting",
    "applies": false,
    "priority": "100",
    "queries": [{"id": "{ALLPRODUCTS_QUERY_ID}"}],
    "data": {
      "$struct": {"rows": [{"elementPath": "$ep.1", "newContent": "$ref.1"}]},
      "$ref":   {"$ref.1": "Festa"},
      "$ep":    {"$ep.1": "g:brand"}
    }
  }'
```

---

## Key Tools — Quick Reference

### Navigation (work fine via MCP)
```
list_user_eshops(id)            → shops user can access
list_shop_projects(id)          → projects in a shop
list_project_elements(id)       → full element tree
list_project_queries(id)        → queries defined in project
list_project_rules(id)          → rules in project (also /projects/{id}/rules/?limit=100)
get_project(id)                 → ⚠️ BROKEN output schema, use direct JSON-RPC
```

### Inspecting feed values
```
element_values_post(project_id, element_path, is_output)
  ⚠️ MCP tool BROKEN (output schema), use direct JSON-RPC
  is_output=false: raw values from source feed
  is_output=true:  values from LAST EXPORT (not real-time after rule changes)
```

### Products

**Načíst konkrétní produkty s hodnotami elementů (ověřený způsob):**
```bash
# list_project_products_post s mql filtrem a values_to_extract — MUSÍ BÝT přes přímý JSON-RPC
# (MCP tool by values_to_extract stringifikoval → chyba)
curl -s -X POST "https://mcp.mergado.com/" \
  -H "Authorization: Bearer {TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"list_project_products_post","arguments":{
    "id": "{PROJECT_ID}",
    "mql": "g:id IN (\"ID1\"; \"ID2\")",
    "values_to_extract": ["g:title", "g:link"],
    "per_page": 10
  }}}'
# Odpověď: data[].extracted_values.{element} nebo data[].data.elements.{element}[0].value
```

**Pravidla:**
- `values_to_extract` jako array funguje POUZE přes přímý JSON-RPC (ne přes MCP tool)
- `mql` parametr filtruje produkty — podporuje MQL výrazy jako `g:id = "X"`, `title CONTAINS "Y"`
- `list_project_products(id)` bez filtrů: ⚠️ vrátí všechny produkty — pro tisíce produktů nepoužívat
- Pokud potřebuješ jen počet produktů splňujících podmínku: vytvoř query přes `create_project_query` a načti `product_count` z `GET /queries/{id}/`

### Queries (filter products for a rule)
```
POST /projects/{id}/queries/  body: {name, query}   → HTTP 409 if name already exists
GET  /queries/{id}/           → product_count (None = not yet evaluated)
DELETE /queries/{id}/
```

The default "all products" query has a system-defined ID — fetch it from `list_project_queries`.
It's identified by `name: "♥ALLPRODUCTS♥"` and `read_only: true`.

> **MQL syntaxe** (operátory, IN, NOT, SORT BY, PARAM…) → viz skill **mergado-mql**

### Rules — create
```
POST /projects/{id}/rules/
  Required: name, type, queries (top-level array, even for batch types!), priority, data
  applies: false → create as disabled (recommended for review)
  priority: required, string format (e.g. "100" or "1E+2")
```

### Rules — update
```
PATCH /rules/{id}/
  Use to enable/disable: {"applies": true/false}
  ⚠️ MCP update_rule is BROKEN (HTTP 405) — must use REST API
  ⚠️ MCP tool uses `enabled` param; REST API uses `applies`
```

### Rules — delete
```
DELETE /rules/{id}/
  Returns HTTP 204 on success
```

### User
```
get_current_user()  → MCP tool BROKEN on prod, use direct JSON-RPC
```

---

## Scopes & Permissions

| Scope | Required for |
|-------|--------------|
| *(read-only default)* | list shops/projects/products/elements/rules/queries |
| `project.rules.write` | create_rule, update_rule, delete_rule, create_project_query |

Token scope error returns HTTP 403:
```
"Bearer token scope not valid. Required scopes: [project.rules.write]"
```

Generate PAT with the needed scopes at `app.mergado.com` (or `dev.mergado.com`).

---

## End-to-End Workflows

### Workflow A — SEO title optimization (batch_rewriting)

1. `list_project_elements(project_id)` — discover available data
2. For each candidate element, fetch values via direct JSON-RPC `element_values_post` with `is_output=false`
3. `list_project_products(id)` (without `values_to_extract`) — parse with Agent subagent
4. Compose new titles per product based on input data
5. Create per-product queries (one per product, e.g. `g:id = "LEV-..."`)
6. Create rule via **REST API** (Bug #1 — MCP can't take array data):
   ```bash
   curl -X POST "https://api.mergado.com/projects/{id}/rules/" -d '{
     "type": "batch_rewriting", "element_path": "g:title", "applies": false, "priority": "100",
     "queries": [{"id":"Q1"},{"id":"Q2"},{"id":"Q3"}],
     "data": [
       {"position":1, "query_id":"Q1", "value":"New title 1"},
       {"position":2, "query_id":"Q2", "value":"New title 2"},
       {"position":3, "query_id":"Q3", "value":"New title 3"}
     ]
   }'
   ```

### Workflow F — Extract structured data from descriptions → Google Shopping parameters (verified end-to-end)

A powerful pattern: variable with regex + `batch_param` rule = extract values from free-text
descriptions and write them as proper Google Shopping `product_detail` parameters.

**Use case:** product descriptions contain unstructured info like `"tloušťka: 0,65mm"`. We want
Google to see a structured parameter `Tloušťka: 0,65mm` it can filter and display.

**Steps (verified working via API):**

```bash
# Step 1: Create variable that extracts the value via regex
POST /projects/{id}/variables/
{
  "name": "THICKNESS",
  "element_path": "g:description",
  "regular_expression": "tl?oušťka:\\s*([\\d,.]+\\s*mm)",
  "fragment_number": 1,
  "sample_text": null
}
# → returns variable id

# Step 2: Create batch_param rule that writes to g:product_detail
POST /projects/{id}/rules/
{
  "name": "Extract tloušťka → g:product_detail",
  "type": "batch_param",
  "applies": true,
  "priority": "6",
  "queries": [{"id": "{ALLPRODUCTS_ID}"}],
  "data": {
    "$struct": {
      "settings": {
        "epParam": "$ep.1",
        "epParamName": "$ep.2",
        "epParamValue": "$ep.3"
      },
      "rows": [{
        "queries": ["$ref.1"],
        "params": [{
          "paramName": "$ref.2",
          "value": "$ref.3",
          "unit": ""
        }]
      }]
    },
    "$ref": {
      "$ref.1": "{ALLPRODUCTS_ID}",
      "$ref.2": "Tloušťka",
      "$ref.3": "%THICKNESS%"
    },
    "$ep": {
      "$ep.1": "g:product_detail",
      "$ep.2": "g:product_detail | g:attribute_name",
      "$ep.3": "g:product_detail | g:attribute_value"
    }
  }
}
```

**Result:** Products whose description matches get a `<g:product_detail>` node with the extracted
value. Products without a matching pattern get nothing (no junk parameters — clean behavior).

**Key takeaways:**
- `batch_param` works fully via API (unlike `batch_rewriting_values` which silently drops `additional_data`)
- Variables and dynamic `%VAR%` references in rule values work seamlessly
- The `$ep` map points to TARGET element paths; the rule writes there
- Nested element paths (`parent | child`) work in `$ep` values
- This pattern scales to any extraction-to-parameter need (material, color, dimensions, etc.)

**Demo showcase note:** This is a great demo flow — shows AI extracting structured data from
free-form text and producing proper Google Shopping XML.

---

### Workflow E — Per-product value mapping (batch_rewriting vs batch_rewriting_values)

When you need to set DIFFERENT values for different products (e.g. brand, GTIN, title per product),
you have two options:

#### Option 1: `batch_rewriting` with per-product queries (works via API ✅)
- Create N queries (one per product, `g:id = "X"`)
- One `batch_rewriting` rule with N data rows, each referencing one query
- Slightly verbose but reliable

```bash
# Step 1: Create queries
for ID in LEV-32338 LEV-33100 LEV-33102; do
  curl -X POST ".../projects/{PID}/queries/" -d "{\"name\":\"Produkt $ID\",\"query\":\"g:id = \\\"$ID\\\"\"}"
done

# Step 2: One batch_rewriting rule
curl -X POST ".../projects/{PID}/rules/" -d '{
  "type": "batch_rewriting",
  "element_path": "g:brand",
  "applies": false, "priority": "100",
  "queries": [{"id":"Q1"},{"id":"Q2"},{"id":"Q3"}],
  "data": [
    {"position":1, "query_id":"Q1", "value":"Festa"},
    {"position":2, "query_id":"Q2", "value":"Levior"},
    {"position":3, "query_id":"Q3", "value":"Levior"}
  ]
}'
```

#### Option 2: `batch_rewriting_values` (UI ONLY ❌ — API broken)

This rule type maps `input_value → output_value` of a TARGET element. Example: "if g:id = LEV-32338,
set g:brand = Festa". No queries needed.

**But it doesn't work via API** — the `additional_data` field (which holds `target_element_path`)
is silently dropped by the server. The rule gets created but won't function. Only the UI can set
it correctly.

If you have this rule type in mind, ask the user to create it via Mergado UI.

---

### Workflow B — Google product category mapping (categories rule type)

For Czech Google taxonomy lookup:
```bash
curl -s "https://www.google.com/basepages/producttype/taxonomy-with-ids.cs-CZ.txt" \
  | grep -i "<your-product-keyword>"
# Output format: <ID> - <Full > path > to > category>
```

Create `categories` rule (smarter than `rewriting` — preserves mapping per source category):
```bash
curl -X POST "https://api.mergado.com/projects/{id}/rules/" -d '{
  "name": "Google kategorie - Hladítka",
  "type": "categories",
  "applies": false,
  "priority": "22",
  "queries": [{"id": "{ALLPRODUCTS_ID}"}],
  "data": [
    {"position": 1, "input": "Source category A", "output": "Kutilství a řemeslo > ... > Hladítka"},
    {"position": 2, "input": "Source category B (already correct)", "output": "Kutilství a řemeslo > ... > Hladítka"}
  ]
}'
```

### Workflow C — Cleanup HTML in g:description (tagstripping)

Simplest rule type, just needs queries and element_path:
```bash
curl -X POST "https://api.mergado.com/projects/{id}/rules/" -d '{
  "name": "Strip HTML from g:description",
  "type": "tagstripping",
  "element_path": "g:description",
  "applies": false,
  "priority": "30",
  "queries": [{"id": "{ALLPRODUCTS_ID}"}],
  "data": {}
}'
```

### Workflow D — Activate/deactivate an existing rule

MCP `update_rule` is broken. Use REST PATCH:
```bash
curl -X PATCH "https://api.mergado.com/rules/{rule_id}/" \
  -H "Authorization: Bearer {TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"applies": true}'
```

---

## Feed Audit API — diagnostics workflow

Mergado has a **Feed Audit API** that validates project feeds against platform requirements (Google
Shopping, Heureka, etc.) and returns structured issues. Endpoints:

| Endpoint | Purpose |
|----------|---------|
| `GET /projects/{id}/feedaudits/` | List audits for a project |
| `POST /projects/{id}/feedaudits/` | Create a new audit (body: `feed_url`, `feed_types`, `parser_type`, `webhook_url`) |
| `GET /feedaudits/{id}/` | Audit detail (status, started_at, finished_at, errors count) |
| `GET /feedaudits/{id}/issues/` | List all issues in the audit |
| `GET /feedaudit/audits/{id}/products/` | List products in the audit |
| `GET /feedaudit/products/{id}` | Get audit product detail |
| `GET /feedaudit/products/{id}/issues/` | List issues for a specific product |
| `GET /feedaudits/issues/{id}/` | Get a specific issue |

### Issue structure
```json
{
  "id": "...",
  "verdict": "missing | invalid_separator | invalid_format | ...",
  "info": { "element": "G:GOOGLE_PRODUCT_CATEGORY" } | { "elements": [...] },
  "validator": "categorytext_google_product_category_google",
  "level": "warning | recommendation | error",
  "feed_types": ["google.cz", "google.us", ...],
  "product_id": "...",
  "audit_id": "..."
}
```

### Required OAuth scope
`projects.feedaudit.read` (note: plural `projects`) for reading audits; `.write` for creating.

### Example: list current audits + issues
```bash
TOKEN="..."
PROJECT_ID="..."

# 1) Get latest audit
AUDIT_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.mergado.com/projects/$PROJECT_ID/feedaudits/?limit=1" | jq -r '.data[0].id')

# 2) List its issues
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.mergado.com/feedaudits/$AUDIT_ID/issues/?limit=100" | jq '.data[] | {verdict, level, info, product_id}'
```

---

## Rule Query Management — separate endpoints

Beyond `create_rule` (which requires `queries` upfront), there are endpoints to manage queries **after**
the rule is created:

| Endpoint | Purpose |
|----------|---------|
| `GET /rules/{id}/queries/` | List queries assigned to a rule |
| `PATCH /rules/{id}/queries/` body `{"id": "QID"}` | Assign an existing query to a rule |
| `DELETE /rules/{rid}/queries/{qid}` | Remove a query from a rule |
| `GET /rules/{id}/data/` | Get only `data` of a rule (useful for large batch rules) |

This enables workflows like "create rule with one query, then attach more queries dynamically".

---

## Other useful API endpoints (less common)

- `GET /heureka/categories/` — Built-in Heureka taxonomy (no need to fetch external file)
- `GET /heureka/categories/{id}/` — Get specific Heureka category
- `GET /projects/{id}/variables/` — Project variables (custom defined values)
- `GET /projects/{id}/elements/` — Element tree (same as `list_project_elements` MCP tool)
- `POST /projects/{id}/elements/` — Create a custom element
- `GET /projects/{id}/stats/products/` — Per-product statistics (impressions, clicks, etc.)
- `GET /projects/{id}/stats/categories/` — Per-category statistics
- `GET /projects/{id}/google/analytics_4/` — GA4 integration data
- `GET /apps/` — List all available Mergado apps
- `GET /projects/{id}/apps/` — Apps enabled on this project
- `GET /me/app/enabled/` — List entities where MY app is enabled (OFFLINE token only)
- `GET /maintenance` — Maintenance status info

### Deprecated endpoint to avoid
- `GET /projects/{id}/info/` — marked as deprecated in API docs since 2019 but still exists. Use
  `GET /projects/{id}/` for project metadata instead.

---

## OAuth Scopes — Complete List

There are **38 OAuth scopes** in the Mergado API. Selected scope groups:

### Project scopes
- `project.read` / `project.write` — basic project access
- `project.rules.read` / `project.rules.write` — rule management
- `project.queries.read` / `project.queries.write` — query management
- `project.elements.read` / `project.elements.write` — element tree
- `project.variables.read` / `project.variables.write` — project variables
- `project.products.read` / `project.products.write` — product data
- `project.apps.read` / `project.apps.write` — project apps
- `project.stats.read` — statistics
- `project.ga.read` — Google Analytics integration
- `project.logs.read` — import/export logs
- `projects.feedaudit.read` / `projects.feedaudit.write` — **note plural `projects`**

### Shop scopes
- `shop.read` / `shop.write`
- `shop.apps.read` / `shop.apps.write`
- `shop.stats.read` / `shop.stats.source.read`
- `shop.projects.read`
- `shop.ga.read`
- `shop.notify.write`
- `shop.proxy.read` / `shop.proxy.write`

### User scopes
- `user.read`
- `user.apps.read` / `user.apps.write`
- `user.shops.read`
- `user.notify.read`
- `user.billing.read`
- `user.formats.read`

### Other
- `eshop.read`

---

## Rule type relationship (1:1 vs 1:N)

The `Rule_Definitions` schema in API spec has a `relationship` field:
- **`1:1`** — rule accepts a **single object** as `data` (e.g. `{"new_content": "..."}` for `rewriting`)
- **`1:N`** — rule accepts a **list of objects** as `data` (e.g. `[{position, query_id, value}, ...]` for `batch_rewriting`)

This is the formal way to identify which rule types need array data. However, **`/rules/definitions/`
endpoint doesn't list all rule types** — `batch_rewriting`, `batch_param`, `categories` are missing
entirely. For full list see "Rule Types — Complete List" section in this skill.

---

## Verified Write Endpoints — Quick Reference

Endpoints we've tested and verified working with PAT tokens (all via direct REST API):

| Endpoint | Status | Notes |
|----------|--------|-------|
| `PATCH /projects/{id}/` | ✅ | Update project fields (name, note, etc.) |
| `POST /projects/{id}/elements/` | ✅ | Create custom element. Body: `{name, is_attribute, hidden}` |
| `DELETE /elements/{id}/` | ✅ | Delete element |
| `POST /projects/{id}/queries/` | ✅ | Create query. Body: `{name, query}` (MQL string) |
| `DELETE /queries/{id}/` | ✅ | Delete query |
| `POST /projects/{id}/rules/` | ✅ | Create rule (see Rule data formats section) |
| `PATCH /rules/{id}/` | ✅ | Update rule (e.g. `{"applies": true}`, `{"name": "..."}`) |
| `DELETE /rules/{id}/` | ✅ | Delete rule |
| `PATCH /rules/{id}/queries/` | ✅ | Assign **additional** query to rule. Body: `{"id": "QID"}` |
| `DELETE /rules/{rid}/queries/{qid}` | ✅ | Remove query from rule |
| `POST /users/{id}/notifications/` | ✅ | Send notification. Body: `{"title": "...", "body": "..."}` |
| `POST /shops/{id}/notifications/` | ✅ | Send to shop. Required: `title`, `body` (and possibly `event`, `scope`) |
| `POST /projects/{id}/variables/` | ⚠️ | Requires `element_path` in body (undocumented). Path is plural — spec typo `/project/` is wrong. |
| `POST /projects/{id}/feedaudits/` | ❌ | **HTTP 500** even with full scope — server crash (Bug #22) |
| `PATCH /shops/{id}/` | ❌ | Requires `shop.write` scope — not in UI "All" preset |

### Workflow tips

- **Adding queries to existing rule**: Use `PATCH /rules/{id}/queries/` with single `{"id": "QID"}` body. You can chain multiple calls to add multiple queries.
- **Activating a rule**: `PATCH /rules/{id}/` with `{"applies": true}` — MCP `update_rule` is broken (HTTP 405), use REST.
- **Updating rule data**: Send full new `data` to `PATCH /rules/{id}/` — the field replaces, doesn't merge.
- **Variables in Mergado are element-bound** — you can't create a standalone variable. Each variable references an `element_path` in the project.

---

## Token Scopes — UI vs Reality

**Don't trust "All" preset in Mergado UI.** When creating a PAT token, the UI offers `None / Only read / All` shortcuts for each scope group. The "All" preset is **not actually all scopes** — for example:

- "All" in **Online Store** group does NOT grant `shop.write` (cannot update shop via API)
- Some scopes are only available individually, not via preset

When generating a PAT token for write operations on shops/eshops, explicitly enable the specific
write checkbox for that resource type.

### Mapping UI labels → OAuth scopes (partially confirmed)

| UI label (in PAT creation) | OAuth scope |
|----------------------------|-------------|
| Reading feed audits | `projects.feedaudit.read` |
| Running feed audits | `projects.feedaudit.write` |
| Reading project data | `project.read` |
| Editing project data | `project.write` |
| Reading of rules | `project.rules.read` |
| Editing of rules | `project.rules.write` |
| Reading of queries | `project.queries.read` |
| Editing of queries | `project.queries.write` |
| ...(35 total in PAT UI; 38 OAuth scopes in API) | |

The 3 OAuth scopes not exposed in PAT UI are likely `shop.write`, `eshop.read`, and one other — needs further investigation if those operations are needed.

---

## Limitations & Known Gotchas

- **Creating shops/projects** is NOT available via MCP — use Mergado UI (`app.mergado.com`).
- **Reading data** works without `project.rules.write` scope.
- **Production MCP** was released after dev — some bugs exist only on prod (e.g. `get_current_user`).
- **`element_values_post` with `is_output=true`** returns last-export values, not real-time. After
  changing rules, you need to wait for next scheduled export (hourly) or rebuild manually in UI.
- **`trigger_project_rebuild` via MCP returns 404** — endpoint doesn't exist. Manual rebuild only via Mergado UI:
  - **Page:** *Rules* (Pravidla)
  - **Button:** *Regenerate changed* (CZ: *Přegenerovat změněné*)
  - This re-applies rules to the feed without waiting for the scheduled hourly sync.
- **System-managed rule types** (`format_converter`, `product`) should NOT be created via API even
  though the API allows it. Creates conflicts with system-generated counterparts.
- **`heurekawatchdog__pairing`** is only meaningful for Heureka output projects. UI in Google projects
  will show empty form when opening such a rule.
- **Output format compatibility**: Some rule types depend on the project's output format. Validate
  this manually — API doesn't.

---

## Pre-flight Checklist Before Creating Any Rule

1. ✅ Identify rule type (use list from this skill, not just `/rules/definitions/` — it's incomplete)
2. ✅ Decide format: simple vs struct (use **struct** if rule should be editable in UI)
3. ✅ Create queries if needed; reuse `♥ALLPRODUCTS♥` for "all products"
4. ✅ Set `applies: false` for safety; activate after review
5. ✅ Choose explicit `priority` (string, e.g. "100")
6. ✅ Include `queries` on top-level (required, even when types like `batch_rewriting` have `query_id` in `data`)
7. ✅ Name the rule clearly — humans will read it later

---

## When to Look at the Bug Report

Full bug report with reproduction steps, severity, and fix suggestions:
```
/Users/radimzhor/Documents/Mergado/MCP/bug-report.md
```

Read it when:
- A new bug seems to appear that's not covered here
- Talking to the Mergado dev team (they'll want details)
- Investigating MCP/API behavior that doesn't match expectations
