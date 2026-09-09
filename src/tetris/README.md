# Tetris pro Atari XL/XE (MADS)

Klasický Tetris v 6502 assembleru pro Atari 800XL/XE, inspirovaný mechanikou
amigáckého *Tetris Pro* (Logic Systems, 1993): každý level začíná s několika
řádky „smetí" a je splněn, jakmile se herní plocha úplně vyprázdní.

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
| pauza                | –               | START, P              |
| zpět do menu         | –               | ESC                   |
| menu: level / skill  | vlevo / vpravo  | SELECT / OPTION       |

## Obrazovky a mechaniky

- **Uvodní obrazovka** – titulek v ANTIC mode 7 s duhovým DLI, podtitul, nápověda.
- **Menu** – START GAME, LEVEL (1–15), SKILL (BASIC / EXPERT). Expert nezobrazuje
  náhled dalšího kusu.
- **Demo** – po ~15 s nečinnosti v menu se spustí demo: AI (heuristika výška /
  díry / nerovnost / smazané řady + náhodný šum) hraje jako průměrný hráč
  lidským tempem. Velký blikající nápis DEMO vlevo od studny a blikající hláška
  dole. Jakýkoliv vstup (joystick, klávesa, START/SELECT/OPTION) demo ukončí.
- **Hra** – plocha 10×20 v GTIA režimu 10 (9 barev): I cyan, O žlutá, T fialová,
  S zelená, Z červená, J modrá, L oranžová. Texty nad a pod plochou v mode 2,
  přepínání režimu dělá DLI. Rotace s jednoduchým „wall kickem".
- **Mazání řad** – plné řady 3× bliknou bíle a zmizí se zvukem, vše nad nimi
  sesedne; kontrola se opakuje, dokud nějaká plná řada existuje.
- **Level** – rychlost pádu podle tabulky `SpeedTab` (40 → 2 snímků na řádek),
  počet řádků smetí podle `GarbTab` (2 → 8). Vyprázdnění plochy = level hotov,
  fanfára, bonus 1000 × level, další level.
- **Skóre** – 40 / 100 / 300 / 1200 × level za 1–4 řady, +1 za buňku soft dropu,
  +2 za buňku hard dropu.
- **Game over** – když nový kus nemá kam spawnout: sestupný zvuk, plocha se
  odspodu zaplní bílou, čeká se na FIRE/START.
- **Zvuky** – POKEY, 4 kanály, jednoduchý sekvencer v VBI (`SoundTick`):
  pohyb, rotace, drop, soft drop, řada, tetris, fanfára (2 hlasy), game over, menu.

## Rozvržení paměti

| Oblast          | Adresa        | Obsah                                   |
|-----------------|---------------|-----------------------------------------|
| ZP              | $80–$93       | ukazatele, dočasné proměnné, čítač snímků |
| kód + data      | $2000–~$3B00  | program, tabulky, `Board`/`Comp`        |
| bitmapa plochy  | $5010–$695F   | 162 řádků × 40 B (mode F / GTIA 10)     |
| text menu       | $6A00–$6BFF   | řádky titulní obrazovky a menu          |
| text hry        | $6E00–$6E77   | 3 řádky (hlavička, hodnoty, hláška)     |
| display listy   | $7000, $7100  | hra, menu                               |

## Testovací harness (`tools/`)

`tools/emu.py` je headless mini-emulátor (6502 + ANTIC/GTIA/POKEY v rozsahu,
který hra používá) v Pythonu; umí skriptovat vstupy a renderovat obrazovku do
PNG včetně DLI/WSYNC efektů. Potřebuje Pillow.

```
cd tools
python emu.py 120 out.png        # 120 snímků a screenshot
python test_flow.py              # menu -> hra -> pohyb, rotace, hard drop
python test_demo.py              # necinnost -> demo, AI hraje, klavesa demo ukonci
python test_misc.py              # level complete, game over, pauza, ESC, expert
```

`cpu6502.py` je jádro CPU převzaté z mini-emulátoru ve skillu
`atari-to-web-emulator`; `atari-rom-font.png` je systémový font, `DefaultPAL.pal`
paleta pro render.
