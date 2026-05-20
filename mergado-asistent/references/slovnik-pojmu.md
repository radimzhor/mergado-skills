# Slovník pojmů a překladový slovník

Tento soubor má dvě části:
1. **Mergado koncepty** — co každý pojem znamená a kdy ho potřebuješ vysvětlit uživateli.
2. **Překladový slovník** — jak uživatel typicky mluví → jak to znamená v Mergadu → jakou akci to vyžaduje.

---

## 1. Mergado koncepty (pro tebe i pro vysvětlení uživateli)

### Projekt
Jeden projekt = jeden e-shop, typicky pro jeden trh / jednu doménu. Pokud má klient cz a sk, jsou to obvykle dva projekty. Projekt drží vstup, výstupy, pravidla, produktové výběry, statistiky.

> **Vysvětlení uživateli:** "Projekt je tvoje pracovní složka v Mergadu pro jeden e-shop."

### Vstupní feed (vstup)
XML nebo CSV soubor, který Mergado pravidelně stahuje z e-shopu. Obsahuje surová data — Mergado je **nemění**, jen z nich čerpá.

> **Vysvětlení:** "Vstupní feed je seznam tvých produktů, jak ti je generuje e-shop."

### Výstupní feed (výstup)
Výsledný feed pro konkrétní platformu (Google Shopping, Heureka, Zboží, Meta, Glami, Allegro, Sklik…). Vzniká aplikací pravidel na vstup v okamžiku exportu. Každý výstup má vlastní URL, kterou uživatel vloží do reklamní platformy.

> **Vysvětlení:** "Výstup je upravený feed, který posíláš do Google / Heureky / Mety. Mergado ho vyrobí pokaždé, když exportujeme — typicky každých pár hodin."

### Element
Atribut produktu ve feedu. Příklady: `g:title`, `g:gtin`, `g:google_product_category`, `IMGURL`, `CATEGORYTEXT`, `PARAM`, `DELIVERY_DATE`, `ITEMGROUP_ID`. Element může mít hodnotu, atributy (např. `lang`, `description`), může se opakovat.

> **Vysvětlení:** "Element je jedno políčko produktu — třeba název, cena, kategorie, obrázek."

### Atribut elementu
XML atribut nesený elementem, např. `<IMAGE description="hlavní">…</IMAGE>` má atribut `description`. V Mergado syntaxi se píše s `@`: `IMAGE | @description`.

> **Vysvětlení:** "Atribut je doplňková informace u políčka — třeba u obrázku označení, jestli je hlavní."

### Pravidlo
Transformace, která se aplikuje na produkty při generování výstupu. Hlavní typy:

- **Přepsat** — přepíše hodnotu elementu novou hodnotou (text nebo proměnná).
- **Doplnit** — doplní hodnotu jen tam, kde je element prázdný. **Neničí existující data.**
- **Najít a nahradit** — najde text v elementu a nahradí ho jiným (umí regex).
- **Skrýt produkt** — vyloučí produkt z výstupu (nezahodí ho ze vstupu, jen ho neexportuje).
- **Import datového souboru** — natahá data z externího XML/CSV (obohacení o sklady, marže, statistiky).
- **Vlastní element** — vytvoří nový vlastní element, do kterého pak něco napíšeš.
- (a další specifické typy podle Mergado verze)

Pravidla jsou **stack** — pořadí pravidel může být důležité (jedno upravuje to, co jiné předtím napsalo).

> **Vysvětlení:** "Pravidlo je úprava, kterou Mergado udělá s tvým feedem před tím, než ho pošle dál. Třeba 'všem botám doplň kategorii Obuv'."

### Produktový výběr
Filtr, který určuje, na které produkty se pravidlo aplikuje. Může být podle čehokoli — kategorie, značky, rozsahu cen, prázdnosti elementu, regex match v titulku…

> **Vysvětlení:** "Produktový výběr je 'na které produkty se to bude vztahovat'. Můžeš třeba vybrat jen produkty bez GTINu, jen značku Nike, jen levné produkty."

### Proměnná
Reference na hodnotu jiného elementu, použitelná v poli "Nová hodnota". Syntax: `%název_elementu%`. Příklady: `%manufacturer%`, `%g:price%`, `%name%`. Hodnota proměnné se vyhodnocuje per-produkt.

> **Vysvětlení:** "Proměnná je odkaz na jiné políčko produktu. `%brand%` znamená 'doplň sem značku produktu'."

### Mergado Audit
Bezplatný kontrolní nástroj. Umí kontrolovat feed proti pravidlům platforem (Google Merchant Center, Heureka, Meta…), vrací seznam chyb se severity a doporučeními. Audit **data nemění**, jen analyzuje. Dostupný i bez registrace na `audit.mergado.com`.

> **Vysvětlení:** "Audit je nezávislá kontrola — zjistí, jestli je tvůj feed v pořádku pro Google / Heureku / atd."

### Element path syntax (v pravidle)
- `TITLE` — element TITLE
- `IMAGE | @description` — atribut description elementu IMAGE
- `PARAM { @@VALUE = "Barva" } | @lang` — atribut lang elementu PARAM, kde VALUE = "Barva"
- `CATEGORYTEXT { @@POSITION > 1 }` — element CATEGORYTEXT na pozici > 1 (druhé a další výskyty)

Toto je Mergado-specifická syntax — uživatel ji nemusí vidět, ale ty ji potřebuješ pro tvorbu pravidel přes MCP.

### Aktivace / pořadí pravidel
Pravidla mají stav `aktivní` / `neaktivní`. Můžeš si je dočasně vypnout, aniž bys je mazal. Pořadí pravidel **někdy** záleží — pokud pravidlo A přepíše titulek a pravidlo B v něm něco hledá, B musí být po A.

### Mergado Aplikace (Store)
Třetí strana / Mergado vlastní pluginy, které dělají specializované věci: **Pricing Fox** (přeceňování), **Bidding Fox** (CPC bidding), **Repairman** (oprava XML chyb), **Pairing Bear** (párování na Heureka), **Mergado Translate** (překlady), atd. Každá aplikace má svůj vlastní stack pravidel a UI.

> **Vysvětlení:** "Mergado má taky aplikace — speciální nástroje pro úkoly jako přeceňování, biddování, párování na Heurece. Většinu jsou placené."

### MERGADO_AI elementy
Podsekce specifikace `<MERGADO_AI>` v XML — AI generované návrhy hodnot (kategorie, barva, materiál, gender, popis…). Uživatel je může brát do pravidel přes proměnné (`%AI_COLOR_PRIMARY%`). Jsou to *návrhy*, ne autoritativní data. Detail viz spec dokument `mergado-ai-elements-spec-v1.1.md`.

---

## 2. Překladový slovník (user phrase → akce)

| Co uživatel řekne | Co tím myslí | Co s tím udělat |
|---|---|---|
| "Oprav chyby v Google Shopping" | Audit Google výstupu, identifikace chyb, opravná pravidla | Spustit audit, seskupit chyby, navrhnout opravy |
| "Heureka mi neschvaluje produkty" | Heureka identifikuje produkty, ale nepáruje / odmítá | Zkontrolovat povinné elementy (CATEGORYTEXT, ITEM_TYPE, EAN), spustit Heureka audit |
| "Meta zamítla katalog" | Facebook Catalog odmítá produkty | Zkontrolovat fb_product_category, image_link, availability, condition |
| "Přidej mi Glami / Allegro / nový kanál" | Vytvořit nový výstup pro novou platformu | Onboarding workflow (viz workflows.md) |
| "Doplň barvy / materiály / pohlaví" | Najít produkty s prázdným elementem, doplnit hodnotu | Pravidlo Doplnit s výběrem "element je prázdný" |
| "Změň všem cenám DPH / přidej slevu / sniž ceny" | Modifikovat element PRICE_VAT / g:price | Pravidlo Přepsat s matematikou |
| "Skryj vyprodané produkty" | Vyloučit produkty s availability != "in stock" | Pravidlo Skrýt produkt s výběrem podle dostupnosti |
| "Mám duplicitní produkty" | Více produktů se stejným ID/EAN/titulkem | Diagnostika přes audit, pravidlo Skrýt s výběrem podle duplicit |
| "Vytvoř lepší titulky" | Přepsat g:title strukturovaně | Pravidlo Přepsat s proměnnými (`%brand% %name% %color%`) |
| "Doplň popisy z parametrů" | Sestavit g:description z PARAM elementů | Pravidlo Přepsat s konstrukcí ze proměnných |
| "Přidej k titulku 'AKCE' u zlevněných" | Modifikovat titulek u podmnožiny | Pravidlo Přepsat s úzkým výběrem (např. cena < původní cena) |
| "Změň kategorie podle mojí mapy" | Přepsat google_product_category podle vlastního mapování | Pravidlo Přepsat s výběrem per kategorie / Import datového souboru |
| "Produkt X se nezobrazuje" | Diagnostika konkrétního produktu | Najít produkt v projektu, zkontrolovat: je v exportu? není skryt? prošel audit? je na platformě? |
| "Proč mi Google snížil výkon?" | Otázka mimo Mergado scope | Vysvětli, že Mergado neuvidí Google Ads výkon, ale můžeš zkontrolovat kvalitu feedu |
| "Spoj mi feed s daty z mojí tabulky" | Obohacení o externí data (sklady, marže) | Pravidlo Import datového souboru (CSV/XML) |
| "Co se mi v Mergadu vůbec děje" | Stav projektu, přehled | Načti přehled projektu, výstupů, posledního exportu, otevřených chyb |
| "Jak začít / nastavit Mergado" | Onboarding | Workflow A v SKILL.md + workflows.md |
| "To se mi nelíbí, vrať to" | Uživatel chce zrušit poslední změnu | Najdi naposledy vytvořené pravidlo, deaktivuj nebo smaž (po potvrzení) |
| "Prosím udělej to za mě všechno" | Plná delegace | Reaguj opatrně — ano k bezpečným krokům, ne k destruktivním bez kontroly |
| "Mám tarif za zbytečné peníze" | Otázka mimo edit scope | Otázka pro fakturaci / účet — odkaž do Mergado Účet sekce |

---

## 3. Často zaměňované pojmy (na pozor!)

- **Vstup vs Výstup.** Uživatel často říká "feed" — bez kontextu nevíš, jestli mluví o vstupu (z e-shopu) nebo výstupu (do Googlu). Při nejistotě se zeptej.
- **Element vs Atribut.** `g:gtin` je element. `lang` u `<TITLE lang="cs">` je atribut. Uživatelé tomu obojímu říkají "pole" — nemusíš je opravovat, ale ty si to musíš pamatovat při tvorbě pravidla.
- **Přepsat vs Doplnit.** **Přepsat = vždy nahradí.** **Doplnit = nahradí jen prázdné.** Volba má dopad — Přepsat může smazat data, která uživatel chce zachovat.
- **Skrýt produkt vs Smazat produkt.** Mergado produkt **nemaže** — Skrýt = nevyexportovat. Produkty zmizí ze vstupu, jen když je e-shop přestane posílat.
- **Pravidla v Mergado Editor vs v aplikacích.** Pravidla v Pricing Fox / Bidding Fox / dalších aplikacích jsou *jiná stack*, ne ta z hlavního Editoru. Když uživatel mluví o "pravidlech", typicky myslí ta v Editoru — ale když řeší přeceňování, myslí Pricing Fox.
