# Kontrola a opravy Tetrisu – 11. 9. 2026

Opravy jsou ve větvi `feature/tetris-review-fixes`. Výchozí stav hry,
dokumentace a reprodukcí nálezů je uložen v commitu `61b7820`.
Všech pět hlavních nálezů je vyřešených; cílený audit nyní vrací prázdný
seznam `detected_issues` a návratový kód 0.

## Nálezy a jejich řešení

| Nález ve výchozím stavu | Provedená oprava | Ověření |
|---|---|---|
| P1: VBI přepsalo pracovní `ptr2/tmp4`; text skončil ve zvukové tabulce | `SoundTick` má vlastní ZP ukazatel `SndRead`; číslo kanálu ukládá na zásobník VBI | Přerušení zápisu textu, uchování registrů a pracovní ZP u všech 13 efektů, neměnnost kódu/tabulek při pěti časováních harnessu |
| P2: monolitické `AiPlan` přehlédlo krátký ESC | `AiPlan` jen zahájí hledání; `StPlan` volá `AiPlanStep` po jednom kandidátovi za krok, mezi kroky běží vstupy a čas | ESC držený tři snímky ukončí demo, každý krok obnoví Board, hledání všech sedmi typů skončí nejvýše po 48 krocích |
| P2: PAUSED nezastavilo dokončení levelu | `LevelDoneSeq` během pauzy nesnižuje odpočet; game over pauzu ignoruje | Level i odpočet během 160 snímků pauzy stojí, po obnovení přechod doběhne; game over stále přijímá START/ESC |
| P2: `test_game.py` neměl aserce výsledků | Přidané kontroly stavů, vykreslené studny, obtížností, pauzy a návratů; rozšířený audit | Herní scénář končí `ALL OK`, audit kódem 0; čitelnost a rozvržení ověřeny také na PNG |
| P2: `make.bat` pokračoval po chybě | Zastavení s kódem 1 po každém neúspěšném překladu, varianta `game`, práce ve vlastním adresáři | Test chyby na každém ze čtyř překladů, úspěšný úplný build a varianta `game`, cesty s mezerami |

## Zjednodušení a výkon

- `BoardDirty` a `ValuesDirty` dovolují přeskočit nezměněnou studnu/panel.
  Zpráva a DEMO banner mají cache obsahu a fáze blikání. Vynucení při vstupu
  do hry i změny po pohybu, rotaci, pádu, mazání a novém levelu jsou zachované.
- Čtyři mazací rutiny menu nahradila `ClearMenuItem` s tabulkou adres.
- Odstraněny nepoužívané `RowBuf`, `DliCnt` a `TxtH3`. `GROWS` se používá
  v display listu, `MSG_DEMO` jako klíč cache zprávy.
- Pole a odpovídající smyčky používají `BOARD_SIZE`; MADS aserce hlídají
  10×24 a osmibitový index. Tabulky a rozvržení nadále výslovně odpovídají
  těmto rozměrům. Aserce chrání také hranici kódu před PMG oblastí.
- Opravené zastaralé komentáře a kontaktový list screenshotů: výška každé
  buňky nyní vychází z nejvyššího obrázku, takže spodní části hry nejsou oříznuté.

| Měření v harnessu | Před opravou | Po opravě |
|---|---:|---:|
| Instrukce nezměněného `RenderGame` | 3 228 | 22 |
| Zápisy nezměněného `RenderGame` do obrazovky | 62 | 0 |
| Nejdelší souvislé plánování na prázdné ploše (ze sedmi typů) | 190 618 instrukcí | nejvýše 5 697 instrukcí v jednom kroku |
| Velikost sestaveného XEX | 9 287 B | 9 471 B |

Počet instrukcí není měření cyklů nebo času na skutečném Atari. Celkový
objem hledání AI zůstává podobný; změnou je jeho rozdělení. Během hledání
zůstává dílek ve spawn poloze a běží čas, pak přejde do pádu s obvyklým
čítačem přemýšlení 14. U složitějších kusů může hledání trvat 48 herních kroků.

## Rozsah úspěšného ověření

- Překlad hry i všech tří prototypů přes `make.bat`.
- 10 976 hraničních kombinací typu/rotace/pozice proti kolizi s okrajem.
- 120 náhodných ploch s 1–4 plnými řádky proti referenčnímu mazání.
- 60 kombinací obtížnosti/levelu proti tabulkám startovních struktur.
- 100 číselných převodů a 80 kombinací bodování řad.
- Všech 13 úplných POKEY sekvencí: AUDF/AUDC, délky, ukončení, uchování
  registrů, decimal flagu a pracovní ZP při VBI.
- Hledání všech typů AI po krocích s vykreslováním mezi nimi, obnova Board
  po každém kandidátovi a omezení počtu instrukcí kroku.
- Krátký ESC při hledání, zastavení a obnovení dokončení levelu, OPTION
  při bootu, hranice DEV levelů, N/G a jejich neúčinnost v běžném režimu.
- Průchod menu, HELP, EASY, ADVANCED, EXPERT, pauzou, dokončením levelu,
  game over a demem s kontrolou stavů a obsahu vykreslené studny.
- Čtyři testy řízení buildu; jeden obsahuje čtyři podscénáře chyb překladače.
- Kontrola vykresleného přehledu obrazovek a `git diff --check`.

Harness je částečný model hardwaru. Poslech skutečného POKEY, plný OS
a chování na fyzickém Atari či NTSC zůstávají mimo rozsah tohoto ověření.
Úspěšné kontroly nevylučují chybu v jiném netestovaném stavu.

## Opakování kontrol

Z `src/tetris` v PowerShellu, po úspěšném buildu:

```powershell
./make.bat
python tools/test_build.py
python tools/audit_tetris.py
cd tools
python test_game.py
```

Pythonové herní kontroly samy nesestavují XEX ani labely. Úspěšný audit
vrací 0 a prázdné `detected_issues`; při nálezu vrací 1. Herní průchod vypíše
`ALL OK`. Potřebné závislosti jsou Python 3 a Pillow.

## Návrat k výchozímu stavu

`main` zůstává na původní historii. Commit `61b7820` ve feature větvi
obsahuje hru před opravami a k ní dokumentaci i reprodukce původních chyb.
Pro další pokus z tohoto bodu lze vytvořit novou větev:

```powershell
git switch -c feature/tetris-before-review 61b7820
./make.bat
```

Přepínat s uloženými změnami. XEX a labely jsou ignorované výstupy, takže
se při změně větve samy nevrátí: po přepnutí je nutné znovu sestavit příslušný
zdroj. Původní reprodukce v `61b7820` záměrně hlásí tehdejší vady.
