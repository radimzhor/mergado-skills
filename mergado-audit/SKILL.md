---
name: mergado-audit
description: >
  Workflow a reference pro práci s Mergado Feed Auditem — čtení výsledků auditu,
  interpretace issues (verdict, level, validator), mapování chyb na opravná pravidla
  a API endpointy. Použij vždy, když uživatel chce zkontrolovat kvalitu feedu,
  opravit chyby Google Shopping / Heureka / Zboží, nebo pracovat s /feedaudits/ API.
---

# Mergado Feed Audit

---

## API endpointy

| Endpoint | Účel |
|----------|------|
| `GET /projects/{id}/feedaudits/?limit=1` | Nejnovější audit projektu |
| `GET /feedaudits/{id}/` | Detail auditu (status, časy, počet chyb, počet produktů) |
| `GET /feedaudits/{id}/issues/?limit=100` | Všechny issues v auditu |
| `GET /feedaudit/products/{id}/issues/` | Issues konkrétního produktu |
| `GET /feedaudits/issues/{id}/` | Detail jednoho issue |
| `POST /projects/{id}/feedaudits/` | ❌ **HTTP 500** — server crash, nefunguje ani s plným scope. Audit lze spustit pouze z UI. |

### Scope
- Čtení: `projects.feedaudit.read` (pozor: **plural** `projects`, ne `project`)
- Spuštění: `projects.feedaudit.write` (nefunkční viz výše)

---

## Struktura issue

```json
{
  "id": "...",
  "audit_id": "...",
  "product_id": "...",          // null = issue platí pro celý feed (např. duplikáty)
  "level": "error | warning | recommendation",
  "verdict": "missing | wrong | duplicate | contains_html | ...",
  "validator": "enum_g_availability_google",
  "info": {
    "element": "G:AVAILABILITY",           // jeden element
    "elements": ["G:CONDITION", "G:SIZE"], // nebo více elementů
    "enum": ["in_stock", "out_of_stock"],  // povolené hodnoty (u wrong verdiktu)
    "value": "...",                         // duplicitní hodnota (u duplicate)
    "products": ["id1", "id2"],            // produkty sdílející duplicitu
    "duplicates": 2
  },
  "feed_types": ["google.cz", "google.uk", ...]
}
```

---

## Úrovně issues

| Level | Význam |
|-------|--------|
| `error` | Blokující chyba — produkt může být zamítnut v GMC |
| `warning` | Problém snižující kvalitu / viditelnost |
| `recommendation` | Doporučení pro lepší výkon (neblokuje) |

---

## Workflow: načtení a analýza auditu

```bash
TOKEN="..."
PROJECT_ID="..."

# 1) Nejnovější audit
AUDIT_ID=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.mergado.com/projects/$PROJECT_ID/feedaudits/?limit=1" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['data'][0]['id'])")

# 2) Shrnutí (status, počet produktů, chyb)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.mergado.com/feedaudits/$AUDIT_ID/"

# 3) Všechny issues
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://api.mergado.com/feedaudits/$AUDIT_ID/issues/?limit=100" \
  | python3 -c "
import json,sys
d=json.load(sys.stdin)
by_level={}
for i in d['data']:
    by_level.setdefault(i['level'],[]).append(i)
for lvl,issues in sorted(by_level.items()):
    print(f'{lvl.upper()} ({len(issues)})')
    for i in issues:
        elem=i.get('info',{}).get('element') or i.get('info',{}).get('elements','')
        print(f'  [{i[\"verdict\"]}] {elem}')
"
```

---

## Časté verdikty a jak je opravit pravidlem

### `wrong` — špatná hodnota enumu

| Element | Typická špatná hodnota | Správná hodnota | Pravidlo |
|---------|----------------------|-----------------|----------|
| `G:AVAILABILITY` | `yes`, `skladem`, `in stock` | `in_stock` | `rewriting` na `g:availability` |
| `G:CONDITION` | `novy`, `new condition`, `použitý` | `new` / `used` / `refurbished` | `rewriting` na `g:condition` |

```bash
# Oprava g:availability
curl -X PATCH "https://api.mergado.com/rules/{rule_id}/" \
  -d '{"data": {"$struct": {"rows": [{"elementPath": "$ep.1", "newContent": "$ref.1"}]},
       "$ref": {"$ref.1": "in_stock"}, "$ep": {"$ep.1": "g:availability"}}}'

# Nebo nové pravidlo přes POST /projects/{id}/rules/
# type: rewriting, element_path: g:availability, value: in_stock
```

---

### `missing` — chybí povinný element

| Validator | Chybějící elementy | Řešení |
|-----------|--------------------|--------|
| `is_present_chain_any_present_google_variant_attrs` | `G:ITEM_GROUP_ID`, `G:COLOR`, `G:SIZE`, `G:MATERIAL`, `G:PATTERN`, `G:AGE_GROUP`, `G:GENDER` | Pro variantové produkty doplnit `g:item_group_id`; jednoduché produkty tuto warning dostanou vždy — lze ignorovat |
| `is_present_g_gtin_google` | `G:GTIN` | Doplnit GTIN pravidlem nebo importem |
| `is_present_g_brand_google` | `G:BRAND` | Doplnit `rewriting` pravidlem |
| `is_present_g_google_product_category` | `G:GOOGLE_PRODUCT_CATEGORY` | Mapovat pomocí `categories` pravidla nebo `rewriting` |

---

### `duplicate` — duplicitní hodnota

| Element | Příčina | Řešení |
|---------|---------|--------|
| `G:TITLE` | Pravidlo truncate na příliš krátký max_length → různé produkty dostanou stejný titulek | Zvýšit `max_length` v truncating pravidle (doporučeno ≥ 100–150 znaků) |
| `G:ID` | Duplicitní identifikátory ve zdrojovém feedu | Opravit ve zdroji; v Mergadu nelze spolehlivě opravit |

---

### `contains_html` — HTML v textovém poli

| Element | Řešení |
|---------|--------|
| `G:DESCRIPTION` | Pravidlo `tagstripping` na `g:description` |
| `G:TITLE` | Pravidlo `tagstripping` na `g:title` (vzácné) |

```bash
curl -X POST "https://api.mergado.com/projects/{id}/rules/" \
  -d '{"name": "Strip HTML z g:description", "type": "tagstripping",
       "element_path": "g:description", "applies": true, "priority": "30",
       "queries": [{"id": "{ALLPRODUCTS_ID}"}], "data": {}}'
```

---

### Google validátory — přehled dalších issues

| Kategorie | Typické verdikty | Řešení |
|-----------|-----------------|--------|
| **Identifikátory** | invalid GTIN, invalid EAN (8/12–14 číslic) | `rewriting` na prázdno nebo import správných hodnot |
| **Zakázané znaky** | non-breaking spaces v titulu, kategorii, EAN | `rewriting` s regex nahrazením |
| **Promo obsah v titulu** | "doprava zdarma", "sleva", "© ™" | `rewriting` nebo Find & Replace pravidlo |
| **URL v textu** | URL v `g:title` nebo `g:description` | `rewriting` s regex |
| **Kategorie** | neúplná cesta, špatný oddělovač | `categories` pravidlo nebo `rewriting` |
| **Parametry** | invalid PARAM_NAME/PARAM value | opravit ve zdrojovém feedu nebo `rewriting` |

---

## Mapování issue → pravidlo (rychlý přehled)

| Issue | Pravidlo | Element |
|-------|----------|---------|
| `wrong` G:AVAILABILITY | `rewriting` | `g:availability` |
| `wrong` G:CONDITION | `rewriting` | `g:condition` |
| `contains_html` G:DESCRIPTION | `tagstripping` | `g:description` |
| `duplicate` G:TITLE (příliš krátký) | upravit `truncating` (zvýšit max_length) | `g:title` |
| `missing` G:GOOGLE_PRODUCT_CATEGORY | `rewriting` nebo `categories` | `g:google_product_category` |
| `missing` G:BRAND | `rewriting` | `g:brand` |
| promo obsah v titulu | `rewriting` s regex nebo Find & Replace | `g:title` / `title` |

---

## Audit v UI vs. API

| Akce | UI | API |
|------|----|----|
| Spustit nový audit | ✅ záložka Audit → Spustit audit | ❌ HTTP 500 |
| Číst výsledky | ✅ | ✅ `GET /feedaudits/{id}/issues/` |
| Filtrovat issues podle produktu | ✅ | ✅ `GET /feedaudit/products/{id}/issues/` |

Po spuštění auditu v UI — počkej na `status: done` (obvykle 3–10 sekund pro malé feedy).

---

## Tipy

- **product_count** v auditu ≠ počet issues — jeden produkt může mít více issues
- **product_id = null** u issue znamená feed-level problém (duplikáty napříč produkty)
- **feed_types** v issue říká pro které Google markety je problém relevantní — `google.cz` / `google.uk` atd.
- Po opravě pravidly je potřeba **přegenerovat feed** (UI → Pravidla → Přegenerovat změněné) a pak spustit nový audit pro ověření

Zdroj: [Mergado KB — Audit produktových dat](https://help.mergado.com/cs/audit-produktovych-dat/) · [Google validátory](https://help.mergado.com/cs/audit-produktovych-dat/google-validatory/google-feed-validators-1-definice-chyb-a-doporucena-reseni-mergado-audit)
