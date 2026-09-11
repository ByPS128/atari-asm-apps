# Tetris – pokyny pro práci v tomto adresáři

Tyto pokyny platí pro `src/tetris` a jeho podadresáře.
Aktuální popis hry a ovládání je v `README.md`, technická předávka v `HANDOFF.md`.
Zdrojový kód je autorita; při rozporu ověř jeho chování a oprav dokumentaci.
`SPEC.md` je zadání pro vytvoření obdobné hry odvozené z implementace,
včetně datových tabulek a přejímacích scénářů. `CLAUDE.md` odkazuje na tento
soubor; společné pokyny udržuj zde.

Při změně chování, ovládání, vzhledu, herních tabulek nebo buildu aktualizuj
v rámci stejné práce příslušné části `README.md`, `HANDOFF.md` a `SPEC.md`.
Změny pracovních postupů patří sem. Dokumentace má popisovat implementované
chování; záměry do budoucna nesměšuj se současným stavem. Přejímací scénáře
v `SPEC.md` jsou požadavky na ověření, nikoli tvrzení o existujícím pokrytí testy.

## Build a ověření

- Pracuj z `src/tetris`. Hru sestav příkazem
  `mads tetris.asm -o:tetris.xex -t:tetris.lab` (MADS v `PATH`).
  `./make.bat` sestaví také všechny tři designové prototypy, ale nezastaví se
  při chybě; kontroluj jednotlivé překlady.
- Před ověřováním změny assembleru úspěšně sestav aktuální XEX i labely.
  Harness sám nepřekládá a staré výstupy neověřují nový kód.
- Z `tools` spusť `python test_game.py` (Python 3 + Pillow).
  Skript vypisuje stavy a vytváří `out_n_*.png` a `out_n_sheet.png`.
  Nemá aserce herního chování, proto kromě návratového kódu zkontroluj
  relevantní výpisy a obrázky. Nové chování ověř cíleným scénářem;
  vývojářský režim současný skript nepokrývá.
- Samostatný screenshot: z `tools` spusť `python emu.py 120 out.png`.
  Pro další scénáře použij `Machine`, `load_labels()`, `label()`, `tap()`,
  `set_key()`, `set_stick()`, `set_consol()` a `screenshot()` v `tools/emu.py`.
  Dev režim zapni přes `set_consol(option=True)` před prvním `run()`.
- Harness má vlastní částečný model CPU/grafiky a přerušení OS; POKEY pouze
  zaznamenává do `pokey_log`. Nenahrazuje kontrolu obrazu, zvuku a časování
  na Atari nebo v plném emulátoru. Hra počítá s PAL 50 Hz.
- `tools/emu.py` a `tools/cpu6502.py` využívá i `../snake/test_snake.py`.
  Při změně sdíleného harnessu ověř i Snake po sestavení jeho aktuálního
  XEX a labelů; změny testované pouze Tetrisem za ověřené pro Snake nevydávej.
- U čistě dokumentačních změn stačí kontrola proti zdrojům a diffu.
  Generované XEX, listingy, labely, screenshoty ani místní referenční ADF
  nepřidávej do commitu.
- Známé nálezy a důkazy jsou v `REVIEW.md`; cílený audit spouštěj po buildu
  z `src/tetris` pomocí `python tools/audit_tetris.py`. Při nálezu vrací kód 1.
  Při opravě nálezu aktualizuj jeho stav v review a zachovej odpovídající
  regresní ověření. Audit není náhradou za všechny přejímací scénáře.

## Architektura a současné mechaniky

- `tetris.asm` obsahuje celou hru: proměnné a tabulky, titulní obrazovku/menu,
  `RunGame`/`FrameStep`, stavy `StSpawn`/`StFall`/`StClear`, kolize a rotace,
  skóre, levely, AI, vykreslování, vstupy, zvuky a přerušení.
- `Board` = usazené buňky, `Comp` = obraz včetně padajícího kusu/blikání,
  `PrevComp` = poslední vykreslený stav. Každé pole má 240 bajtů (10×24).
  Typy kusů jsou 0–6, `WHITE=7` je značka skryté blikající řady, `EMPTY=8`.
  Při změně rozměrů zkontroluj také pevné délky polí, smyčky a tabulky.
- EASY má prázdnou studnu a NEXT, ADVANCED struktury a NEXT, EXPERT
  struktury bez celého rámečku NEXT. Názvy BASIC a dvoustupňová obtížnost
  ve starších komentářích už neplatí.
- `SpeedTab` a `TargetTab` určují rychlost a cíl řádků. Po dosažení cíle
  `LevelDoneSeq` přičte 1000 × level a připraví prázdnou plochu či strukturu
  dalšího levelu. Maximum je 20 a tento level se opakuje. Menu běžně dovoluje
  1–15; OPTION při startu zapne `DevMode`, výběr 1–20 a klávesy N/G.
- `FillPattern` vybírá `Pat1`–`Pat12`, nad 12 opakuje vzory 7–12.
  Počet výplňových řad je `(Level-1)/12` celočíselně, tedy jedna pro 13–20.
  Vzor tvoří počet řádků a řádky shora dolů po 10 znacích; `#` znamená cihlu.
  Zachovej nepřítomnost plných řad. Ne všechny vzory jsou zrcadlově symetrické.
- `ReadInputs` čte hardware a vytváří držené/nové vstupy. Demo začíná po
  750 snímcích nečinnosti na titulní obrazovce nebo v menu a přerušují jej
  pouze namapované herní vstupy či START/SELECT/OPTION. AI plánuje v
  `AiPlan`/`Evaluate` a simuluje vstupy v `AiStep`.

## Obraz a vazba na OS

- Zachovej Graphics 0 (ANTIC mode 2), 26×40 znaků, 24 viditelných řádků
  studny, tenké stěny, plný blok `$80` a NEXT ve spawn rotaci 0 v měřítku 1:1.
  Rozvržení řídí `WELL_COL`, `NEXT_COL`, `PAN_COL`, `HINT_COL`, `MSG_ROW`.
- Barvy nastavují `COL_*` a PMG ve `Vbi`. Studna je jednolitá (`COL_WELL`);
  `GameDL` nepoužívá DLI. DLI dělá pouze duhu titulku/menu. Historický návrh
  gradientu po řádcích není současná implementace.
- `design3.asm` je reference rozvržení; `design.asm` (GTIA 10 + `font35.inc`)
  a `design2.asm` (mode 4 + PMG + `charset4.inc`) jsou dřívější prototypy.
  Hra tyto include soubory nepoužívá. Schválené rozvržení nevracej ke chunky
  písmu, texturovaným kostkám nebo zvětšenému NEXT bez požadavku uživatele.
- Hra používá `VVBLKI`, `VDSLST`, `XITVBV` a ROM font přes `CHBASE=$E0`.
  Není nezávislá na OS. Zachovej kontrakt přerušení: `Vbi` se vrací přes
  `XITVBV`, `Dli` obnovuje A/X/Y a končí `RTI`.
- Vstupy čti přes `PORTA`, `TRIG0`, `CONSOL`, `SKSTAT`/`KBCODE` a náhodu přes
  `RANDOM`. Harness neaktualizuje OS shadow registry vstupů.
- ZP zabírá `$80–$91`, program/data začínají na `$2000` a musí zůstat pod PMG
  oblastí `$5000–$57FF`. Obrazovka je `$6000–$640F`, ale její mazání sahá do
  `$64FF`. Menu rezervuje `$6A00–$6BFF`; display listy jsou na `$7000`/`$7100`.
  Aktuální adresy rutin a proměnných ber z čerstvého `tetris.lab`.

## Konvence a pasti assembleru

- Zachovej styl zdroje: mnemoniky malými písmeny, labely bez dvojteček,
  konstanty velkými písmeny, komentáře v kódu ASCII, dokumentace česky
  s diakritikou. MADS nerozlišuje velikost písmen v labelech.
- Adresové výrazy závorkuj: `<(label+7)` a `>(label+7)`.
  `:n` opakuje instrukci/direktivu, `:1` atd. jsou parametry maker.
- Pro obrazovkové řetězce používej stávající `dta d'...',$FF` a makro `PUTS`
  (`ptr` = zdroj, `ptr2` = cíl, `TxtOr` = maska). Vzory struktur používají
  `dta c'...'` pro porovnání s literálem `'#'`; nezaměňuj oba formáty.
- `Score`, `Lines`, `TimeSec` a `TimeMin` jsou BCD; `Level`, `RowsInLevel`
  a `RowsTarget` jsou binární. `SED` omez na BCD výpočty a zakonči `CLD`.
  Obě přerušení musí začínat výpočty s vyčištěným decimal flagem.
- `RenderGame` a další rutiny přepisují `tmp*`, ukazatele a `celly`.
  Dlouhé sekvence přes tato volání drží čítače v `SeqCnt`/`SeqRow`.
