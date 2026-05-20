---
name: mergado-elements
description: >
  Reference pro práci s elementy a atributy v Mergadu — typy elementů (simple, vícenásobné,
  zanořené, atributové), origin (input/from_rule), hidden elementy, API pro výpis a vytváření
  vlastních elementů, časté XML struktury s cestami (PARAM, g:product_detail, VARIANTS, metafields).
  Použij vždy, když uživatel chce zjistit strukturu elementů projektu, vytvořit vlastní element,
  pochopit rozdíl mezi vstupními a výstupními elementy, nebo identifikovat element podle jeho
  origin/hidden příznaků. Pro syntaxi Element Path (|, {}, @@, #) použij anthropic-skills:mergado-element-path.
---

# Mergado — Elementy a atributy

> **Syntaxe Element Path** (pokročilé cesty, filtrování, @@POSITION, #indexace) je pokryta
> v `anthropic-skills:mergado-element-path`. Tento skill se zaměřuje na typy elementů,
> API a správu.

---

## Typy elementů

| Typ | Popis | Příklad |
|-----|-------|---------|
| **Jednoduchý** | Jedna hodnota | `g:title`, `ITEM_ID`, `PRICE_VAT` |
| **Vícenásobný** | Více hodnot (opakující se tag) | `IMGURL_ALTERNATIVE`, `CATEGORYTEXT` |
| **Zanořený** | Potomek jiného elementu | `PARAM | VAL`, `g:product_detail | g:attribute_value` |
| **Atributový** | Hodnota XML atributu (@ prefix) | `VARIANT { @id = "..." }`, `CATEGORIES | @id` |

---

## Origin — vstupní vs. výstupní elementy

```json
{
  "path": "g:title",
  "origin": "input",      // ze zdrojového feedu (raw)
  "hidden": true          // není ve výstupu — jen pro interní zpracování
}
```

```json
{
  "path": "g:title",
  "origin": "from_rule",  // generovaný pravidlem (ve výstupu)
  "hidden": false
}
```

| `origin` | Zdroj | Kdy použít |
|----------|-------|------------|
| `"input"` | Zdrojový feed | Pro MQL výběry a `is_output=false` dotazy |
| `"from_rule"` | Výsledek pravidel | Ve výstupu — to co jde do Google/Heureka |

> **Klíčový gotcha:** UK Google projekty mají vstupní element `title` (`origin: input`),
> nikoli `g:title`. Pro MQL výběr nad vstupními daty vždy ověř správný název elementu.

---

## API — výpis elementů projektu

### `list_project_elements` (MCP tool funguje ✅)

```bash
# Přes MCP
mcp__mergado__list_project_elements(project_id="353819")

# Přes REST
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.mergado.com/projects/353819/elements/"
```

### Struktura odpovědi

```json
{
  "data": [
    {
      "id": "...",
      "path": "g:title",
      "origin": "from_rule",
      "hidden": false,
      "type": "string",
      "children": []
    },
    {
      "id": "...",
      "path": "g:product_detail",
      "origin": "from_rule",
      "hidden": false,
      "type": "string",
      "children": [
        {"path": "g:product_detail | g:attribute_name", ...},
        {"path": "g:product_detail | g:attribute_value", ...}
      ]
    }
  ]
}
```

### Jak najít vstupní elementy (raw feed)

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.mergado.com/projects/$PROJECT_ID/elements/" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
print('=== INPUT elementy ===')
for e in d['data']:
    if e.get('origin') == 'input':
        print(f\"  {e['path']}  (hidden={e.get('hidden')})\")
print()
print('=== OUTPUT elementy (from_rule) ===')
for e in d['data']:
    if e.get('origin') == 'from_rule' and not e.get('hidden'):
        print(f\"  {e['path']}\")"
```

---

## Vlastní elementy — vytvoření přes API

Vlastní element = uložená hodnota navázaná na pravidlo nebo ruční editaci. Využívá se pro
přechodné hodnoty nebo data importovaná z externího zdroje.

```bash
curl -s -X POST "https://api.mergado.com/projects/$PROJECT_ID/elements/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "path": "my_custom_element",
    "type": "string"
  }'
```

> ⚠️ API `create_element` vyžaduje `element_path` (undocumented) — pokud selže,
> viz bug report v `mergado-mcp` skillu.

### Smazání elementu

```bash
curl -s -X DELETE "https://api.mergado.com/elements/{ELEMENT_ID}/" \
  -H "Authorization: Bearer $TOKEN"
# HTTP 204 = úspěch
```

---

## Doplněk k Element Path: `@@MAX_POSITION`

> Syntaxe Element Path (`|`, `{}`, `@@POSITION`, `@@VALUE`, `#{ }`) je v `anthropic-skills:mergado-element-path`.
> Zde je pouze `@@MAX_POSITION`, který v tom skillu chybí.

`@@MAX_POSITION` vrací celkový počet výskytů vícenásobného elementu. Použití: cílení na **poslední prvek** bez znalosti přesného počtu.

```
IMAGE { @@POSITION = @@MAX_POSITION }        ← poslední obrázek
```

Nelze použít samostatně — vždy jen jako hodnota v porovnání s `@@POSITION`.

---

## Časté struktury elementů

### Parametry produktu (Heureka / XML feed)
```xml
<PARAM>
  <PARAM_NAME>Barva</PARAM_NAME>
  <VAL>Černá</VAL>
</PARAM>
```
```
Element path:  PARAM | VAL
Filtrovaný:    PARAM { PARAM_NAME = "Barva" } | VAL
```

### Google Shopping — product detail
```xml
<g:product_detail>
  <g:attribute_name>Tloušťka</g:attribute_name>
  <g:attribute_value>8 mm</g:attribute_value>
</g:product_detail>
```
```
Element path:  g:product_detail | g:attribute_value
Filtrovaný:    g:product_detail { g:attribute_name = "Tloušťka" } | g:attribute_value
```

### Varianty produktu
```xml
<VARIANTS>
  <VARIANT id="v1">
    <COLOR>Červená</COLOR>
    <SIZE>XL</SIZE>
  </VARIANT>
</VARIANTS>
```
```
Element path:  VARIANTS | VARIANT | COLOR
Filtrovaný:    VARIANTS | VARIANT { @id = "v1" } | SIZE
```

### Alternativní obrázky
```
IMGURL_ALTERNATIVE                          ← všechny alternativní obrázky
IMGURL_ALTERNATIVE { @@POSITION = 1 }      ← první
IMGURL_ALTERNATIVE { @@POSITION = 2 }      ← druhý
```

### Metafields (Shopify feed)
Párové key/value — čti vždy oba elementy a zarovnej podle pořadí:
```
metafields | key                ← ["color-pattern", "material"]
metafields | value              ← ["Green", "Glass, Neoprene"]
```

---

## Elementy v MQL výběrech

MQL výběry pracují se **vstupními** hodnotami (`origin: input`). Výstupní `from_rule` elementy
v MQL nefungují spolehlivě — používají naposledy uložené výstupní hodnoty, ne aktuální.

```
# Správně — vstupní element
title CONTAINS "Continental"          ← pro UK projekt
ITEM_ID = "KH9365023"

# Pozor — g: elementy v MQL = výstupní snapshot, ne real-time
g:title CONTAINS "Continental"        ← může vrátit zastaralé výsledky
```

Viz `mergado-mql` skill pro kompletní MQL syntaxi.

---

## API endpointy — přehled

| Endpoint | Účel |
|----------|------|
| `GET /projects/{id}/elements/` | Seznam všech elementů projektu |
| `GET /elements/{id}/` | Detail elementu |
| `POST /projects/{id}/elements/` | Vytvoř vlastní element |
| `DELETE /elements/{id}/` | Smaž vlastní element |
| `POST /projects/{id}/products/elements/` | Hodnoty elementu přes `element_values_post` |

Pro čtení hodnot elementů viz `mergado-products-export` skill.
