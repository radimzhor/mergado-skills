---
name: mergado-products-export
description: >
  Vzory pro načítání hodnot produktů z Mergadu bez přetížení kontextu — element_values_post
  pro agregovaná data, list_project_products_post s MQL + values_to_extract přes JSON-RPC
  pro per-produkt hodnoty, export do CSV. Použij vždy, když potřebuješ zjistit hodnoty elementů
  pro konkrétní produkty nebo podmnožinu produktů, porovnat vstupní vs. výstupní hodnoty,
  nebo exportovat data do souboru.
---

# Mergado — Načítání hodnot produktů

---

## Tři přístupy — kdy použít který

| Přístup | Kdy | Výstup |
|---------|-----|--------|
| `element_values_post` (JSON-RPC) | Chci vědět **jaké různé hodnoty** element obsahuje napříč celým feedem | Agregovaný seznam unikátních hodnot (počty výskytů) |
| `list_project_products_post` + MQL + `values_to_extract` (JSON-RPC) | Chci hodnoty **konkrétních produktů** (filtr podle g:id, brand, kategorie…) | Per-produkt seznam s hodnotami elementů |
| `GET /projects/{id}/products/` (REST) | Základní listing bez filtrování | Paginated list, bez values_to_extract |

> **Klíčové pravidlo:** Nikdy nenačítej všechny produkty bez MQL filtru — v projektu může být tisíce produktů a odpověď přetíží kontext. Vždy filtruj nebo agreguj.

---

## Přístup 1 — element_values_post (agregovaná data)

Vrátí seznam unikátních hodnot elementu + počet výskytů. **Nefiltrovatelné per produkt.**

### ⚠️ MCP tool je broken (output schema mismatch) → použij JSON-RPC

```bash
TOKEN="mergado_pat_..."
PROJECT_ID="353819"
ELEMENT="g:availability"   # nebo "title", "g:brand", "g:product_type", atd.

curl -s -X POST "https://mcp.mergado.com/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{
    \"name\":\"element_values_post\",
    \"arguments\":{
      \"project_id\":\"$PROJECT_ID\",
      \"element_path\":\"$ELEMENT\",
      \"is_output\":false
    }
  }}" | python3 -c "
import json, sys
r = json.load(sys.stdin)
data = json.loads(r['result']['content'][0]['text'])
values = data.get('values', data.get('data', []))
for v in values[:30]:
    print(f\"{v.get('count','?'):>6}x  {v.get('value','?')}\")"
```

### Parametry

| Parametr | Hodnota | Popis |
|----------|---------|-------|
| `is_output=false` | Vstupní data | Surové hodnoty ze zdrojového feedu |
| `is_output=true` | Výstupní data | Hodnoty z **posledního vygenerovaného exportu** (ne real-time po změně pravidel) |

---

## Přístup 2 — list_project_products_post + MQL + values_to_extract

Per-produkt hodnoty pro filtrovanou podmnožinu produktů.

### ⚠️ MCP tool stringifikuje array parametry → použij JSON-RPC

```bash
TOKEN="mergado_pat_..."
PROJECT_ID="353819"

# Příklad: načíst g:title a g:link pro 2 konkrétní produkty
curl -s -X POST "https://mcp.mergado.com/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "list_project_products_post",
      "arguments": {
        "project_id": "353819",
        "mql": "g:id IN (\"KH9365023\"; \"CN03572760000\")",
        "values_to_extract": ["g:title", "g:link"],
        "is_output": true,
        "limit": 100
      }
    }
  }' | python3 -c "
import json, sys
r = json.load(sys.stdin)
data = json.loads(r['result']['content'][0]['text'])
for p in data.get('data', []):
    pid = p.get('id', '?')
    ev = p.get('extracted_values', {})
    title = ev.get('g:title', ['?'])[0] if ev.get('g:title') else '?'
    link = ev.get('g:link', ['?'])[0] if ev.get('g:link') else '?'
    print(f'{pid}: {title}')
    print(f'  {link}')
"
```

### Struktura odpovědi

```json
{
  "data": [
    {
      "id": "KH9365023",
      "extracted_values": {
        "g:title": ["Kumho Ecowing ES31 175/65R15 84H"],
        "g:link": ["https://example.com/product/KH9365023"]
      },
      "data": {
        "elements": {
          "g:title": [{"value": "Kumho Ecowing ES31 175/65R15 84H"}],
          "g:link": [{"value": "https://example.com/product/KH9365023"}]
        }
      }
    }
  ]
}
```

Hodnoty čti z `extracted_values.{element}[0]` (primární) nebo `data.elements.{element}[0].value` (fallback).

### Časté MQL filtry pro values_to_extract

```bash
# Konkrétní produkty (preferuj IN nad OR řetězcem)
"g:id IN (\"ID1\"; \"ID2\"; \"ID3\")"

# Brand filtr
"g:brand = \"Continental\""

# Brand + podmínka na title (vstupní element UK projektu je "title", ne "g:title"!)
"g:brand = \"Continental\" AND title NOT CONTAINS \"Continental\""

# Prázdný element
"g:gtin IS EMPTY"

# Regulární výraz
"g:gtin ~ \"^\\d{13}$\""
```

> **Pozor na název vstupního elementu:** UK projekt má vstupní element `title` (ne `g:title`). Vždy ověř správný název přes `list_project_elements` nebo `element_values_post`.

---

## Export do CSV

```bash
TOKEN="mergado_pat_..."
PROJECT_ID="353819"

curl -s -X POST "https://mcp.mergado.com/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0", "id": 1, "method": "tools/call",
    "params": {
      "name": "list_project_products_post",
      "arguments": {
        "project_id": "353819",
        "mql": "g:brand = \"Continental\"",
        "values_to_extract": ["g:id", "g:title", "g:link", "g:price"],
        "is_output": true,
        "limit": 200
      }
    }
  }' | python3 -c "
import json, sys, csv, io

r = json.load(sys.stdin)
data = json.loads(r['result']['content'][0]['text'])
products = data.get('data', [])

fields = ['g:id', 'g:title', 'g:link', 'g:price']
writer = csv.writer(sys.stdout)
writer.writerow(fields)
for p in products:
    ev = p.get('extracted_values', {})
    row = [ev.get(f, [''])[0] if ev.get(f) else '' for f in fields]
    writer.writerow(row)
" > /tmp/products_export.csv

echo "Exportováno $(wc -l < /tmp/products_export.csv) řádků do /tmp/products_export.csv"
```

---

## Omezení a gotchas

### `limit` a stránkování

- Default `limit`: 10 (málokdy dost)
- Max doporučený limit: **200–500** (větší může přetížit kontext)
- Pro větší sady používej `offset` pro stránkování nebo filtruj MQL úžeji

```bash
# Stránka 2 (offset 200, limit 200)
"limit": 200, "offset": 200
```

### `is_output=true` vs `is_output=false`

- `is_output=false` = surové hodnoty ze zdrojového feedu (ihned aktuální)
- `is_output=true` = hodnoty z **posledního vygenerovaného exportu** — po změně pravidel nejsou aktuální, dokud se feed nepřegeneruje (default hodinový plán nebo manuálně v UI)

### `values_to_extract` s neexistujícím elementem

Pokud element pro daný produkt neexistuje nebo je prázdný, `extracted_values.{element}` bude prázdný array nebo klíč chybí. Vždy používej `.get(f, [''])[0] if ev.get(f) else ''` pattern.

### Velké odpovědi

`list_project_products_post` bez MQL filtru na velkém projektu (tisíce produktů) → odpověď přetíží kontext. Vždy:
1. Filtruj MQL (brand, kategorie, ID seznam)
2. Nebo použij `element_values_post` pro agregovaná data
3. Nebo spusť v Agent subagent a nechej ho zpracovat a vrátit jen výsledek

---

## Jak zjistit správné názvy elementů

```bash
# Všechny elementy projektu
mcp__mergado__list_project_elements(project_id)

# Nebo zkontroluj pár unikátních hodnot — pokud element neexistuje, vrátí prázdné
# element_values_post s is_output=false → input element names (title, vendor, price...)
# element_values_post s is_output=true → output element names (g:title, g:price...)
```

Elementy s `origin: "input"` jsou ze zdrojového feedu. Elementy s `origin: "from_rule"` jsou generované pravidly.

---

## Vytvoření výběru produktů pro pozdější použití v pravidlech

Pokud chceš podmnožinu produktů použít v pravidle, nestačí jen načíst hodnoty — musíš vytvořit Mergado query:

```bash
# Vytvoř výběr — pak ho přiřaď k pravidlu místo ALLPRODUCTS
curl -s -X POST "https://api.mergado.com/projects/{PROJECT_ID}/queries/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Continental bez brand v title",
    "query": "g:brand = \"Continental\" AND title NOT CONTAINS \"Continental\""
  }'

# Počet produktů ve výběru (asynchronní — None = 0 produktů, číslo = hotovo)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.mergado.com/queries/{QUERY_ID}/" | python3 -c "
import json, sys; d=json.load(sys.stdin)
print(f'Produktů: {d[\"product_count\"]}')
"
```

> **Poznámka:** `product_count = None` znamená **0 produktů** (ne nevyhodnoceno). Tak Mergado API reportuje prázdné výběry.

Viz `mergado-mql` skill pro kompletní MQL syntaxi a operátory.
