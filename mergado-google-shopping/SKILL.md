---
name: mergado-google-shopping
description: >
  Reference pro optimalizaci Google Shopping feedů v Mergadu — povinné a doporučené elementy,
  validní hodnoty (availability, condition), Google taxonomy lookup, mapování kategorií,
  typické GMC chyby a jak je opravit Mergado pravidly. Použij vždy, když uživatel
  optimalizuje feed pro Google Shopping, řeší neschválené produkty v GMC, mapuje kategorie,
  nebo se ptá na správné hodnoty g:availability, g:condition, g:google_product_category.
---

# Google Shopping — Feed Reference pro Mergado

---

## Povinné elementy Google Shopping

| Element (Mergado) | Google atribut | Požadavek |
|-------------------|---------------|-----------|
| `g:id` | `id` | Unikátní, max 50 znaků, neměnit po publikaci |
| `title` / `g:title` | `title` | Max 150 znaků, musí odpovídat titulu na webu, bez promo textu |
| `description` / `g:description` | `description` | Max 5000 znaků, čistý text (bez HTML), bez promo textu |
| `link` / `g:link` | `link` | Musí začínat https, ověřená doména v GMC |
| `g:image_link` | `image_link` | Min 500×500 px, JPEG/PNG/WebP |
| `g:price` | `price` | Musí odpovídat ceně na webu, formát: `199.00 CZK` |
| `g:availability` | `availability` | Viz povolené hodnoty níže |
| `g:brand` | `brand` | Povinný pro nové produkty (kromě knih, filmů) |

---

## Povolené hodnoty klíčových elementů

### `g:availability`
```
in_stock       ← skladem
out_of_stock   ← vyprodáno
preorder       ← předobjednávka
backorder      ← na objednávku
```
❌ Časté chyby: `yes`, `skladem`, `in stock`, `ano`, `1`

### `g:condition`
```
new            ← nové zboží
refurbished    ← repasované
used           ← použité
```
❌ Časté chyby: `novy`, `nové`, `new condition`, `použitý`

### `g:availability_date`
Povinné při `preorder` nebo `backorder`. Formát ISO 8601: `2025-12-31T00:00:00+01:00`

---

## Doporučené elementy (zvyšují výkon v Google Shopping)

| Element | Poznámka |
|---------|----------|
| `g:gtin` | Silně doporučeno — EAN/UPC/ISBN, 8/12/13/14 číslic |
| `g:mpn` | Povinné pokud chybí GTIN; max 70 znaků |
| `g:google_product_category` | Viz sekce Taxonomy níže |
| `g:product_type` | Vlastní kategorie eshopu — doplňuje google_product_category |
| `g:additional_image_link` | Až 10 dalších fotek |
| `g:color` | Povinné pro variantní oděvy |
| `g:size` | Povinné pro oděvy/obuv |
| `g:gender` | `male` / `female` / `unisex` |
| `g:age_group` | `newborn` / `infant` / `toddler` / `kids` / `adult` |
| `g:item_group_id` | Povinné pro varianty (spojuje varianty do skupiny) |
| `g:product_detail` | Strukturované parametry — Google zobrazuje jako filtry |
| `g:sale_price` | Akční cena — zobrazí přeškrtnutou původní cenu |

---

## Google Taxonomy — vyhledání správné kategorie

### Stažení taxonomy souborů
```bash
# CZ (česky)
curl -s "https://www.google.com/basepages/producttype/taxonomy-with-ids.cs-CZ.txt" | grep -i "pneumatik\|pneum\|tyre"

# UK / EN
curl -s "https://www.google.com/basepages/producttype/taxonomy-with-ids.en-GB.txt" | grep -i "tyre\|tire"

# Formát výstupu:
# 6093 - Vehicles & Parts > ... > Motor Vehicle Tyres > Auto Tyres
```

### Dostupné taxonomy soubory
| Trh | URL přípona |
|-----|------------|
| CZ | `taxonomy-with-ids.cs-CZ.txt` |
| UK | `taxonomy-with-ids.en-GB.txt` |
| DE | `taxonomy-with-ids.de-DE.txt` |
| SK | `taxonomy-with-ids.sk-SK.txt` |
| Globální (EN) | `taxonomy-with-ids.en-US.txt` |

### Formát hodnoty pro feed
Google přijímá **numerické ID** nebo **celý textový path**:
```
6093
Vehicles & Parts > Vehicle Parts & Accessories > Motor Vehicle Parts > Motor Vehicle Wheel Systems > Motor Vehicle Tyres > Auto Tyres
```

### Časté kategorie (UK)
| Produkt | ID | Path |
|---------|----|------|
| Auto pneumatiky | 6093 | `...Motor Vehicle Tyres > Auto Tyres` |
| Off-road / all-terrain pneu | 7252 | `...Motor Vehicle Tyres > Off-Road and All-Terrain Vehicle Tires` |
| Motocyklové pneu | 6091 | `...Motor Vehicle Tyres > Motorcycle Tyres` |
| Kola jízdních kol | 4571 | `Sporting Goods > ... > Bicycle Tyres` |

---

## Pravidla Mergado pro opravu Google Shopping elementů

### Oprava g:availability
```bash
# Diagnostika: zjisti aktuální výstupní hodnoty
element_values_post(project_id, "g:availability", is_output=true)

# Oprava přes PATCH na existující pravidlo nebo nové pravidlo:
curl -X POST "https://api.mergado.com/projects/{id}/rules/" \
  -d '{"name":"Fix availability","type":"rewriting","applies":true,"priority":"10",
       "queries":[{"id":"{ALLPRODUCTS}"}],
       "data":{"$struct":{"rows":[{"elementPath":"$ep.1","newContent":"$ref.1"}]},
               "$ref":{"$ref.1":"in_stock"},"$ep":{"$ep.1":"g:availability"}}}'
```

### Mapování kategorií (categories rule)
```bash
# Zjisti zdrojové kategorie
element_values_post(project_id, "g:product_type", is_output=false)

# Vytvoř categories pravidlo
curl -X POST "https://api.mergado.com/projects/{id}/rules/" \
  -d '{
    "name": "Google kategorie mapping",
    "type": "categories",
    "applies": false,
    "priority": "20",
    "queries": [{"id": "{ALLPRODUCTS}"}],
    "data": [
      {"position": 1, "input": "Pneumatiky > Letní", "output": "6093"},
      {"position": 2, "input": "Pneumatiky > Offroad", "output": "7252"}
    ]
  }'
# ⚠️ categories rule s array data → MUSÍ přes REST API (ne MCP tool)
```

### Přidání brand do titulu
```bash
# rewriting s dynamickou referencí %g:brand%
"$ref": {"$ref.1": "%g:brand% %g:title%"},
"$ep": {"$ep.1": "g:title"}
```

### Extrakce parametrů do g:product_detail
Viz Workflow F v `mergado-mcp` skillu — batch_param + variable s regex.

---

## Typické GMC chyby a opravy

| GMC chyba | Příčina | Oprava v Mergadu |
|-----------|---------|-----------------|
| **Neplatná hodnota availability** | `yes`, `skladem` místo `in_stock` | `rewriting` na `g:availability` |
| **Neplatná hodnota condition** | `novy`, `nové` místo `new` | `rewriting` na `g:condition` |
| **Nesoulad ceny** | Cena ve feedu ≠ cena na webu | Zkontrolovat pravidlo přepisující `g:price` |
| **Chybí GTIN** | Prázdný nebo špatný formát | Import správných GTIN nebo odstranit nevalidní hodnoty |
| **Promo text v titulu** | "doprava zdarma", "sleva %", "AKCE" | `rewriting` s regex odstraněním |
| **Příliš krátký titul** | truncating na < 30 znaků | Zvýšit `max_length` truncating pravidla |
| **Duplicitní tituly** | truncating příliš krátký → shoda | Zvýšit `max_length` (doporučeno ≥ 100–150 znaků) |
| **HTML v popisu** | `<ul>`, `<br>` v `g:description` | `tagstripping` pravidlo |
| **Chybí brand** | Prázdný `g:brand` | `rewriting` nebo importovat z externího zdroje |
| **Chybí google_product_category** | Element prázdný/chybí | `rewriting` nebo `categories` pravidlo |
| **Neplatná google_product_category** | Neexistující ID nebo špatný path | Zkontrolovat taxonomy soubor, opravit `categories` pravidlem |

---

## Best practices pro tituly (g:title)

**Doporučené pořadí pro různé typy produktů:**

| Typ | Struktura titulu |
|-----|-----------------|
| Oděvy | Značka + Pohlaví + Typ produktu + Atributy (barva, velikost) |
| Elektronika | Značka + Model + Typ produktu + Klíčové specifikace |
| Pneumatiky | Značka + Model + Rozměr (napr. `235/45R18`) + Index zátěže/rychlosti |
| Spotřební zboží | Značka + Typ + Atributy + Model |

**Pravidla:**
- Max 150 znaků (Google zobrazuje ~70 znaků v Nákupech)
- Klíčová slova na začátek
- Bez promo textu (`sleva`, `výprodej`, `doprava zdarma`)
- Bez HTML, URL, symbolů © ™
- Musí odpovídat titulu na produktové stránce webu

---

## Kontrolní seznam před publikací feedu do GMC

- [ ] `g:id` — unikátní, stabilní, max 50 znaků
- [ ] `g:title` — obsahuje brand + klíčové atributy, bez promo textu
- [ ] `g:description` — čistý text, bez HTML
- [ ] `g:availability` — hodnota z povoleného enumu (`in_stock` / `out_of_stock` / `preorder` / `backorder`)
- [ ] `g:condition` — `new` / `used` / `refurbished` (nebo vynechán pro nové produkty)
- [ ] `g:price` — odpovídá ceně na webu
- [ ] `g:brand` — vyplněný pro nové produkty
- [ ] `g:gtin` — vyplněný pokud dostupný
- [ ] `g:google_product_category` — platné ID nebo textový path z taxonomy
- [ ] `g:link` — https, ověřená doména v GMC
- [ ] `g:image_link` — min 500×500 px, dostupná URL

Zdroj: [Google Merchant Center Help](https://support.google.com/merchants/answer/7052112) · [Mergado KB — Google validátory](https://help.mergado.com/cs/audit-produktovych-dat/google-validatory/)
