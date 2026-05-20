---
name: mergado-rules
description: >
  Kompletní reference pro vytváření a správu pravidel v Mergadu přes API — typy pravidel,
  datové formáty (simple vs struct), priority, výběry (queries), known bugs a workarounds.
  Použij vždy, když uživatel chce vytvořit, upravit nebo smazat pravidlo v Mergadu přes API
  nebo MCP, nebo se ptá na typ pravidla (přepsat, hromadné přepisování, kategorii, parametry,
  zkrácení, tagstripping, skrytí, výpočet, najít a nahradit).
---

# Mergado — Pravidla (Rules)

---

## Sdílené koncepty — platí pro všechna pravidla

### Vytvoření pravidla — vždy přes REST API

```bash
curl -s -X POST "https://api.mergado.com/projects/{PROJECT_ID}/rules/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{...}'
```

> ⚠️ MCP `create_rule` nelze použít pro `batch_rewriting`, `batch_param`, `categories` — data jsou array, MCP tool očekává object. Pro tyto typy **vždy REST API**.

### Povinné parametry při vytvoření

| Parametr | Typ | Popis |
|----------|-----|-------|
| `name` | string | Název pravidla (zobrazuje se v UI) |
| `type` | string | Typ pravidla (viz tabulka níže) |
| `priority` | string | Pořadí aplikace — nižší číslo = dříve; formát: `"100"` nebo `"1E+2"` |
| `applies` | bool | `false` = vytvoř jako vypnuté (doporučeno pro review) |
| `queries` | array | Seznam výběrů — `[{"id": "ALLPRODUCTS_ID"}]` nebo konkrétní výběr |
| `data` | object/array | Konfigurace pravidla — závisí na type |

### Jak získat ALLPRODUCTS query ID

```bash
# Z list_project_queries — hledej name: "♥ALLPRODUCTS♥", read_only: true
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.mergado.com/projects/{PROJECT_ID}/queries/" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
for q in d['data']:
    if q.get('read_only'):
        print(q['id'], q['name'])"
```

### Aktualizace pravidla — vždy REST PATCH

```bash
# Zapnout / vypnout pravidlo
curl -s -X PATCH "https://api.mergado.com/rules/{RULE_ID}/" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"applies": true}'

# Změnit data pravidla
curl -s -X PATCH "https://api.mergado.com/rules/{RULE_ID}/" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"data": {...}}'
```

> ⚠️ MCP `update_rule` vrací HTTP 405 — vždy použij REST PATCH.

### Smazání pravidla

```bash
curl -s -X DELETE "https://api.mergado.com/rules/{RULE_ID}/" \
  -H "Authorization: Bearer $TOKEN"
# HTTP 204 = úspěch
```

### Priority — pořadí aplikace

- Pravidla se aplikují **odshora dolů** (nižší priorita = dříve)
- Pokud PATCH nastaví prioritu na již existující hodnotu, Mergado ji může auto-upravit na zlomek (např. `"5"` → `"5.5"`)
- Systémové pravidlo `format_converter` má prioritu 1 — nenastavuj uživatelská pravidla na 1

### data formát: Simple vs Struct

**Simple format** — dokumentovaný, ale UI ho neumí editovat:
```json
{"new_content": "hodnota"}
```

**Struct format** — nezdokumentovaný, UI ho plně edituje ✅:
```json
{
  "$struct": {"rows": [{"elementPath": "$ep.1", "newContent": "$ref.1"}]},
  "$ref":    {"$ref.1": "hodnota"},
  "$ep":     {"$ep.1": "g:brand"}
}
```

> **Pravidlo:** Vždy používej struct format, pokud uživatel bude pravidlo editovat v UI. Pro headless integrace postačí simple.

---

## Přehled typů pravidel

| UI název (CZ) | API `type` | Data formát | REST nutný? |
|--------------|-----------|-------------|-------------|
| Přepsat | `rewriting` | object (simple/struct) | ❌ lze MCP |
| Najít a nahradit | `rewriting` s regex | object | ❌ lze MCP |
| Hromadné přepisování dle výběrů | `batch_rewriting` | **array** | ✅ vždy REST |
| Hromadné přepisování dle hodnot | `batch_rewriting_values` | array + `additional_data` | ✅ REST; `additional_data` jen UI |
| Hromadné přejmenování kategorií | `categories` | **array** | ✅ vždy REST |
| Nastavit parametry produktů | `batch_param` | struct s `epParam` | ✅ vždy REST |
| Zkrácení hodnoty | `truncating` | object | ❌ lze MCP |
| Odstranit HTML značky | `tagstripping` | `{}` | ❌ lze MCP |
| Odstranit diakritiku | `remove_diacritics` | `{}` | ❌ lze MCP |
| Skrytí produktů | `hiding` | `{}` | ❌ lze MCP |
| Zaokrouhlit číslo | `rounding` | object | ❌ lze MCP |
| Výpočet | `formula` | object | ❌ lze MCP |
| Přidat hodnotu vícenásobného elementu | `adding` | object | ❌ lze MCP |
| Hromadné zkopírování hodnot | `batch_copying` | object | ❌ lze MCP |
| Odstranit hodnoty parametrů | `params_remove_by_value` | struct | ❌ lze MCP |
| Import datového souboru | `data_import` | struct (`$ep: []` pro CSV) | ✅ REST; viz **mergado-data-import** skill |

---

## Pravidlo: Přepsat (`rewriting`)

Nastaví pevnou nebo dynamickou hodnotu elementu pro všechny produkty ve výběru.

### Simple format
```json
{
  "name": "Nastav g:condition",
  "type": "rewriting",
  "element_path": "g:condition",
  "applies": false,
  "priority": "100",
  "queries": [{"id": "ALLPRODUCTS_ID"}],
  "data": {"new_content": "new"}
}
```

### Struct format (UI-editovatelný) ✅
```json
{
  "name": "Nastav g:brand",
  "type": "rewriting",
  "element_path": null,
  "applies": false,
  "priority": "100",
  "queries": [{"id": "ALLPRODUCTS_ID"}],
  "data": {
    "$struct": {"rows": [{"elementPath": "$ep.1", "newContent": "$ref.1"}]},
    "$ref":    {"$ref.1": "Continental"},
    "$ep":     {"$ep.1": "g:brand"}
  }
}
```

### Dynamická reference — `%element%` syntaxe
```json
"$ref": {"$ref.1": "%g:brand% %g:title%"}
```
- `%g:title%` → aktuální hodnota elementu g:title pro daný produkt
- `%MY_VARIABLE%` → hodnota Mergado proměnné (viz `list_project_variables`)
- Pořadí: pravidlo čte hodnoty v momentě své aplikace — elementy upravené dřívějšími pravidly budou mít již upravenou hodnotu

---

## Pravidlo: Najít a nahradit (`rewriting` s regex)

Vyhledá text nebo regulární výraz a nahradí ho. Funguje jako `sed`.

```json
{
  "name": "Odstraň promo text z titulu",
  "type": "rewriting",
  "element_path": "g:title",
  "applies": false,
  "priority": "100",
  "queries": [{"id": "ALLPRODUCTS_ID"}],
  "data": {
    "search": "doprava zdarma|sleva|AKCE",
    "replace": "",
    "case_sensitive": false,
    "use_regex": true
  }
}
```

| Parametr | Popis |
|----------|-------|
| `search` | Hledaný text nebo regex |
| `replace` | Náhrada (prázdný string = smazání) |
| `case_sensitive` | Rozlišování velikosti písmen |
| `use_regex` | `true` = regulární výraz |

> **Poznámka:** V UI se zobrazuje jako samostatný typ „Najít a nahradit", ale v API jde o `rewriting` s jiným datovým formátem.

---

## Pravidlo: Hromadné přepisování dle výběrů (`batch_rewriting`)

Per-výběr různé hodnoty v jednom pravidle. Každý řádek = jiná hodnota pro jiný výběr produktů.

```bash
curl -s -X POST "https://api.mergado.com/projects/{PROJECT_ID}/rules/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "SEO tituly",
    "type": "batch_rewriting",
    "element_path": "g:title",
    "applies": false,
    "priority": "100",
    "queries": [{"id": "Q1"}, {"id": "Q2"}, {"id": "Q3"}],
    "data": [
      {"position": 1, "query_id": "Q1", "value": "Continental ContiSportContact 5 235/45R18 98W XL"},
      {"position": 2, "query_id": "Q2", "value": "Pirelli P Zero 245/40R20 99Y XL"},
      {"position": 3, "query_id": "Q3", "value": "Michelin Pilot Sport 4 225/45R17 94Y"}
    ]
  }'
```

- `queries` na top-level = všechny výběry, na které pravidlo platí
- `data[].query_id` = ke kterému výběru patří daná hodnota
- `position` = pořadí (1-based, unikátní)
- Každý výběr Q musí existovat před vytvořením pravidla

---

## Pravidlo: Hromadné přejmenování kategorií (`categories`)

Mapuje zdrojové kategorie (vstup) na cílové (výstup). Klíčové pro Google Shopping taxonomy.

```bash
curl -s -X POST "https://api.mergado.com/projects/{PROJECT_ID}/rules/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Google kategorie mapping",
    "type": "categories",
    "element_path": "g:google_product_category",
    "applies": false,
    "priority": "20",
    "queries": [{"id": "ALLPRODUCTS_ID"}],
    "data": [
      {"position": 1, "input": "Pneumatiky > Letní", "output": "6093"},
      {"position": 2, "input": "Pneumatiky > Zimní", "output": "6093"},
      {"position": 3, "input": "Pneumatiky > Offroad", "output": "7252"},
      {"position": 4, "input": "Pneumatiky > Moto", "output": "6091"}
    ]
  }'
```

- `input` = hodnota ze zdrojového feedu (element `g:product_type` nebo `CATEGORYTEXT`)
- `output` = cílová hodnota (Google taxonomy ID nebo textový path)
- Párování je case-insensitive, partial match funguje (prefix matching)
- Pro Google taxonomy ID viz `mergado-google-shopping` skill

---

## Pravidlo: Nastavit parametry produktů (`batch_param`)

Přidá nebo nastaví produktové parametry (např. `g:product_detail`) různým skupinám produktů.

```bash
curl -s -X POST "https://api.mergado.com/projects/{PROJECT_ID}/rules/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Doplnit g:product_detail - tloušťka",
    "type": "batch_param",
    "element_path": null,
    "applies": false,
    "priority": "200",
    "queries": [{"id": "ALLPRODUCTS_ID"}],
    "data": {
      "$struct": {
        "rows": [
          {
            "elementPath": "$epParam.1",
            "epParamName": "$epParamName.1",
            "epParamValue": "$epParamValue.1",
            "newParamName": "$refParamName.1",
            "newContent": "$refParamValue.1"
          }
        ]
      },
      "$epParam":      {"$epParam.1": "g:product_detail"},
      "$epParamName":  {"$epParamName.1": "g:product_detail | g:attribute_name"},
      "$epParamValue": {"$epParamValue.1": "g:product_detail | g:attribute_value"},
      "$refParamName": {"$refParamName.1": "Tloušťka"},
      "$refParamValue": {"$refParamValue.1": "%TLOUSTKA%"}
    }
  }'
```

- `%TLOUSTKA%` = Mergado proměnná (regex extrakce z jiného elementu) — viz `list_project_variables`
- Lze použít i pevnou hodnotu místo proměnné: `"$refParamValue.1": "8 mm"`
- Pro více parametrů/výběrů = více rows v `$struct.rows`

---

## Pravidlo: Zkrácení hodnoty (`truncating`)

Zkrátí text na max. počet znaků.

```json
{
  "name": "Zkrácení g:title na 150 znaků",
  "type": "truncating",
  "element_path": "g:title",
  "applies": false,
  "priority": "150",
  "queries": [{"id": "ALLPRODUCTS_ID"}],
  "data": {
    "max_length": 150,
    "intelligent": true,
    "truncate_prepositions": false,
    "append": "..."
  }
}
```

| Parametr | Popis |
|----------|-------|
| `max_length` | Maximální délka v znacích |
| `intelligent` | Neořezávej uprostřed slova |
| `truncate_prepositions` | Odstraní předložky na konci zkráceného textu |
| `append` | Přidá text na konec zkráceného řetězce (nesmí překročit max_length) |

> **Pozor:** `max_length` příliš nízký → duplicitní tituly (různé produkty dostanou stejný zkrácený titulek). Doporučeno ≥ 100–150 pro g:title.

---

## Pravidlo: Odstranit HTML značky (`tagstripping`)

Odstraní všechny HTML tagy z textu elementu. Zachová textový obsah.

```json
{
  "name": "Strip HTML z g:description",
  "type": "tagstripping",
  "element_path": "g:description",
  "applies": false,
  "priority": "30",
  "queries": [{"id": "ALLPRODUCTS_ID"}],
  "data": {}
}
```

Vstup: `<p><strong>Nová kolekce</strong> – doprava zdarma!</p>`
Výstup: `Nová kolekce – doprava zdarma!`

---

## Pravidlo: Odstranit diakritiku (`remove_diacritics`)

Nahradí znaky s diakritikou jejich ASCII ekvivalenty.

```json
{
  "name": "Odstranit diakritiku z g:title",
  "type": "remove_diacritics",
  "element_path": "g:title",
  "applies": false,
  "priority": "110",
  "queries": [{"id": "ALLPRODUCTS_ID"}],
  "data": {}
}
```

---

## Pravidlo: Skrytí produktů (`hiding`)

Skryje produkty ve výběru z výstupního feedu.

```json
{
  "name": "Skrýt vyprodané produkty",
  "type": "hiding",
  "element_path": null,
  "applies": false,
  "priority": "5",
  "queries": [{"id": "OUT_OF_STOCK_QUERY_ID"}],
  "data": {}
}
```

- Produkt ve výstupu zmizí — není exportován
- Chceš-li skrýt vše **kromě** výběru, použij opačný výběr v MQL: `NOT(podmínka)` — viz `mergado-mql` skill

---

## Pravidlo: Zaokrouhlit číslo (`rounding`)

```json
{
  "name": "Zaokrouhlit ceny na .99",
  "type": "rounding",
  "element_path": "g:price",
  "applies": false,
  "priority": "120",
  "queries": [{"id": "ALLPRODUCTS_ID"}],
  "data": {
    "precision": "0.99",
    "type": "up"
  }
}
```

| `precision` | Výsledek |
|-------------|---------|
| `"1"` | Celé číslo |
| `"0.1"` | Na desetiny |
| `"0.01"` | Na setiny |
| `"100"` | Na stovky |
| `"0.5"` | Na půlky |
| `"0.9"` | Koncovka .9 |
| `"0.99"` | Koncovka .99 |

| `type` | Typ zaokrouhlení |
|--------|-----------------|
| `"up"` | Vždy nahoru |
| `"down"` | Vždy dolů |
| `"math"` | Matematicky |

---

## Workflow: kompletní vytvoření pravidla

```bash
TOKEN="mergado_pat_..."
PROJECT_ID="353819"

# 1) Zjisti ALLPRODUCTS query ID
ALLPRODUCTS=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.mergado.com/projects/$PROJECT_ID/queries/" \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
for q in d['data']:
    if q.get('read_only'): print(q['id'])" )

echo "ALLPRODUCTS ID: $ALLPRODUCTS"

# 2) Vytvoř pravidlo (příklad: tagstripping na g:description)
curl -s -X POST "https://api.mergado.com/projects/$PROJECT_ID/rules/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Strip HTML z g:description\",
    \"type\": \"tagstripping\",
    \"element_path\": \"g:description\",
    \"applies\": false,
    \"priority\": \"30\",
    \"queries\": [{\"id\": \"$ALLPRODUCTS\"}],
    \"data\": {}
  }" | python3 -c "import json,sys; d=json.load(sys.stdin); print('Rule ID:', d.get('id','ERROR'), d.get('name',''))"

# 3) Zkontroluj → v UI zapni (nebo přes PATCH applies: true)
```

---

## Časté chyby při vytváření pravidel přes API

| Chyba | Příčina | Oprava |
|-------|---------|--------|
| `create_rule` selže se `[...]` is not valid | MCP tool stringifikuje array pro `batch_rewriting`/`categories`/`batch_param` | Použij REST API přímo |
| `update_rule` vrátí HTTP 405 | MCP tool používá špatnou HTTP metodu | Použij REST PATCH |
| Pravidlo vytvořeno, ale v UI prázdný formulář | Simple data format | Přepni na struct format |
| Priority conflict | Stejná priorita existuje | Mergado auto-adjustuje na zlomek — nevadí |
| `queries` prázdné nebo chybí | API nevyhodí chybu, ale pravidlo se neaplikuje na žádné produkty | Vždy zkontroluj `queries` v odpovědi |
| Broken rule bez error | API neprovádí validaci `data` struktury | Ověř pravidlo v UI před zapnutím |

---

## Scope pro vytváření pravidel

```
project.rules.write   ← nutný pro create_rule, update_rule, delete_rule
```

Bez scope → HTTP 403: `Bearer token scope not valid. Required scopes: [project.rules.write]`
