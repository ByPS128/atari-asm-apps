# Tetris pro Atari XL/XE (MADS)

Klasický Tetris v 6502 assembleru pro Atari 800XL/XE, inspirovaný amigáckým
*Tetris Pro* (Logic Systems, 1993): každý level má cíl v řádcích a rychlost,
ve vyšších obtížnostech začíná se startovními strukturami cihel ve studně.

[SPEC.md](SPEC.md) obsahuje zadání odvozené ze současného zdroje pro vytvoření
funkčně a vzhledově podobné hry: pravidla, rozvržení, časování, kompletní
tabulky dílků, levelů, struktur a zvuků i přejímací scénáře.

## Build

Vyžaduje MADS v `PATH`. Z adresáře `src/tetris` v PowerShellu:

```powershell
./make.bat
# Pouze hra (včetně labelů pro harness):
mads tetris.asm -o:tetris.xex -t:tetris.lab
```

`make.bat` sestavuje hru i tři prototypy `design*.xex`. Kontroluj výstup každého
překladu: skript se při chybě nezastaví a poslední úspěšný příkaz ji může zakrýt.

Výsledek `tetris.xex` je určen pro Atari XL/XE s OS ROM, načtený XEX loaderem
na skutečném stroji nebo v emulátoru. Hra přímo řídí grafiku, zvuk a vstupy,
ale používá OS vektory `VVBLKI`/`VDSLST`, návrat přes `XITVBV` a znakový font
z ROM na `$E000`. BASIC nevyužívá. Časování je navrženo pro PAL (50 Hz);
harness nepotvrzuje kompatibilitu všech konfigurací emulátorů ani NTSC.

## Ovládání

| Akce                 | Joystick        | Klávesnice            |
|----------------------|-----------------|-----------------------|
| pohyb vlevo/vpravo   | vlevo / vpravo  | šipky vlevo / vpravo  |
| rotace               | FIRE / nahoru   | šipka nahoru, Z, X    |
| soft drop            | dolů            | šipka dolů            |
| hard drop            | –               | MEZERNÍK              |
| pauza                | –               | P, START              |
| opustit hru (menu)   | –               | ESC                   |
| menu: level / skill  | vlevo / vpravo  | SELECT / OPTION       |

V menu se nahoru/dolů vybírá položka, vlevo/vpravo mění její hodnota a FIRE
ji aktivuje (u LEVEL/SKILL zvýší hodnotu). START spustí hru z libovolné položky;
SELECT zvýší level a OPTION přepne obtížnost. Klávesy Z a RETURN odpovídají
FIRE, X odpovídá směru nahoru. Názvy šipek označují vstupy Atari;
jejich mapování na klávesnici počítače záleží na emulátoru.

## Obrazovky a mechaniky

- **Úvodní obrazovka** – titulek v ANTIC mode 7 s duhovým DLI, podtitul, nápověda.
- **Menu** – START GAME, LEVEL (1–15), SKILL (EASY / ADVANCED / EXPERT), HELP.
  EASY = prázdná studna a náhled NEXT, ADVANCED = startovní struktury cihel v každém
  levelu, EXPERT = struktury a bez náhledu NEXT.
- **HELP** – obrazovka s popisem obtížností, levelů a ovládání.
- **Demo** – po 750 snímcích (~15 s na PAL) nečinnosti na titulní obrazovce
  nebo v menu se spustí demo: AI (heuristika výška /
  díry / nerovnost / smazané řady + náhodný šum) hraje jako průměrný hráč
  lidským tempem. Blikající nápis DEMO nad nápovědou a hláška dole. Jakýkoliv
  namapovaný herní vstup nebo START/SELECT/OPTION demo ukončí; ostatní klávesy ne.
- **Herní obrazovka** – Graphics 0 (ANTIC mode 2) s vlastním display listem
  26 řádků: studna 10×24 z tenkých čar uprostřed, kostky = plný blok, vpravo
  NEXT (6×6 rámeček, dílek 1:1 ve spawn rotaci), LEVEL, SCORE, LINES, ROWS x/y,
  TIME; vlevo nápověda ovládání. Barvy dělají hráči (PMG) jako „filtr" nad
  textem, ladí se konstantami `COL_*` na začátku `tetris.asm`. Studna má
  jednolitou barvu `COL_WELL`; herní display list nepoužívá DLI. Duhové DLI
  patří titulku na úvodní obrazovce a v menu.
- **Level** – rychlost pádu podle `SpeedTab` (40 → 2 snímků na řádek) a cíl
  v řádcích podle `TargetTab` (5, 7, 9, 11, 12 … 20). Po splnění fanfára,
  bonus 1000 × level, studna se vyčistí a další level. V ADVANCED/EXPERT
  začíná každý level strukturou z `Pat1`..`Pat12` (nad level 12 se vzory
  opakují v cyklu 7–12; v levelech 13–20 je dole jedna výplňová řada).
  Hra postupuje nejvýše do levelu 20; po jeho splnění se level 20 opakuje.
- **Mazání řad** – plné řady 3× bliknou a zmizí se zvukem, vše nad nimi sesedne.
- **Skóre** – 40 / 100 / 300 / 1200 × level za 1–4 řady, +1 za buňku soft dropu,
  +2 za buňku hard dropu.
- **Game over** – když nový kus nemá kam spawnout: sestupný zvuk, studna se
  odspodu zaplní, čeká se na FIRE, nahoru, mezerník nebo START (platí i
  klávesové ekvivalenty). ESC vrací do menu; demo se vrátí samo.
- **Zvuky** – POKEY, 4 kanály, jednoduchý sekvencer v VBI (`SoundTick`).

## Vývojářský režim

Drž **OPTION** při spuštění `tetris.xex`. V menu pak jde vybrat level 1–20 a na herní
obrazovce vlevo dole svítí `DEV`. Klávesy ve hře: **N** = okamžitě další level (studna se
vyčistí a načte se struktura levelu), **G** = vynutit game over. Bez OPTION při startu
klávesy nic nedělají.

## Rozvržení paměti

| Oblast          | Adresa        | Obsah                                   |
|-----------------|---------------|-----------------------------------------|
| ZP              | $80–$91       | ukazatele, dočasné proměnné, čítač snímků |
| kód + data      | od $2000, pod $5000 | program, tabulky, `Board`/`Comp`/`PrevComp` |
| PMG             | $5000–$57FF   | hráči P0–P3 (single-line)               |
| herní obrazovka | $6000–$640F   | 26 řádků × 40 (mode 2), i HELP          |
| text menu       | $6A00–$6BFF   | řádky titulní obrazovky a menu          |
| display listy   | $7000, $7100  | hra, menu                               |

`Board`, `Comp` a `PrevComp` mají každý 240 bajtů (10×24). `ClearGameScr`
maže celých pět stránek `$6000–$64FF`, i když viditelná obrazovka končí na
`$640F`; tento přesah musí zůstat volný. Přesné adresy kódu ověřuj po překladu
v `tetris.lab`. Znaková sada hry je ROM na `$E000–$E3FF`.

## Prototypy designu

`design.asm` (GTIA 10), `design2.asm` (mode 4 + PMG) a `design3.asm` (Graphics 0,
schválený vzor) jsou statické mockupy, ze kterých vzešel současný vzhled.
Technická předávka podle současného zdroje je v [HANDOFF.md](HANDOFF.md).
Aktuální instrukce pro práci v projektu jsou v [AGENTS.md](AGENTS.md).
[CLAUDE.md](CLAUDE.md) na ně odkazuje, aby se pokyny nerozcházely.

## Testovací harness (`tools/`)

`tools/emu.py` je headless mini-emulátor (6502 + ANTIC/GTIA/POKEY v rozsahu,
který hra používá) v Pythonu; umí skriptovat vstupy a renderovat obrazovku do
PNG včetně DLI/WSYNC a PMG efektů. Potřebuje Python 3 a Pillow
(`python -m pip install Pillow`). Zápisy do registrů POKEY ukládá do
`Machine.pokey_log`; zvuk nesyntetizuje a neemuluje celý OS ani přesné
časování hardwaru. Potřebné chování přerušení OS nahrazuje sám.

Nejprve úspěšně přelož aktuální `tetris.xex` a `tetris.lab` výše uvedeným
příkazem. Skripty build neprovádějí. Potom z `src/tetris`:

```powershell
cd tools
python emu.py 120 out.png        # 120 snímků a screenshot
python test_game.py              # menu, help, hra, level, ADVANCED, EXPERT, pauza, ESC, game over, demo
```

`test_game.py` vypisuje stavy a ukládá `out_n_*.png` včetně přehledu
`out_n_sheet.png` do pracovního adresáře. Nemá aserce herního chování:
návratový kód 0 znamená dokončení scénáře, výpisy a obrázky je nutné posoudit.
Vývojářský režim tento skript neověřuje. Pro jeho skriptované zapnutí nastav
`m.set_consol(option=True)` ještě před prvním `m.run(...)` a pak OPTION uvolni.

Generované `*.xex`, `*.lst`, `*.lab` a `tools/out*.png` jsou ignorované Gitem.
Harness používá také sousední Snake (`../snake/test_snake.py`); při změně
sdíleného emulátoru zohledni i jeho testy.

[REVIEW.md](REVIEW.md) obsahuje nálezy kontroly zdroje a návrhy oprav.
Po úspěšném buildu lze z `src/tetris` spustit `python tools/audit_tetris.py`:
provádí cílené kontroly, vypíše důkazy v JSON a při zjištěných problémech
vrátí kód 1. Na současné verzi reprodukuje mimo jiné chybu sdílených
dočasných proměnných ve VBI; neznamená to, že jsou nálezy už opravené.
