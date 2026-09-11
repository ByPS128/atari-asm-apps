# Tetris pro Atari XL/XE – technická předávka

Stav ověřený podle `tetris.asm` dne 11. 9. 2026. Zdrojový kód je autorita;
tento dokument popisuje jeho současnou implementaci. Pravidla práce jsou
v [AGENTS.md](AGENTS.md), ovládání a build v [README.md](README.md).
[SPEC.md](SPEC.md) převádí implementaci do zadání pro obdobnou novou hru
a obsahuje úplné tabulky dílků, struktur, rychlostí, cílů a zvuků.

## Stav projektu a soubory

Hra je implementovaná v `tetris.asm` (6502, MADS): titulní obrazovka, menu,
HELP, tři obtížnosti, levely s cílem řádků, AI demo, pauza a zvuky POKEY.
Přenos rozvržení Graphics 0 a nového modelu levelů je hotový.

V `design/` jsou čtyři statické prototypy: `design.asm` (GTIA 10, `font35.inc`),
`design2.asm` (ANTIC mode 4 + PMG, `charset4.inc`), `design3.asm` (Graphics 0)
a `design4.asm` (barevná kostka/NEXT). Rozvržení hry vychází z design3,
barevné kostky z design4; přesné pozice a barvy určuje `tetris.asm`.
Hra používá font z ROM, žádný z obou include souborů nenačítá.

## Obrazovka a paměť

- `GAMESCR=$6000`, 26 řádků × 40 znaků v ANTIC mode 2. `GameDL` na `$7000`
  obsahuje osm prázdných linek, LMS prvního textového řádku, 25 dalších řádků
  a skok na začátek. Nemá DLI bity. `ClearGameScr` maže `$6000–$64FF`,
  tedy více než viditelných 1040 bajtů do `$640F`.
- ROM znaková sada (`CHBASE=$E0`), usazená kostka = inverzní mezera `$80`,
  prázdno i aktivní buňky v textu = 0; aktivní kostku vykresluje PMG.
  Studna má 10×24 viditelných buněk ve sloupcích 15–24, řádcích 0–23.
  Stěny jsou ve sloupcích 14 a 25, dno na řádku 24.
- NEXT: nápis řádek 0/sloupec 32; rám sloupce 31–36, řádky 1–6, vnitřek
  4×4. Dílek je vycentrovaný ve spawn rotaci 0, ve stejném měřítku jako ve
  studni. EXPERT skrývá nápis, rám i dílek.
- Panel: popisky i hodnoty ve sloupci 30; LEVEL řádky 9/10, SCORE 12/13,
  LINES 15/16, ROWS 18/19, TIME 21/22.
- Nápověda: akce ve sloupci 2, ovládání ve sloupci 3; MOVE/STICK řádky 2/3,
  ROTATE/FIRE 5/6, DROP/DOWN 8/9, HARD/SPACE 11/12, PAUSE/P 14/15,
  MENU/ESC 17/18. Obtížnost je na řádku 22, DEV na řádku 24.
  Herní panel používá EASY / ADV. / EXPERT, aby se text s odsazením vešel
  do osmiznakového pruhu P0. Menu a HELP zachovávají celý název ADVANCED.
  Demo bliká na řádku 0 nad nápovědou, zprávy jsou na řádku 25.
- PMG single-line používá oblast `$5000–$57FF`, hráče P0–P3 na `$5400–$5700`.
  P0 quad podbarvuje nápovědu, P1 quad panel; P2 double kreslí aktivní kostku,
  P3 double NEXT. `Vbi` nastavuje `DMACTL=$3E`, `GRACTL=3`, `PRIOR=1`.
  Nápověda má `$B0`, panel `$20`, text/usazené buňky `$0C`, pozadí `$00`.
  `PieceCol` = `$9A,$EE,$48,$B8,$34,$76,$1A` pro I/O/T/S/Z/J/L. Aktivní buňky
  jsou ve videopaměti prázdné, takže hráč dodává sytou barvu i jas.
  `UpdatePiecePM` při `BoardDirty` připraví 32 bajtů `PcBuf`, `PcRow`, HPOS
  a barvu. `DrawNext` při `NextDirty` připraví `NxBuf`, HPOS a barvu.
  VBI teprve smaže staré řádky P2 a zkopíruje oba buffery do PMG RAM.
  Zachovat kopírování během VBI: zápis v hlavní smyčce dříve trhal barvu.
- Titulní obrazovka a menu mají samostatný `MenuDL` na `$7100` a texty od
  `$6A00`. Titulek používá mode 7, podtitul a položky mode 6, nápověda mode 2.
  DLI vykresluje duhu titulku; HELP má dvě stránky (ovládání a bodování),
  používá herní textovou obrazovku bez PMG. ESC z obou vrací přímo do menu.
- ZP je `$80–$92`, kód a data od `$2000` musí zůstat pod PMG na `$5000`.
  Adresy rutin a proměnných ověřuj v čerstvém `tetris.lab`.

## Herní jádro

- EASY má prázdnou plochu a NEXT, ADVANCED struktury a NEXT, EXPERT struktury
  bez NEXT. Ve všech obtížnostech rozhoduje o dokončení počet smazaných řádků.
- Menu dovoluje začátek v levelu 1–15, hra postupuje do 20. OPTION držený při
  spuštění zapíná `DevMode`: výběr 1–20, N připraví další level bez bonusu,
  G zaplní horní dva řádky a vynutí nový spawn, který vyvolá game over.
- `SpeedTab` určuje snímky na řádek pádu, `TargetTab` cíl řádků.
  Po splnění cíle `LevelDoneSeq` přičte 1000 × level, přehraje fanfáru,
  počká 150 snímků a vyčistí plochu pro další level. Na maximu opakuje level 20.
  `StartLevel` nastaví rychlost, cíl, vynuluje `RowsInLevel` a načte strukturu.
- `FillPattern` používá `Pat1`–`Pat12`, nad levelem 12 cyklicky vzory 7–12.
  Dole přidává `(Level-1)/12` výplňových řad (celočíselně, interně nejvýše 6);
  v dosažitelných levelech 13–20 je to jedna řada `FillerA`.
  Formát vzoru: počet řádků a řádky shora dolů po 10 znacích, `#` = cihla.
  Žádný vzor nemá plnou řadu, některé řádky nejsou zrcadlově symetrické.
- `Board`, `Comp`, `PrevComp` mají každý 240 bajtů. `Board` obsahuje usazené
  kostky, `BuildComp` přidává padající kus nebo blikající řady, `DrawBoard`
  kreslí jen změněné řádky. `EMPTY=8`, `WHITE=7` i buňky s bitem `ACTIVE=$10`
  se vykreslují jako prázdno. P2 je vidět v `ST_FALL` i `ST_PLAN`.
  `BoardDirty`/`ValuesDirty` zabraňují zbytečnému sestavování obrazu a zápisu
  panelu. Zpráva a banner mají cache obsahu/fáze blikání.
- `StSpawn` připraví kus v rotaci 0 na X=3/Y=0 a kontroluje kolizi;
  `StFall` zpracuje pohyb a pád; `StClear` nechá řady třikrát bliknout během
  24 snímků, průběžně přičítá skóre, odstraní je a vyhodnotí cíl levelu.
  Demo mezi spawnem a pádem používá `StPlan`, nejvýše jeden kandidát za krok.
  Během hledání se čtou vstupy a běží čas, aktivní dílek zůstává ve spawn poloze.
- Rotace postupuje o jednu variantu s vodorovnými kicky `0,-1,+1,-2,+2`.
  Pohyb má DAS 12/4 snímky. Soft drop má interval 2 snímků a po spawnu
  vyžaduje uvolnění směru dolů před opětovným zrychlením.
- Skóre: 40/100/300/1200 × level za 1–4 řady, +1 za buňku soft dropu,
  +2 za buňku hard dropu. `Score` má 3 BCD bajty, `Lines` 2 BCD bajty;
  `RowsInLevel`/`RowsTarget` jsou binární. Čas v `FrameStep` počítá 50 snímků
  na sekundu a stojí při pauze/game over; hra neprovádí detekci PAL/NTSC.
- `StartClearScore`/`StartScoreAnim` připraví bonus v jednotkách 10 bodů.
  `ScoreTick` jej rozloží rovnoměrně do 24 snímků u řad a 48 u levelu.
  `ScoreLines` po odstranění řad aktualizuje jejich počítadla a `ValuesDirty`;
  `AddScore` příznak nastavuje při každém přírůstku. `ScoreFlush` doplatí zbytek.
  Jen levelový bonus pípá: `ScoreTick` zapisuje `$21/$A8` na kanál 0,
  jeden snímek tónu každé tři snímky, na konci jej umlčí.
- Demo začíná po 750 snímcích nečinnosti na titulní obrazovce nebo v menu,
  používá zvolený level a obtížnost. `AiPlan` zahájí hledání,
  `AiPlanStep`/`Evaluate` hodnotí výšky,
  díry, nerovnost a plné řady s náhodným šumem, `AiStep` simuluje vstupy.
  Návrat do menu vyvolají namapované herní vstupy nebo START/SELECT/OPTION;
  libovolná nenamapovaná klávesa demo neukončí.
- `GameOverSeq` zaplní studnu odspodu a čeká na FIRE, nahoru, hard drop nebo
  START; ESC hru opustí. Demo po zaplnění čeká 150 snímků a vrátí se samo.
  Game over nepřepíná pauzu; dokončení levelu při pauze drží odpočet i stav
  přičítání bonusu a umlčí jeho pípání. Zpráva PAUSED bliká po 32 snímcích
  a její cache sleduje bit `$20` čítače, ostatní blikající zprávy bit `$10`.

## Hardware a vývojové pasti

Hra přímo čte `PORTA`, `TRIG0`, `CONSOL`, `SKSTAT`/`KBCODE` a `RANDOM`,
ale závisí na OS: instaluje přerušení přes `VVBLKI`/`VDSLST`, VBI se vrací
přes `XITVBV` a font bere z ROM. `Vbi` aktualizuje display list, režim DLI,
barvy, PMG a čtyřkanálový zvukový sekvencer `SoundTick`. DLI při herním režimu
jen obnoví registry a vrátí se. Obě přerušení před výpočty provádějí `CLD`.
Zvuk používá soukromý ukazatel `SndRead` a kanál ukládá na zásobník;
pracovní ukazatele ani `tmp*` hlavní smyčky nepřepisuje.

MADS nerozlišuje velikost písmen labelů; adresové výrazy zapisuj jako
`<(label+7)` a `>(label+7)`. Texty pro `PUTS` používají `dta d'...',$FF`,
struktury `dta c'...'`. Krátké BCD úseky zakončuj `CLD`. `RenderGame` přepisuje
dočasné proměnné; čítače blokujících sekvencí patří do `SeqCnt`/`SeqRow`.

## Ověření

Z `src/tetris` v PowerShellu:

```powershell
mads tetris.asm -o:tetris.xex -t:tetris.lab
# Po úspěšném překladu:
cd tools
python test_game.py
python test_piece_pm.py
python test_ui.py
python test_irq.py
python audit_tetris.py
python test_build.py
python emu.py 120 out.png
```

Harness vyžaduje Python 3 a Pillow. `test_game.py` pokrývá průchod menu,
HELP, EASY, dokončením levelu, ADVANCED, EXPERT, pauzou, ESC, game over a demem.
Kontroluje stavy i soulad plochy s obrazem; při úspěchu vypíše `ALL OK` a vrátí 0.
`audit_tetris.py` přidává kontroly kolizí, řad, struktur, VBI, zvukových sekvencí,
postupného hledání AI, pauzy a DEV. `test_build.py` ověřuje řízení dávkového
buildu v dočasném adresáři. Skripty herních testů samy nesestavují XEX.
`make.bat` sestaví jen hru, `design/make.bat` čtyři prototypy. Oba končí při
první chybě. Po změně větve sestav XEX i labely znovu.

`tools/emu.py` s `tools/cpu6502.py` modeluje potřebnou část CPU/grafiky,
DLI/WSYNC a PMG, nahrazuje potřebné chování přerušení OS. POKEY zápisy pouze
loguje, zvuk nesyntetizuje; nejde o plný ani cyklově přesný emulátor.
Sdílený harness využívá také Snake. Vizuální výstup, zvuk a kompatibilitu
s reálným hardwarem či NTSC je nutné ověřovat mimo tento harness.
