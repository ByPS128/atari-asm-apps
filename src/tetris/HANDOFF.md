# Tetris pro Atari XL/XE – handoff (stav k 9. 9. 2026)

> **Stav:** body 2, 3 a 5 jsou implementovány v `tetris.asm` (commit na `feature/tetris`).
> Obtížnosti: EASY (prázdná studna, NEXT), ADVANCED (struktury, NEXT), EXPERT (struktury, bez NEXT).
> Barvy PMG jsou konstanty `COL_*` na začátku `tetris.asm` a čekají na doladění uživatelem.
> HELP obrazovka z menu, P = pauza, ESC = opustit hru. Test: `tools/test_game.py`.
> Dev režim: OPTION při startu (`DevMode`), level 1–20 v menu, klávesy N (další level) a G (game over).

Tento dokument je soběstačná předávka: kdo ho zvedne, nemusí znovu procházet konverzaci ani
zdrojáky. Popisuje, k čemu jsme doiterovali v designu a herních pravidlech, co už existuje,
co se přepisuje, a jak se to ověřuje.

## 1. Kontext a záměr

Hra `src/tetris/tetris.asm` (MADS, 6502) je funkční Tetris s menu, demem (AI), zvuky a
klasickými pravidly. Původní herní obrazovka (GTIA mode 10, 9 barev, chunky písmo) byla
esteticky odmítnuta. Po třech prototypech (`design.asm` GTIA, `design2.asm` ANTIC mode 4 +
PMG, `design3.asm` Graphics 0) je **schválený směr = `design3.asm`**: Graphics 0 (ANTIC
mode 2, systémová znaková sada), plné bloky, studna z tenkých čar, barvy přes PMG a DLI.

Cílový stav: přenést layout z `design3.asm` do `tetris.asm`, přidat nový model levelů
(cíl v řádcích + startovní struktury), zachovat menu, demo, zvuky a herní jádro.

## 2. Schválený design herní obrazovky (`design3.asm` = vzor k okopírování)

- **Režim**: vlastní display list, `$70` (8 prázdných linek) + **26 řádků** ANTIC mode 2
  (208 scanlinů). Obrazovka `SCREEN = $6000` (26×40 = 1040 B). Řádek 0 začíná na scanline 16.
- **Znaková sada**: ROM (`CHBASE = $E0`). Kostka = **inverzní mezera `$80`** (plný blok 8×8),
  všechny tvary stejným znakem (barvu dává řádek, viz PMG).
- **Studna**: sloupce 14 a 25 = svislá čára `$7C`, buňky sloupce 15..24 (`WELL_COL = 15`),
  řádky 0..23 (**24 buněk vysoká**, `WELL_H = 24`), dno na řádku 24 = vodorovná čára `$52`
  s rohy `$5A` (└) a `$43` (┘).
- **NEXT**: nápis na řádku 0 sloupec 32; rámeček **6×6 znaků** (sloupce 31..36, řádky 1..6)
  z `$51 ┌ $45 ┐ $5A └ $43 ┘ $52 ─ $7C │`, vnitřek 4×4; dílek vycentrovaný, **ve spawn
  rotaci** (dnes rotace 0; až přibude obtížnost s orotovaným spawnem, NEXT ukáže tu rotaci).
- **Pravý panel** (sloupec 29 popisek, 30 hodnota): LEVEL ř. 9/10, SCORE 12/13, LINES 15/16,
  ROWS 18/19 (řady v aktuálním levelu, formát `03/11`), TIME 21/22 (mm:ss z 50 Hz čítače).
- **Levá nápověda** (sloupec 1 akce, 3 ovládání): MOVE/STICK ř. 2/3, ROTATE/FIRE 5/6,
  DROP/DOWN 8/9, HARD/SPACE 11/12, PAUSE/START 14/15, MENU/ESC 17/18, skill (BASIC/ADVANCED)
  ř. 22. Řádek 25 je volný pro hlášky (pauza, demo, game over, level complete).
- **Barvy** (`COLPF2 = $00`, `COLPF1 = $0C`, `COLBK = $00`): PMG single-line, `PMBASE = $50`,
  `DMACTL = $3E`, `GRACTL = 3`, `PRIOR = 1` (hráči nad playfieldem). Trik: v hi-res textu
  dostane rozsvícený pixel odstín hráče + jas PF1, pozadí pruhu = barva hráče (lum 0, což na
  Atari není čistá černá → panely jsou tmavě tónované; přijato jako vlastnost).
  - P0 quad (`SIZE 3`), HPOS `48+4*1`, sloupce 1..8, řádky 2..22, barva `$90` – nápověda.
  - P1 quad, HPOS `48+4*29`, sloupce 29..36, řádky 8..23, barva `$20` – panel.
  - **P2 double (`SIZE 1`) = aktivní kostka, P3 double = kostka v NEXT** (od 10.9.2026,
    vzor `design4.asm`; nahradilo podbarvenou studnu). 1 bit hráče = půl znaku, 8 bitů =
    4 buňky (`CellMask` $C0/$30/$0C/$03 pro dx 0..3). `UpdatePiecePM` (každý snímek
    z `RenderGame`) připraví `PcBuf` (32 scanlinů) podle `PieceTab`, `PcRow = 16+8*CurY`
    ($FF mimo `ST_FALL`), `PcHpos = 48+4*(WELL_COL+CurX)`, `PcCol = PieceCol[CurType]`.
    `DrawNext` totéž do `NxBuf` (`NxHpos`/`NxCol`; EXPERT → `NxHpos = 0`).
    **Do paměti hráčů zapisuje výhradně VBI** (smaže `PcPrevRow`, zkopíruje `PcBuf` na
    `PcRow`, `NxBuf` na pevné řádky NEXT, nastaví HPOS/barvy) – když to dělal hlavní kód,
    paprsek uprostřed přepisu ukázal spodek kostky šedě, vždy ve výšce NEXT (Altirra).
    Barvy `PieceCol` (I O T S Z J L) = $90 $E0 $60 $B0 $30 $70 $10; jas dává COLPF1,
    takže jsou pastelové a sytě červená není možná. Stěny studny jsou v barvě textu.
    Test: `tools/test_piece_pm.py`.
  - NEXT rámeček zůstává šedý (hráči došly; volitelně střely/missiles).
- Odmítnuto (neopakovat): GTIA mode 10 plocha, chunky písmo 3×5, mode 4 s 4px fontem,
  textury kostek z grafických symbolů, zvětšený NEXT, modré pozadí, bílé stěny, obří číslo
  levelu, horní/dolní textové lišty.

## 3. Schválená herní mechanika levelů (nahrazuje „level končí vyprázdněním plochy")

- Level určuje **rychlost** (`SpeedTab`, 40 → 2 snímků/řádek) a **cíl řádků**, rostoucí
  podlineárně: `5,7,9,11,12,13,14,15,16,17,18,18,…` strop 20. Zobrazení `ROWS x/y`.
- Po splnění: fanfára, bonus 1000×level, plocha se vyčistí, další level.
- **Startovní struktury** („fragmenty cihel") jen v obtížnosti **ADVANCED** (přejmenovaný
  EXPERT; navíc skrývá NEXT? – rozhodnout: doporučení = ADVANCED skrývá NEXT **ne**, jen
  struktury; ponechat skrytí NEXT jako samostatnou volbu později). BASIC vždy prázdná plocha.
- Vzory: tabulka řádků odspodu, 10 znaků (`#` cihla, `.` prázdno), zrcadlově symetrické,
  žádná plná řada, díry dosažitelné. Progrese podle Tetris Pro (Amiga): level 1 skoro prázdný,
  2–3 schůdky u krajů, 4–5 bloky s dírou uprostřed + první převis (plovoucí cihly), 6–8 věže a
  vyšší převisy, 9–12 husté zaplnění se skulinami; od 13 se vzory opakují s přidanou vrstvou.
  Level 2 podle screenshotu originálu:
  ```
  #........#
  #........#
  ##......##
  ###....###
  ```
- Studna **24 řádků herních** (BH = 24, zkusit; fallback 20 + 4 skryté).
- Amiga ADF `Tetris Pro (1993)(Logic Systems).adf` je zabalený, nečitelný; vzory navrhujeme
  vlastní (rozhodnuto).

## 4. Co existuje a přebírá se beze změny

`tetris.asm` (funkční, ověřená): vstupy (`ReadInputs`, joystick + klávesy + CONSOL), stavový
automat (`StSpawn/StFall/StClear`), kolize a rotace s kicky (`Fits`, `TryRotate`, `KickTab`),
DAS, soft/hard drop, `FindFull/RemoveFullRows`, BCD skóre, zvukový sekvencer (`SoundTick`,
`Sd*` tabulky), AI dema (`AiPlan/Evaluate/AiStep`), menu a titulní obrazovka (mode 7 duha),
`FrameStep` s přerušením dema a pauzou. Testovací harness `tools/emu.py` (nyní umí mode 2/4/6/7/F,
DLI s WSYNC, PMG včetně hi-res triku a barev po řádcích) + `test_*.py`.

## 5. Co se přepisuje v `tetris.asm`

1. Herní display list → 26 řádků mode 2 s DLI na každém řádku; `SetGameScreen` kreslí studnu,
   NEXT rámeček, panel, nápovědu (zkopírovat `DrawMockup`/`NextBox` z `design3.asm`).
2. `Board`/`Comp` na 10×24 (`BH = 24`, `RowOff10` 24 položek, `RowPtr` = adresy řádků
   obrazovky), `DrawBoard` = zápis `$80`/`0` do znaků (žádná bitmapa), `PrevComp` porovnání
   zůstává.
3. `DrawNext` → 4×4 znaků uvnitř rámečku, spawn rotace, vycentrování; ADVANCED bez NEXT jen
   pokud zůstane ta volba.
4. Panel: `DrawValues` na nové pozice, přidat `RowsInLevel`, `RowsTarget`, `TimeSec`
   (BCD mm:ss, tik z `FrameCnt` po 50).
5. Hlášky na řádek 25 (`DrawMessage`), DEMO: velký nápis vlevo zrušit; místo něj blikající
   inverzní „DEMO" v levém sloupci nad nápovědou + hláška dole.
6. Level: `LevelDoneSeq` po dosažení cíle (ne po vyprázdnění), `FillGarbage` → `FillPattern`
   z tabulky vzorů jen v ADVANCED; `GarbTab` zrušit.
7. VBI/DLI: PMG init a barvy podle bodu 2 (studna gradient), `DliMode` 1 = hra (řádkový),
   0 = titulní duha. Blikání mazaných řad = inverze/`$80`↔ jiný znak nebo změna `COLPM2/3`.
8. Menu: EXPERT → ADVANCED, texty nápovědy.

## 6. Pasti

- MADS: `<label+7` = `(<label)+7` → vždy `<(výraz)`; labely jsou case-insensitive (`ColBk` vs
  `COLBK` kolize); `:n` opakuje instrukci/direktivu; makro parametry `:1`.
- DLI/VBI zdědí decimal flag → `cld` na začátku obou. `SED` jen krátce v BCD rutinách.
- Blokující sekvence nesmí používat `tmp*`/`celly` přes volání `RenderGame` (viz `SeqCnt/SeqRow`).
- V GTIA 10 je okraj = COLPM0 (netýká se nového designu, ale harness to nemodeluje).
- Řádek 25 (26. řádek) končí na scanline 224 – na NTSC může být oříznut; na PAL OK.
- `atari800.exe` na H: na tomto Windows nejede (DirectDraw); uživatel testuje v Altirře 4.21
  (`C:\_ByPS\Atari\Altirra\Altirra-4.21`), my v `tools/emu.py` (render do PNG, `Machine(xex=...)`).
- **Kód volaný z VBI/DLI nesmí sdílet ZP proměnné (`ptr`, `ptr2`, `tmp*`) s hlavním kódem.**
  `SoundTick` je původně sdílel; když SFX hrál během kreslení HELP, VBI přepsal `ptr2`
  uprostřed `PutStr`, text se zapsal mimo a Altirra spadla (BRK → SELF TEST). Zvuk má teď
  vlastní `sptr`/`stmp`. Harness pouští VBI jen po 10 000 instrukcích, takže to neviděl;
  `tools/test_irq.py` běží s VBI každých 400 instrukcí a chybu chytá.

## 7. Ověření

```
cd src/tetris && make.bat                 # tetris.xex, design*.xex
cd tools && python test_game.py
python -c "from emu import Machine; m=Machine(); m.run(120); m.screenshot('out.png')"
```
Po přepisu: aktualizovat testy na `BH=24`, `Board` 240 B, nové pozice textů (`text_rows(0x6000, 26)`).

## 8. První krok pro toho, kdo to zvedne

Vzít `design3.asm` jako referenci layoutu a v `tetris.asm` nahradit sekci „VYKRESLOVANI HERNI
OBRAZOVKY" + display list + VBI/DLI; teprve pak levely a ADVANCED. Průběžně renderovat
harnessem a porovnávat s `tools/out_design3.png`.

## 9. Odkazy

- PR původní verze: https://github.com/ByPS128/atari-asm-apps/pull/1 (větev `feature/tetris`)
- Prototypy: `design.asm` (GTIA), `design2.asm` + `charset4.inc` (mode 4), `design3.asm` (schváleno)
