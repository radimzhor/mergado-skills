# Mergado MQL & Výběry

Kompletní reference pro práci s Mergado Query Language (MQL) a výběry produktů přes MCP/API.

---

## Výběry (Queries) — základní principy

Výběr = uložený filtr produktů. Používá se jako základ pro pravidla (která produkty pravidlo ovlivní).

**Typy výběrů:**
- **Uložené** — trvalé, zobrazují počet produktů a přiřazených pravidel
- **Dočasné** — jen pro aktuální relaci
- **♥ALLPRODUCTS♥** — systémový výběr všech produktů, `read_only: true`

**Vytvoření výběru přes API:**
```bash
POST /projects/{id}/queries/
{"name": "Název výběru", "query": "<MQL výraz>"}
# HTTP 409 pokud výběr se stejným názvem už existuje
```

**Počet produktů ve výběru** je k dispozici až po vyhodnocení (asynchronně):
```bash
GET /queries/{id}/   →  field: product_count  (None = ještě nevyhodnoceno, 0 = prázdný výběr)
```

---

## MQL — základní operátory

### Porovnávací operátory

| Operátor | Popis | Příklad |
|----------|-------|---------|
| `=` | rovná se | `g:brand = "Continental"` |
| `!=` | nerovná se | `g:condition != "new"` |
| `CONTAINS` | obsahuje text | `title CONTAINS "zimní"` |
| `NOT CONTAINS` | neobsahuje text | `g:title NOT CONTAINS "Continental"` |
| `~` | regulární výraz | `g:gtin ~ "^\d{13}$"` |
| `!~` | neodpovídá regexu | `g:id !~ "^PI"` |
| `<` `>` `<=` `>=` | číselné porovnání | `g:price > 1000` |
| `IS EMPTY` | prázdná hodnota | `g:brand IS EMPTY` |
| `IS NOT EMPTY` | neprázdná hodnota | `g:gtin IS NOT EMPTY` |

### IN operátor — seznam hodnot ✅ preferovaný způsob

Pro filtrování podle **více konkrétních hodnot** vždy použij `IN`, ne řetězec `OR`:

```
g:id IN ("CN03137100000"; "CN03597950000"; "PI4435400")
```

**Syntaxe:** hodnoty oddělené **středníkem**, uzavřené v závorkách.

```
g:brand IN ("Continental"; "Kumho"; "Pirelli")
g:id NOT IN ("ID1"; "ID2"; "ID3")
```

❌ **Nepoužívat:**
```
g:id = "ID1" OR g:id = "ID2" OR g:id = "ID3"   ← špatná praxe pro seznamy
```

### Logické operátory

```
g:price > 1000 AND g:brand = "Nike"
(g:price > 500 AND g:brand = "Nike") OR g:category CONTAINS "sport"
```

### Opačné výběry — operátor NOT

Neguje celou podmínku — vybere vše **kromě** produktů splňujících podmínku:

```
NOT(g:title CONTAINS "boty" AND g:category = "Doplňky")
```

Přímé opačné operátory:
```
g:id NOT IN ("ID1"; "ID2")
g:title NOT CONTAINS "sleva"
g:brand != "Pirelli"
```

### Řazení

```
SORT BY g:price DESC
SORT BY title ASC
SORT BY g:price AS NATURAL    ← přirozené pořadí (číselné, ne lexikografické)
```

### Parametry produktů (PARAM operátor)

```
PARAM { NAME = "Materiál" } | VALUE = "Masiv"
```

---

## Vstupní vs. výstupní elementy v MQL

**Klíčový rozdíl:** MQL výběry pracují se vstupními (input) hodnotami elementů, ne s výstupními (po aplikaci pravidel). Výjimkou jsou `g:` prefixované elementy, které jsou specifické pro daný feed formát.

- `title` = vstupní element s názvem (bez prefixu)
- `g:title` = výstupní Google element (po pravidlech)
- `g:id` = identifikátor produktu (stejný ve vstupu i výstupu)

**Příklad:** Feed s Google formátem má vstupní element `title`, nikoli `g:title`. Query `g:title NOT CONTAINS "X"` pak vrátí špatné výsledky, protože `g:title` ve vstupu neexistuje nebo je prázdné.

Vždy ověř správný název elementu přes `element_values_post` nebo `list_project_elements`.

---

## Ověření výběru — debugging

Ověř konkrétní produkt přidáním jeho ID do podmínky:
```
g:brand = "Continental" AND g:id = "CN03137100000"
```
Pokud vrátí 1 produkt → podmínka správně zachytí i tento produkt.

Ověř příslušnost produktu k výběrům přes záložku **Výběry** u konkrétního produktu v UI.

---

## Vzorové MQL výrazy

| Cíl | MQL |
|-----|-----|
| Konkrétní produkt | `g:id = "CN03137100000"` |
| Seznam produktů | `g:id IN ("ID1"; "ID2"; "ID3")` |
| Prázdný GTIN | `g:gtin IS EMPTY` |
| Produkty bez brand v názvu | `g:brand IS NOT EMPTY AND title NOT CONTAINS "Continental"` |
| All-terrain pneumatiky | `description CONTAINS "terrain" OR description CONTAINS "rugged"` |
| Produkty určité značky | `g:brand = "Continental"` |
| Skrýt vše kromě výběru | výběr s `NOT IN (...)` + skrývací pravidlo |
| Produkty s EAN ve správném formátu | `g:gtin ~ "^\d{13}$"` |

---

## API — správa výběrů

| Endpoint | Účel |
|----------|------|
| `POST /projects/{id}/queries/` | Vytvořit výběr |
| `GET /projects/{id}/queries/` | Seznam výběrů projektu |
| `GET /queries/{id}/` | Detail výběru + `product_count` |
| `PATCH /queries/{id}/` | Upravit výběr |
| `DELETE /queries/{id}/` | Smazat výběr |
| `GET /rules/{id}/queries/` | Výběry přiřazené k pravidlu |
| `PATCH /rules/{id}/queries/` body `{"id":"QID"}` | Přiřadit výběr k pravidlu |
| `DELETE /rules/{rid}/queries/{qid}` | Odebrat výběr z pravidla |

Zdroje: [Výběry](https://help.mergado.com/cs/mergado-editor/prace-s-daty/zakladni-prvky/produkty-a-produktove-vybery/) · [Opačné výběry](https://help.mergado.com/cs/mergado-editor/prace-s-daty/zakladni-prvky/opacne-vybery-v-mergadu/) · [MQL operátory](https://help.mergado.com/cs/mergado-editor/prace-s-daty/zakladni-prvky/operatory-pro-mergado-query-language/)
