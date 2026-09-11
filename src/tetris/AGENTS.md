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

## Git a výchozí verze

Před založením opravné větve ověř `git status`, `git branch -avv`, aktualizuj
reference pomocí `git fetch origin` a porovnej lokální větev s `origin/main`.
Otevřená lokální `main` nemusí obsahovat nejnovější hru. Ověř také poslední
commity pro `src/tetris`, zejména při rozporu se vzhledem popsaným uživatelem.
Nezahazuj místní commity ani rozpracované změny. Po přepnutí či sloučení větví
znovu sestav XEX a labely; ignorované výstupy Git při checkoutu neaktualizuje.

## Build a ověření

- Pracuj z `src/tetris`. Hru sestav příkazem
  `mads tetris.asm -o:tetris.xex -t:tetris.lab` (MADS v `PATH`).
  `./make.bat` sestaví jen hru a labely (`game` je nadále přijímaný argument).
  Čtyři prototypy sestavuje samostatný `./design/make.bat`. Oba skripty
  pracují ve svém adresáři a při první chybě končí nenulovým kódem.
- Před ověřováním změny assembleru úspěšně sestav aktuální XEX i labely.
  Harness sám nepřekládá a staré výstupy neověřují nový kód.
- Z `tools` spusť `python test_game.py` (Python 3 + Pillow).
  Skript kontroluje herní stavy a soulad studny s obrazovkou, vytváří
  `out_n_*.png` a `out_n_sheet.png`. Úspěch = `ALL OK` a návratový kód 0.
  Po změně vzhledu zkontroluj také relevantní obrázky.
- Po změně hry spusť také `python test_piece_pm.py`, `python test_ui.py`
  a `python test_irq.py` z `tools`: barvy a masky P2/P3, HELP, animace skóre,
  blikání pauzy a přerušení při kreslení textu.
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
- Po změně hry spusť také audit (včetně DEV a zvukového sekvenceru).
  Po změně buildu spusť `python tools/test_build.py`; test ověřuje zastavení
  po chybě každého překladu hry/prototypů a variantu `game` v dočasném adresáři.

## Architektura a současné mechaniky

- `tetris.asm` obsahuje celou hru: proměnné a tabulky, titulní obrazovku/menu,
  `RunGame`/`FrameStep`, stavy `StSpawn`/`StPlan`/`StFall`/`StClear`, kolize a rotace,
  skóre, levely, AI, vykreslování, vstupy, zvuky a přerušení.
- `Board` = usazené buňky, `Comp` = obraz včetně padajícího kusu/blikání,
  `PrevComp` = poslední vykreslený stav. Každé pole má 240 bajtů (10×24).
  Typy kusů jsou 0–6, `WHITE=7` je značka skryté blikající řady, `EMPTY=8`.
  Aktivní buňky v `Comp` mají bit `ACTIVE=$10`: v textu jsou prázdné, kreslí je P2.
  Délky polí/smyček používají `BOARD_SIZE`. Aserce MADS hlídají rozměry 10×24
  a osmibitový index; při změně rozměrů uprav i pevné tabulky a rozvržení.
- EASY má prázdnou studnu a NEXT, ADVANCED struktury a NEXT, EXPERT
  struktury bez celého rámečku NEXT.
- `SpeedTab` a `TargetTab` určují rychlost a cíl řádků. Po dosažení cíle
  `LevelDoneSeq` přičítá 1000 × level po 48 snímků a připraví plochu či strukturu
  dalšího levelu. Maximum je 20 a tento level se opakuje. Menu běžně dovoluje
  1–15; OPTION při startu zapne `DevMode`, výběr 1–20 a klávesy N/G.
- `FillPattern` vybírá `Pat1`–`Pat12`, nad 12 opakuje vzory 7–12.
  Počet výplňových řad je `(Level-1)/12` celočíselně, tedy jedna pro 13–20.
  Vzor tvoří počet řádků a řádky shora dolů po 10 znacích; `#` znamená cihlu.
  Zachovej nepřítomnost plných řad. Ne všechny vzory jsou zrcadlově symetrické.
- `ReadInputs` čte hardware a vytváří držené/nové vstupy. Demo začíná po
  750 snímcích nečinnosti na titulní obrazovce nebo v menu a přerušují jej
  pouze namapované herní vstupy či START/SELECT/OPTION. AI plánuje v
  `AiPlan`/`AiPlanStep`/`Evaluate` a simuluje vstupy v `AiStep`.
  `StPlan` vyhodnotí nejvýše jednoho kandidáta za krok. `AiSearchX/Rot` musí
  přežít vykreslování, které přepisuje `Test*`; při návratu z `AiPlanStep`
  musí být hypotetický dílek odstraněný z `Board`. Čas/vstupy během hledání
  běží, gravitace začne až ve `StFall`.
- `BoardDirty` a `ValuesDirty` nastavuj při změně zobrazovaných dat;
  `SetGameScreen` oba příznaky vynucuje. `RenderGame` stabilní části přeskakuje.
  Cache zprávy/banneru zohledňuje jejich obsah i fázi blikání.
- Bonusy za řady přičítá `ScoreTick` během 24 snímků blikání, bonus za level
  během 48 snímků. `ScoreLines` aktualizuje jen počítadla řad a `ValuesDirty`.
  Napočet levelu pípá na kanálu 0 (1 snímek tón + 2 ticho).
- Pauza bliká po 32 snímcích a zastavuje odpočet i napočet `LevelDoneSeq`. Game over pauzu ignoruje;
  potvrzení a ESC zůstávají aktivní.

## Obraz a vazba na OS

- Zachovej Graphics 0 (ANTIC mode 2), 26×40 znaků, 24 viditelných řádků
  studny, tenké stěny, plný blok `$80` a NEXT ve spawn rotaci 0 v měřítku 1:1.
  Rozvržení řídí `WELL_COL`, `NEXT_COL`, `PAN_COL`, `HINT_COL`, `MSG_ROW`.
- P0/P1 podbarvují nápovědu/panel. P2 kreslí aktivní dílek v `ST_FALL` i
  `ST_PLAN`, P3 NEXT, oba v dvojnásobné šířce. `PieceCol` obsahuje barvy
  I/O/T/S/Z/J/L: `$9A,$EE,$48,$B8,$34,$76,$1A`. Usazené buňky jsou šedé.
  `UpdatePiecePM` připraví `PcBuf` při `BoardDirty`, `DrawNext` připraví `NxBuf`.
  Do PMG RAM kopíruje data až VBI; zachovej tuto opravu vykreslování.
  `GameDL` nepoužívá DLI; DLI dělá pouze duhu titulku/menu.
- `design/design3.asm` je reference rozvržení, `design/design4.asm` barevných
  kostek. `design/design.asm` (GTIA 10 + `font35.inc`) a `design/design2.asm`
  (mode 4 + PMG + `charset4.inc`) jsou dřívější prototypy.
  Hra tyto include soubory nepoužívá. Schválené rozvržení nevracej ke chunky
  písmu, texturovaným kostkám nebo zvětšenému NEXT bez požadavku uživatele.
- Hra používá `VVBLKI`, `VDSLST`, `XITVBV` a ROM font přes `CHBASE=$E0`.
  Není nezávislá na OS. Zachovej kontrakt přerušení: `Vbi` se vrací přes
  `XITVBV`, `Dli` obnovuje A/X/Y a končí `RTI`.
- Vstupy čti přes `PORTA`, `TRIG0`, `CONSOL`, `SKSTAT`/`KBCODE` a náhodu přes
  `RANDOM`. Harness neaktualizuje OS shadow registry vstupů.
- ZP zabírá `$80–$92`, program/data začínají na `$2000` a musí zůstat pod PMG
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
  Zvuk ve VBI používá výhradně vlastní ZP ukazatel `SndRead` a původní kanál
  ukládá na zásobník. Nikdy v něm nepoužívej pracovní `ptr/ptr2/tmp*` hlavního
  programu bez jejich úplného uchování; `SEI` před NMI nechrání.
