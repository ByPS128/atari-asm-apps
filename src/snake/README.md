# Snake pro Atari XL/XE (MADS)

Klasický Snake v 6502 assembleru pro Atari 800XL/XE: had na ploše 38×21 políček,
jablka, zrychlování, menu a obrazovka GAME OVER.

## Build

```
make.bat            ; = mads snake.asm -o:snake.xex -t:snake.lab
```

Výsledek `snake.xex` spustíš v libovolném emulátoru (Altirra, atari800) nebo na
reálném stroji přes loader. Hra nepoužívá OS (vlastní display list, VBI, přímé
čtení hardwaru), takže funguje s BASICem i bez něj.

## Ovládání

| Akce                 | Joystick        | Klávesnice                     |
|----------------------|-----------------|--------------------------------|
| směr hada            | 4 směry         | šipky (CTRL + `-` `=` `+` `*`) |
| potvrzení v menu     | FIRE            | RETURN, MEZERNÍK               |
| zpět do menu         | –               | ESC                            |

## Obrazovky a mechaniky

- **Menu** – START GAME / ABOUT, výběr nahoru/dolů, vybraná položka inverzně.
- **Hra** – řádek 0 = `SCORE nnn` a `LENGTH nnn`, řádky 1–23 = ohrada (inverzní
  mezera), uvnitř had (`@` hlava, `O` tělo) a jablko (`*`). Had startuje uprostřed
  s délkou 3 a jede doprava. Otočení o 180° se ignoruje (kontroluje se vůči směru
  posledního kroku, takže ani dvě rychlé klávesy v jednom kroku hada neotočí do sebe).
- **Rychlost** – na začátku 10 snímků na krok, každé třetí jablko zrychlí o
  1 snímek až na 3 (konstanty `START_DELAY`, `MIN_DELAY`, `SPEED_STEP`).
- **Kolize** – náraz do ohrady nebo do vlastního těla; detekuje se čtením
  videopaměti na políčku nové hlavy (had se kreslí inkrementálně: smaže se ocas,
  přikreslí hlava, stará hlava se přebarví na tělo).
- **GAME OVER** – červené pozadí, nápis a čekání na FIRE / RETURN; skóre zůstává
  vidět.
- **Zvuk** – krátké pípnutí při sežrání jablka, hluboký tón při smrti (POKEY
  kanál 1, odpočítává VBI).

## Test

```
python test_snake.py
```

Skript řídí hru v headless harnessu `../tetris/tools/emu.py` (6502 + ANTIC/GTIA/POKEY
bez OS): projde menu, ABOUT, rozjede hru, otestuje ignorování otočky, dojede
k jablku, narazí do zdi a vrátí se přes GAME OVER do menu. Ukládá `out_menu.png`,
`out_game.png`, `out_over.png`. Potřebuje přeložený `snake.xex` a `snake.lab`
(tabulku labelů z `mads -t:`).

## Historie

Původní verze (leden 2025) v emulátoru hlásila `BOOT ERROR`: rutiny pro tisk textu
sundávaly ze zásobníku čtyřmi `PLA` i návratovou adresu loaderu a `RTS` pak skočil
zpět do bootovacího kódu OS s nastaveným carry. Kromě toho psala do `$9400` místo
skutečné videopaměti, alokovala pole hada jako jeden bajt (`.BYTE MAX_LEN`) a
četla FIRE a klávesnici ze špatných registrů. Verze v tomto adresáři je přepis od
nuly stejným stylem jako `../tetris`.
