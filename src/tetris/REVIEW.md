# Kontrola a opravy Tetrisu – 11. 9. 2026

Aktuální práce je ve větvi `feature/tetris-current-review-fixes`: slučuje
`origin/main` na `199b92c` s dosavadními opravami z `ebe0654`.
Barevná hra, novější HELP a animované skóre jsou zachované. Zdrojový kód
je autorita; README, HANDOFF, AGENTS a SPEC popisují tento spojený stav.

## Příčina návratu ke starému vzhledu

Předchozí opravy začaly z lokální `main` na `92c29b3`, bez ověření jejího
vztahu ke vzdálené větvi. Po `git fetch origin` byla tato lokální větev
2 commity napřed (opravy Snake) a 17 commitů pozadu za `origin/main`.
Základem revize tedy byla stará šedá hra. Nešlo o ztrátu barev při merge:
strom Tetrisu v `199b92c` odpovídal poslední barevné větvi na `5bb129b`.

| Funkce zachovaná v historii | Původní commit |
|---|---|
| Oprava pádu HELP: samostatná pracovní ZP pro zvuk ve VBI | `418507b` |
| Barevný aktivní dílek a NEXT přes P2/P3 | `bd223f2` |
| Přenos dat P2/P3 do PMG RAM až během VBI | `043652f` |
| PAUSED bliká po 32 snímcích | `ab1fdac` |
| Syté barvy: prázdné textové buňky + plný jas PMG | `6b83d21` |
| Dvě stránky HELP, druhá s bodováním | `19a33e3` |
| Postupný nápočet bodů za řady | `a8b3c2b` |
| Postupný nápočet levelového bonusu | `fba79b7` |
| Levelové pípání 1 snímek tónu + 2 ticho | `853126f` |
| Samostatné prototypy a build v design/ | `5bb129b` |

Paleta `tools/DefaultPAL.pal` zůstala beze změny. `PieceCol` používá původní
hodnoty `$9A,$EE,$48,$B8,$34,$76,$1A`. Předchozí audit nesprávně prezentoval
pád HELP jako nový nález aktuální hry: novější historie už tuto chybu opravila.
Pokyny v AGENTS nyní vyžadují kontrolu větví a upstreamu před zahájením oprav.

## Opravy a řešení souběhu s novější hrou

| Oblast | Výsledné řešení | Ověření |
|---|---|---|
| VBI a pracovní paměť | Jediný soukromý ukazatel `SndRead`, kanál na zásobníku; odstraněna duplicita obou nezávislých oprav | Text během VBI, registry/ZP, 13 zvukových sekvencí, test_irq |
| Dlouhé plánování AI | `AiPlanStep` vyhodnotí nejvýše jednoho kandidáta, mezi kroky se čtou vstupy | Krátký ESC, nejvýše 48 kandidátů, obnova Board |
| Pauza dokončení levelu | Stojí odpočet i animovaný bonus, nepípá; game over pauzu ignoruje | 160 snímků pauzy a následné dokončení levelu |
| Optimalizace obrazu | `BoardDirty`/`ValuesDirty`, cache zpráv a banneru | Nezměněný RenderGame: 22 instrukcí, 0 zápisů do textové obrazovky |
| Barevné kostky + cache | Při změně plochy se obnoví také PcBuf; P2 viditelný ve ST_FALL i ST_PLAN | Všech 28 rotací, 7 barev, NEXT, lock a EXPERT |
| Blikání pauzy + cache | Klíč zprávy obsahuje bit `$20` pro PAUSED, `$10` pro DEMO/level | Přepínání PAUSED po 32 snímcích |
| Animované skóre + cache | ScoreTick běží každý aktivní krok blikání, ScoreLines invaliduje panel | Body rostou v přesných intervalech, správné počítadlo řad a konečná suma |
| Build | Hra přes make.bat, čtyři prototypy přes design/make.bat; oba končí po chybě | 5 testů, chyby každého z 5 překladů a cesty s mezerami |
| Přesah názvu obtížnosti z P0 | Jen herní panel používá ADV.; menu a HELP zachovávají ADVANCED | Screenshot ADVANCED: celý text uvnitř zeleného pruhu |

Zůstává sjednocené mazání položek menu, odstranění mrtvých dat a aserce
rozměrů/hranice paměti. Hledání AI na prázdné ploše má nejdelší krok
5 697 instrukcí; celkový objem hledání se podstatně nezmenšil.
XEX po úpravě názvu obtížnosti má 10 683 bajtů. Počty instrukcí nejsou měřením
cyklů na Atari; VBI dál obsluhuje PMG i při nezměněném textovém obrazu.

## Provedené ověření

- Sestavení hry a všech čtyř prototypů MADS.
- `test_game.py`: menu, obě stránky HELP, tři obtížnosti, řady, level,
  pauza, ESC, game over a demo; stavy i soulad textové studny s Board.
- `test_piece_pm.py`: P2/P3 data a registry, všech 7 barev a 28 rotací,
  centrování NEXT, pohyb, rotace, pád, lock, ST_PLAN a skrytí P3 v EXPERT.
- `test_ui.py`: 32snímkové blikání PAUSED, HELP a bodování, 24snímkový
  nápočet řad, 48snímkový bonus levelu a pípání každé tři snímky.
- `test_irq.py`: časté VBI při kreslení HELP, zachovaný text a návrat.
- `audit_tetris.py`: 10 976 hraničních kolizí, 120 mazání řad proti referenci,
  60 kombinací struktur/obtížností/levelů, 100 převodů a 80 animovaných
  bodových odměn včetně platnosti BCD po každém snímku; dále zvuky/VBI,
  paměť, AI, DEV a pauza. Výsledek `detected_issues: []`, kód 0.
- `test_build.py`: oba build skripty, úspěchy i selhání.
- Kontrola screenshotů hry a všech sedmi barev s původní DefaultPAL paletou,
  `git diff --check` a kontrola změn proti aktuálnímu origin/main.

Harness je částečný model CPU/grafiky, zvuk ověřuje zápisy POKEY.
Tato kontrola nezahrnuje poslech a časování na skutečném Atari nebo v Altirře.

## Opakování a návrat

Z adresáře Tetrisu:

```powershell
./make.bat
./design/make.bat
python tools/test_build.py
python tools/audit_tetris.py
cd tools
python test_game.py
python test_piece_pm.py
python test_ui.py
python test_irq.py
```

`feature/tetris-review-fixes` zůstává na `ebe0654` jako záloha před spojením.
Obsahuje starou šedou hru s opravami, nikoli poslední barevnou verzi.
Poslední barevná hra před touto revizí je v `199b92c` (také ve stromu
`5bb129b`). Pro samostatný návrat k ní lze s uloženými změnami vytvořit větev:

```powershell
git switch -c feature/tetris-colored-baseline 199b92c
./make.bat
```

Lokální main i předchozí feature větev zůstávají zachované. Ignorované XEX
a labely se při změně větve samy nevrátí: vždy znovu přeložit příslušný zdroj.
