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
| pauza                | START           | P                              |
| zpět do menu         | –               | ESC (i z pauzy)                |

## Obrazovky a mechaniky

- **Menu** – START GAME / ABOUT, výběr nahoru/dolů, vybraná položka inverzně.
- **Hra** – řádek 0 = `SCORE nnn` a `LENGTH nnn`, řádky 1–23 = rámeček, uvnitř had
  a jablko (vlastní glyfy, viz níže). Had startuje uprostřed
  s délkou 3 a jede doprava. Otočení o 180° se ignoruje (kontroluje se vůči směru
  posledního kroku, takže ani dvě rychlé klávesy v jednom kroku hada neotočí do sebe).
- **Rychlost** – na začátku 10 snímků na krok, každé třetí jablko zrychlí o
  1 snímek až na 3 (konstanty `START_DELAY`, `MIN_DELAY`, `SPEED_STEP`).
- **Kolize** – náraz do ohrady nebo do vlastního těla; detekuje se čtením
  videopaměti na políčku nové hlavy (had se kreslí inkrementálně: smaže se ocas,
  přikreslí hlava, stará hlava se přebarví na tělo).
- **GAME OVER** – tmavě šedé pozadí, nápis a čekání na FIRE / RETURN; skóre zůstává
  vidět.
## Grafika a zvuk

- **Had z vlastní znakové sady.** Při startu se ROM font zkopíruje do RAM (`FONT`) a
  od interního kódu `$60` se přepíše 15 glyfy ze `snake_font.inc`: tělo vodorovné a
  svislé, 4 rohy, 4 hlavy (s očima) a 4 špičky ocasu podle směru, jablko. Tělo je 6 px
  silné s 1px okrajem, takže rovnoběžné segmenty ve vedlejších sloupcích nesplývají
  a v zatáčkách na sebe rohy navazují. Glyfy generuje `gen_font.py` (jeden vzor,
  zbytek rotací a zrcadlením) – úprava vzhledu = úprava vzoru a `python gen_font.py`.
- **Směr každého segmentu** se drží v poli `SegDir` (směr, kterým segment přijel).
  Tělo = `BodyTab[in*4+out]` (rovně, nebo roh spojující vstupní a výstupní stranu),
  hlava = `HeadTab[dir]`, ocas = `TailTab[směr k dalšímu segmentu]`.
- **Ohrada** z ROM rámečkových znaků (CTRL-Q/E/Z/C rohy, CTRL-R vodorovně, `|` svisle).
- **Jablko přes PMG.** Znak jablka nese jen odlesk; tělo kreslí player 0 (červená
  `COL_APPLE`), stopku s lístkem player 1 (zelená `COL_LEAF`), oba na stejném HPOS.
  `PRIOR = 1` (hráči nad playfieldem): pixel textu nad hráčem dostane odstín hráče a jas
  textu, pixel hráče mimo text má barvu hráče, zbytek buňky zůstává barvou pozadí. Sprite
  má tvar jablka, ne celé buňky, proto pozadí kolem jablka nemění barvu. `AppleShow` /
  `AppleHide` udržují znak i data hráčů (`P0DATA`/`P1DATA`, řádek = `32 + 8*y`),
  `ClearScreen` sprite schová. Barvy ploch: menu `$94`, hra `$74`, game over `$04`.
- **ABOUT** – nápověda ukazuje skutečné jablko (znak + sprite); v levém horním rohu je dekorační
  had (7 znaků: ocas, svislé tělo, roh, vodorovné tělo, hlava), jehož hlava v náhodných
  intervalech (60–187 snímků) na 6 snímků mrkne (glyf `HEAD_R_BLINK`).
- **Menu** má vlastní display list: titulek SNAKE v ANTIC módu 6 (dvojnásobná šířka,
  barva `COL_TITLE` přes COLPF3; `$47` místo `$46` v `DListMenu` = mód 7, dvojnásobná
  i výška), položky s mezerou po stranách při inverzi.
- **Pauza** – P nebo START zastaví hru a ukáže inverzní PAUSED na stavovém řádku; P/START
  pokračuje, ESC v pauze hru ukončí (stejný význam jako ve hře).
- **Zvuky jako tabulky** dvojic AUDF/AUDC po snímcích (`SfxEat`, `SfxDenied`, `SfxOver`),
  přehrává je VBI přes `SndPtr`; nový zvuk utne předchozí. Sežrání jablka = šestisnímkový
  stoupavý „blip" (tři čisté tóny, poslední doznívá), denied = klesavý dvoutón (alert) při stisku
  opačného směru (joystick i klávesnice), jen při novém stisku, ne při držení.

## Test

```
python test_snake.py
```

Skript řídí hru v headless harnessu `../tetris/tools/emu.py` (6502 + ANTIC/GTIA/POKEY
bez OS): projde menu, ABOUT, rozjede hru, otestuje ignorování otočky, dojede
k jablku, ověří zvuky, rohy v zatáčce a v U, pauzu, narazí do zdi a vrátí se přes GAME OVER do menu. Ukládá `out_menu.png`,
`out_game.png`, `out_over.png`. Potřebuje přeložený `snake.xex` a `snake.lab`
(tabulku labelů z `mads -t:`).

## Historie

Původní verze (leden 2025) v emulátoru hlásila `BOOT ERROR`: rutiny pro tisk textu
sundávaly ze zásobníku čtyřmi `PLA` i návratovou adresu loaderu a `RTS` pak skočil
zpět do bootovacího kódu OS s nastaveným carry. Kromě toho psala do `$9400` místo
skutečné videopaměti, alokovala pole hada jako jeden bajt (`.BYTE MAX_LEN`) a
četla FIRE a klávesnici ze špatných registrů. Verze v tomto adresáři je přepis od
nuly stejným stylem jako `../tetris`. První přepis (had z běžných znaků, ohrada
z inverzních mezer) je v historii gitu do commitu `0069de5` jako `snake.asm` vedle
`snake_V2.asm`; od té doby zůstala jen V2 pod původním jménem.
