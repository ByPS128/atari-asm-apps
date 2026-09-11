# Tetris pro Atari XL/XE (MADS)

Klasický Tetris v 6502 assembleru pro Atari 800XL/XE, inspirovaný amigáckým
*Tetris Pro* (Logic Systems, 1993): každý level má cíl v řádcích a rychlost,
ve vyšších obtížnostech začíná se startovními strukturami cihel ve studně.

## Build

```
make.bat            ; = mads tetris.asm -o:tetris.xex -t:tetris.lab
```

Výsledek `tetris.xex` spustíš v libovolném emulátoru (Altirra, atari800) nebo na
reálném stroji přes loader. Hra nepoužívá OS (vlastní display list, VBI, DLI,
přímé čtení hardwaru), takže funguje s BASICem i bez něj.

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

## Obrazovky a mechaniky

- **Uvodní obrazovka** – titulek v ANTIC mode 7 s duhovým DLI, podtitul, nápověda.
- **Menu** – START GAME, LEVEL (1–15), SKILL (EASY / ADVANCED / EXPERT), HELP.
  EASY = prázdná studna a náhled NEXT, ADVANCED = startovní struktury cihel v každém
  levelu, EXPERT = struktury a bez náhledu NEXT.
- **HELP** – dvě stránky: obtížnosti, levely a ovládání; bodování (tabulka bodů za
  1–4 řady, dropy, bonus za level). Libovolná klávesa listuje, ESC vrací do menu.
- **Demo** – po ~15 s nečinnosti v menu se spustí demo: AI (heuristika výška /
  díry / nerovnost / smazané řady + náhodný šum) hraje jako průměrný hráč
  lidským tempem. Blikající nápis DEMO nad nápovědou a hláška dole. Jakýkoliv
  vstup demo ukončí.
- **Barevné kostky** – aktivní kostka a náhled NEXT mají barvu podle typu (I tyrkysová,
  O žlutá, T fialová, S zelená, Z červená, J modrá, L oranžová) přes hráče P2/P3
  v dvojnásobné šířce; usazené kostky jsou šedé.
- **Herní obrazovka** – Graphics 0 (ANTIC mode 2) s vlastním display listem
  26 řádků: studna 10×24 z tenkých čar uprostřed, kostky = plný blok, vpravo
  NEXT (6×6 rámeček, dílek 1:1 ve spawn rotaci), LEVEL, SCORE, LINES, ROWS x/y,
  TIME; vlevo nápověda ovládání. Barvy dělají hráči (PMG) jako „filtr" nad
  textem, ladí se konstantami `COL_*` na začátku `tetris.asm`.
- **Level** – rychlost pádu podle `SpeedTab` (40 → 2 snímků na řádek) a cíl
  v řádcích podle `TargetTab` (5, 7, 9, 11, 12 … 20). Po splnění fanfára,
  bonus 1000 × level, studna se vyčistí a další level. V ADVANCED/EXPERT
  začíná každý level strukturou z `Pat1`..`Pat12` (nad level 12 se vzory
  opakují a přibývají výplňové řady).
- **Mazání řad** – plné řady 3× bliknou a zmizí se zvukem, vše nad nimi sesedne.
- **Skóre** – 40 / 100 / 300 / 1200 × level za 1–4 řady, +1 za buňku soft dropu,
  +2 za buňku hard dropu. Bonus za řady naskakuje postupně během blikání (24 snímků),
  rozložený rovnoměrně bez dělení (Bresenham po jednotkách 10 bodů), na konci sedí přesně.
  Stejně naskakuje bonus za dokončený level (1000 × level, 48 snímků), ten navíc pípá:
  každý třetí snímek jeden snímek tónu ~960 Hz (kanál 0), jako napočet v Ghostbusters.
- **Game over** – když nový kus nemá kam spawnout: sestupný zvuk, studna se
  odspodu zaplní, čeká se na FIRE/START.
- **Zvuky** – POKEY, 4 kanály, jednoduchý sekvencer v VBI (`SoundTick`).

## Vývojářský režim

Drž **OPTION** při spuštění `tetris.xex`. V menu pak jde vybrat level 1–20 a na herní
obrazovce vlevo dole svítí `DEV`. Klávesy ve hře: **N** = okamžitě další level (studna se
vyčistí a načte se struktura levelu), **G** = vynutit game over. Bez OPTION při startu
klávesy nic nedělají.

## Rozvržení paměti

| Oblast          | Adresa        | Obsah                                   |
|-----------------|---------------|-----------------------------------------|
| ZP              | $80–$93       | ukazatele, dočasné proměnné, čítač snímků |
| kód + data      | $2000–~$4400  | program, tabulky, `Board`/`Comp`        |
| PMG             | $5000–$57FF   | hráči P0–P3 (single-line)               |
| herní obrazovka | $6000–$640F   | 26 řádků × 40 (mode 2), i HELP          |
| text menu       | $6A00–$6BFF   | řádky titulní obrazovky a menu          |
| display listy   | $7000, $7100  | hra, menu                               |

## Prototypy designu

V `design/` (vlastní `make.bat`): `design.asm` (GTIA 10), `design2.asm` (mode 4 + PMG) a `design3.asm` (Graphics 0,
schválený vzor) jsou statické mockupy, ze kterých vzešel současný vzhled.
Historie rozhodnutí je v `HANDOFF.md`.

## Testovací harness (`tools/`)

`tools/emu.py` je headless mini-emulátor (6502 + ANTIC/GTIA/POKEY v rozsahu,
který hra používá) v Pythonu; umí skriptovat vstupy a renderovat obrazovku do
PNG včetně DLI/WSYNC a PMG efektů. Potřebuje Pillow.

```
cd tools
python emu.py 120 out.png        # 120 snímků a screenshot
python test_game.py              # menu, help, hra, level, ADVANCED, EXPERT, pauza, ESC, game over, demo
```
