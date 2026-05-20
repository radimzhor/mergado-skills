# Workflows — detailní krokové playbooky

Tento soubor obsahuje **kompletní krokové scénáře** pro tři hlavní use-cases. Načti odpovídající sekci, když řešíš zrovna ten scénář a chceš mít jistotu, že žádný krok nezapomeneš.

## Obsah
- [A. Onboarding nového výstupu / nové platformy](#onboarding)
- [B. Hromadná oprava chyb (audit-driven)](#oprava)
- [C. Optimalizace existujícího feedu](#optimalizace)
- [D. Diagnostika konkrétního produktu](#diagnostika)
- [E. Hromadný „úklid" feedu (komplexní)](#uklid)

---

## <a name="onboarding"></a>A. Onboarding nového výstupu / nové platformy

**Trigger:** *"chci začít prodávat na Glami"*, *"přidej mi Google Shopping"*, *"nastav mi Heureku"*, *"jak začít s Mergadem"*.

### Krok 1 — Zjisti kontext

Polož **maximálně 2 otázky**:
1. Kterou platformu cílíme? (Google Shopping / Heureka / Zboží / Meta / Glami / Allegro / Sklik / jiné)
2. Existuje pro tento e-shop už **projekt v Mergadu**? (Pokud uživatel neví, zjisti přes MCP — vytáhni jeho projekty a ukaž mu seznam.)

### Krok 2 — Zorientuj se přes MCP

- Načti **detail projektu** — jak se jmenuje, jaký vstupní feed má, kdy proběhl poslední import.
- Načti **seznam výstupů** — existuje už výstup pro cílovou platformu?
  - Pokud **ano** — máme platform connection, jen potřebuje uklid / doplnění chybějících elementů.
  - Pokud **ne** — potřebuje vytvořit nový výstup.

### Krok 3 — Vytvoř výstup (pokud ještě není)

- Přes MCP vytvoř nový výstup pro zvolenou platformu, **použij standardní šablonu** Mergada (Mergado má pro každou platformu připravenou základní strukturu).
- Pojmenuj výstup popisně (`Glami CZ feed`, ne `feed1`).
- **Po vytvoření** vrať uživateli URL výstupu — bude ji potřebovat na nahrání do platformy.

### Krok 4 — Spusť audit

- Hned po vytvoření výstupu **spusť audit** (přes MCP nebo Knowledge Base recept). Zjistíš, co všechno chybí pro správnou validaci.
- Audit ti vrátí typicky 5–30 chyb (záleží jak kvalitní je vstupní feed).

### Krok 5 — Adresuj chyby v pořadí

Postupuj podle seznamu chyb (priorita: ERRORs > WARNINGs):

- Pro každou skupinu chyb najdi recept v `audit-chyby.md`.
- Vytvoř pravidlo (přes MCP), pojmenuj ho srozumitelně.
- Po skupině 3–5 oprav řekni uživateli **co všechno se právě udělalo** + ukaž rozdíl v auditu.

### Krok 6 — Závěrečný checklist

Před tím, než řekneš "hotovo", projdi:

- [ ] Audit ERRORs = 0 (nebo známé výjimky)
- [ ] Title vypadá strukturovaně (ne marketingově)
- [ ] Kategorie je platform-specific (Google taxonomy / Heureka categories / Glami…)
- [ ] Identifikátory (GTIN, brand) doplněné nebo `identifier_exists=no`
- [ ] Dostupnost (availability) je platform-compliant
- [ ] Vyprodané produkty jsou skryté
- [ ] URL výstupu uživatel zná a může ji nahrát do platformy

### Krok 7 — Předej dál

Řekni uživateli:
1. **URL výstupu** (kam ji vložit v Google / Heureka / Glami platformě).
2. **Frekvence exportu** (jak často Mergado feed obnoví).
3. **Co ještě dál** — odkaž na další krok ("Až Google Merchant Center načte feed, dej mi vědět, kdyby tam vznikly nové chyby — můžeme je hned řešit.").

---

## <a name="oprava"></a>B. Hromadná oprava chyb (audit-driven)

**Trigger:** *"oprav chyby"*, *"Google mi zamítá"*, *"Heureka mi neschvaluje"*, *"GMC errors"*.

### Krok 1 — Lokalizuj problém

- Která platforma? (Google / Heureka / Meta / Zboží…)
- Který výstup? (Pokud má uživatel víc Google výstupů — třeba CZ a SK — zjisti který.)
- Odkud dostal informaci o chybě? Z Mergado Auditu? Z GMC? Ze screenshotu?

### Krok 2 — Získej autoritativní seznam chyb

**Preferuj Mergado Audit** — vrátí strukturovaný seznam s:
- Severity (error / warning / notice)
- Element / pravidlo, kterého se týká
- Počet postižených produktů
- Doporučené řešení

Když uživatel pošle screenshot z GMC, **přelož jeho text** na Mergado audit chybu (Knowledge Base má mapování).

### Krok 3 — Seskup chyby

Nikdy nepřezpívávej uživateli 30 chyb v řadě. Seskup je do **3–5 logických skupin** (chybějící identifikátory, formát ceny, kategorie, dostupnost, obsah titulků…).

### Krok 4 — Adresuj jednu skupinu naráz

Pro každou skupinu:
1. **Vysvětli:** *"V této skupině je [N] produktů s [problém]. Bez toho [důsledek]."*
2. **Navrhni:** *"Vytvořím pravidlo [název]: [popis akce]."*
3. **Ukaž ukázku** před/po na 1–2 konkrétních produktech (pokud lze).
4. **Získej souhlas** — *"Můžu pravidlo vytvořit a aktivovat?"*
5. **Proveď** — vytvoř pravidlo, aktivuj.
6. **Ověř** — znovu audit pro ten element / tu skupinu.
7. **Reportuj rozdíl:** *"Před: 47 problémových. Po: 2."*

### Krok 5 — Co se nepodařilo

Některé chyby se nedají opravit pravidlem (kvalita obrázků, špatný popis v e-shopu, validace platformy). Po projetí všech skupin **upřímně řekni**:

- *"Toto se mi povedlo opravit: [seznam]"*
- *"Toto se nedá opravit pravidlem v Mergadu — musí se opravit v e-shopu: [seznam s konkrétními produkty/pole]"*
- *"Toto je znalostní mezera (nevím / Knowledge Base nemá): [seznam]. Když chceš, podívám se hlouběji nebo se zeptáme supportu."*

### Krok 6 — Závěr

Stručný souhrn: kolik pravidel přibylo, jaký byl impakt (`-X chyb`), co dál.

---

## <a name="optimalizace"></a>C. Optimalizace existujícího feedu

**Trigger:** *"vylepši mi titulky"*, *"doplň barvy"*, *"udělej feed čistější"*, *"napiš lepší popisy"*.

### Krok 1 — Zjisti, co konkrétně chce optimalizovat

Pokud řekne jen *"vylepši feed"*, ukaž 3 nejdopadovější oblasti:

1. **Titulky** (`g:title` / `PRODUCTNAME`) — nejcennější, nejvíc to ovlivní výkon
2. **Chybějící atributy** (barva, materiál, gender, kategorie) — bez nich produkty filtrují hůř
3. **Popisy** (`g:description`) — méně dopad na výkon, ale Google to penalizuje pokud chybí

Ať si vybere **jednu oblast** k optimalizaci. Lépe iterovat.

### Krok 2 — Zorientuj se v aktuálním stavu

Pro vybranou oblast (např. titulky):
- Jak vypadají dnes? Náhodný vzorek 3–5 titulků z reálných produktů.
- Jaké elementy má projekt k dispozici jako zdroj? (`%manufacturer%`, `%name%`, `%color%`, PARAM s konkrétními atributy…)

### Krok 3 — Navrhni strukturu

Předlož uživateli **2 varianty** struktury (např. pro title):
- **A:** `[značka] [název] [barva]` → ukázka: `Nike Air Max 90 černé`
- **B:** `[značka] [název] [klíčový atribut] velikost [X]` → ukázka: `Nike Air Max 90 pánské velikost 42`

Ať si vybere. Pokud není rozhodnutý, vyber A jako default (jednodušší, méně rizik).

### Krok 4 — Vytvoř pravidlo

- Pravidlo Přepsat na element s proměnnými (cookbook → Title).
- Pojmenuj srozumitelně (`Sestavit titulek z brand + name + color`).
- Aktivace **až** po náhledu.

### Krok 5 — Náhled

- Ukaž 3 ukázky před/po na reálných produktech.
- Zeptej se: *"Vypadá to dobře, nebo upravit?"*
- Pokud upravit → iteruj (varianta s velikostí, varianta bez barvy u produktů kde chybí…).

### Krok 6 — Aktivuj a ověř

- Aktivuj.
- Po dalším exportu zkontroluj audit (jestli nově neprasklo nic).
- Reportuj výsledek.

### Krok 7 — Co dál

Nabídni následující optimalizaci v jiné oblasti — *"Titulky máme. Chceš teď doplnit chybějící barvy?"*. Optimalizace je iterativní hra.

---

## <a name="diagnostika"></a>D. Diagnostika konkrétního produktu

**Trigger:** *"produkt X se nezobrazuje v Google"*, *"proč zrovna tenhle produkt zamítli"*, *"ten produkt mám špatně, opravte ho"*.

### Krok 1 — Identifikuj produkt

- ID? URL? Název?
- Zjisti přes MCP `get` produkt podle identifikátoru.

### Krok 2 — Stav produktu ve vstupu

- Existuje produkt vůbec ve vstupním feedu? (Pokud ne → e-shop ho nedodává; není to Mergado problém.)
- Jaké hodnoty má klíčových elementů?

### Krok 3 — Stav produktu ve výstupu

- Není skryt některým pravidlem? (Pokud ano, kterým? Je to záměrné?)
- Po aplikaci pravidel jak vypadají jeho výstupní hodnoty?

### Krok 4 — Stav produktu na platformě

- Pokud je v exportu, ale platforma ho neukazuje, jde o **platform-side problém**:
  - Audit pro tento konkrétní produkt — jaké chyby?
  - Ve specifické platformě (GMC) — uživatel se musí podívat do diagnostiky platformy.

### Krok 5 — Akce

- Pokud chyba ve **vstupu** — Mergado neopraví, řekni uživateli, ať to upraví v e-shopu.
- Pokud chyba ve **výstupu** (po pravidle) — najdi pravidlo, oprav ho.
- Pokud chyba na **platformě** — ukaž auditní chyby + recept z `audit-chyby.md`.

### Krok 6 — Reportuj

Přesný stav: kde je problém, co jsi udělal, co musí udělat uživatel.

---

## <a name="uklid"></a>E. Hromadný „úklid" feedu (komplexní)

**Trigger:** *"udělej mi pořádek ve feedu"*, *"oprav mi všechno"*, *"můj feed je chaos"*.

### Postup

Tohle je nejnáročnější scénář — kombinace všeho. Drž se přístupu **iteruj, neutopej se**.

1. **Audit** + **získání seznamu chyb** (krok 1–3 z workflow B).
2. **Seskup chyby** (krok 3 z workflow B).
3. **Prioritizuj iterace:**
   - Iterace 1: ERRORs blokující inzerci (chybějící identifikátory, kategorie, prázdné title…)
   - Iterace 2: WARNINGs (formát ceny, suboptimální struktura…)
   - Iterace 3: optimalizace (lepší titulky, doplnění gender / age_group / color…)
4. **Pro každou iteraci** projdi workflow B / C podle typu.
5. **Mezi iteracemi** — souhrn ("Iterace 1 hotová. Audit teď ukazuje X chyb. Chceš pokračovat na iteraci 2?").

**Klíčový princip: nekoukej na to jako na jeden monolit.** Iterace, malé vítězství, průběžný report. Uživatel cítí progress, ne přemoženost.

---

## Antipatterns (čeho se vyvarovat)

- **Velký výpis chyb hned na začátku.** *"Tady je 47 chyb..."* → uživatel uteče. Vždy seskupit a odhalovat postupně.
- **Pokus opravit vše jedním pravidlem.** Multifunkční pravidla jsou křehká a špatně se debugují. Dělej úzká, čitelná, samostatná.
- **Změna bez ukázky.** *"Vytvořil jsem pravidlo X."* — uživatel neví, co to udělalo. Vždy ukaž **před / po** na vzorku.
- **Mergado-jazykem napřímo.** *"Aplikoval jsem typ pravidla Přepsat na element g:google_product_category s vyhrazením position 0..."* → uživatel nečte. *"Doplnil jsem Google kategorii u 47 produktů, kterým chyběla."* → uživatel rozumí.
- **"Hotovo" bez ověření.** Vždy zkontroluj výsledek (re-audit nebo jiná verifikace) a zreportuj rozdíl.
