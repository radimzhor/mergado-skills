---
name: mergado-element-path
description: >
  Expert guide for building, validating, and debugging Mergado Element Path expressions — the syntax used
  to target specific values in product feed XML structures within Mergado rules, queries, and element selectors.
  Use this skill whenever the user needs to: write or correct an Element Path (cesta k elementu), target a nested
  XML element like PARAM | VAL, filter by attribute like VARIANT { @id = "..." }, use @@POSITION or @@VALUE,
  work with repeating elements (IMAGE, PARAM, DELIVERY, CATEGORY, g:product_detail), or apply indexation with #.
  Also trigger when the user asks "jak napíšu cestu k elementu", "jak cílit na parametr", "jak vybrat konkrétní
  obrázek", "co je element path", or pastes XML and asks how to reference a value in Mergado.
  Always use this skill alongside Mergado MCP tools (list_project_elements, element_values_get, create_rule,
  create_project_query) when the user is building rules or queries in Mergado.
---

# Mergado Element Path

Element Path je jazyk, kterým Mergadu říkáš, **kde v XML struktuře feedu se nachází hodnota**, na kterou chceš cílit — v pravidle, dotazu nebo výběru elementu.

## Syntaxe přehledně

| Situace | Zápis | Příklad |
|---|---|---|
| Jednoduchý element | `NÁZEV` | `NAME` |
| Zanořený element | `RODIČ \| POTOMEK` | `PARAM \| VAL` |
| Filtr/podmínka | `ELEMENT { podmínka }` | `PARAM { PARAM_NAME = "Barva" } \| VAL` |
| XML atribut | `ELEMENT { @atribut = "hodnota" }` | `VARIANT { @id = "idvariant3" }` |
| Pozice (pořadí) | `@@POSITION` | `PARAM { @@POSITION = 2 } \| VAL` |
| Hodnota elementu | `@@VALUE` | `CATEGORY { @@VALUE != "Hračky" }` |
| Indexace | `ELEMENT #{ číslo }` | `PARAM #{ 2 }` |

## Klíčová pravidla syntaxe

**Svislítko `|` musí mít mezery z obou stran.** Bez mezer Mergado cestu nepřečte správně.
- ✅ `PARAM | VAL`
- ❌ `PARAM|VAL`

**Podmínky patří do složených závorek `{ }`**, nikoli volně za element.
- ✅ `VARIANT { @id = "idvariant3" }`
- ❌ `VARIANT @id = "idvariant3"`

**Atribut uvnitř závorek má jeden `@`**, speciální atributy mají dva `@@`.
- Atribut XML: `{ @id = "123" }`
- Speciální: `{ @@POSITION = 1 }`, `{ @@VALUE = "Červená" }`

**Indexace `#{ číslo }` má číslo ve složených závorkách.**
- ✅ `PARAM #{ 2 }`
- ❌ `PARAM # 2`

## Jak vybrat správný přístup

### Chci n-tou hodnotu vícenásobného elementu (pořadí je konzistentní)
```
IMAGE { @@POSITION = 2 }
```

### Chci hodnotu parametru podle jeho názvu
```
PARAM { PARAM_NAME = "Barva" } | VAL
```
Toto je spolehlivější než `@@POSITION` — název parametru je stabilní.

### Chci vyloučit nebo zahrnout hodnoty podle obsahu
```
CATEGORY { @@VALUE != "Hračky" }
IMGURL_ALTERNATIVE { @@VALUE ~ "cdn.example.com" }
```
`@@VALUE` se hodí u elementů bez potomků — kde hodnota je přímo text elementu.

### Chci cílit podle XML atributu
```
VARIANT { @id = "idvariant3" } | CODE
DEFAULT_CATEGORY { @id = "123" }
```

### Musím vybrat konkrétní opakující se výskyt (indexace `#{ }`)
Indexaci `#{ }` použij jen tehdy, když:
- cesta vrací více než jednu hodnotu, A
- `@@POSITION` nestačí (stejný obsah se u různých produktů vyskytuje na různých pozicích)

```
PARAM #{ 2 } | VAL
g:product_detail { g:attribute_name = "Barva" } #{ 2 } | g:attribute_value
```

> ⚠️ Zbytečná indexace místo `@@POSITION` degraduje výkon. Použij ji jen pokud to opravdu potřebuješ.

## Vícenásobné elementy

Tyto elementy se v produktu mohou opakovat — každý výskyt má vlastní @@POSITION:
- `IMAGE`, `IMGURL_ALTERNATIVE`
- `PARAM` (typicky má potomky `PARAM_NAME` a `VAL`)
- `DELIVERY`
- `CATEGORY`
- `g:product_detail` (má potomky `g:attribute_name`, `g:attribute_value`, volitelně `g:section_name`)

Jednoduchý element (např. `NAME`, `DESCRIPTION`) má vždy @@POSITION = 1.

## Práce s Mergado MCP nástroji

Při sestavování Element Path v kontextu MCP nástrojů:

1. **Zjisti dostupné elementy** pomocí `list_project_elements` — vrátí přehled elementů v projektu včetně jejich cest.
2. **Ověř konkrétní hodnoty** pomocí `element_values_get` — ukazuje, co elementy obsahují a jakou mají strukturu.
3. **Použij cestu v pravidle** při volání `create_rule` nebo `update_rule` — element path jde do parametru `element`.
4. **Použij cestu v dotazu** při volání `create_project_query` nebo `create_rule_query`.

## Časté chyby a jak je opravit

| Chyba | Špatně | Správně |
|---|---|---|
| Chybí mezery u `\|` | `PARAM\|VAL` | `PARAM \| VAL` |
| Atribut mimo závorky | `VARIANT @id = "x"` | `VARIANT { @id = "x" }` |
| Závorky bez mezery | `PARAM{@@POSITION=1}` | `PARAM { @@POSITION = 1 }` |
| Indexace bez závorek | `PARAM # 2 \| VAL` | `PARAM #{ 2 } \| VAL` |
| Indexace místo @@POSITION | `PARAM #{1} \| VAL` (pokud pozice stačí) | `PARAM { @@POSITION = 1 } \| VAL` |

## Příklady sestavení cesty z XML

**XML:**
```xml
<PARAM>
  <PARAM_NAME>Barva</PARAM_NAME>
  <VAL>Černá</VAL>
</PARAM>
```
→ Cesta k hodnotě barvy: `PARAM { PARAM_NAME = "Barva" } | VAL`

---

**XML:**
```xml
<VARIANTS>
  <VARIANT id="idvariant3">
    <CODE>EEQ21</CODE>
  </VARIANT>
</VARIANTS>
```
→ Cesta k CODE konkrétní varianty: `VARIANTS | VARIANT { @id = "idvariant3" } | CODE`

---

**XML:**
```xml
<IMAGE>url1.jpg</IMAGE>
<IMAGE>url2.jpg</IMAGE>
<IMAGE>url3.jpg</IMAGE>
```
→ Druhý obrázek (pořadí konzistentní): `IMAGE { @@POSITION = 2 }`
→ Druhý obrázek (pořadí se liší, jde o výskyt): `IMAGE #{ 2 }`

---

**XML (Google feed):**
```xml
<g:product_detail>
  <g:attribute_name>Barva</g:attribute_name>
  <g:attribute_value>Červená</g:attribute_value>
</g:product_detail>
<g:product_detail>
  <g:attribute_name>Barva</g:attribute_name>
  <g:attribute_value>Modrá</g:attribute_value>
</g:product_detail>
```
→ Druhý výskyt parametru Barva: `g:product_detail { g:attribute_name = "Barva" } #{ 2 } | g:attribute_value`
