# Kontrola Tetrisu podle zdroje – 11. 9. 2026

Herní jádro má dobrý základ: oddělené usazené buňky a vykreslovaný obraz,
přehledné stavy spawn/pád/mazání, tabulky levelů a rozumně malé datové struktury.
Obraz je čitelný a sestavená hra má přibližně 9 KB. Kontrola však našla
jednu závažnou chybu paměti, dva problémy odezvy/chování a slabiny ověřování.

Kontrolován současný `tetris.asm`, přeložený příkazem
`mads tetris.asm -o:tetris.xex -t:tetris.lab`. Zdroj hry nebyl při auditu změněn.
Výsledky níže pocházejí ze statického čtení a z provedení sestavených rutin
v místním harnessu; nejsou potvrzením na skutečném Atari ani v plném emulátoru.

## 1. P1: VBI přepisuje ukazatel a dočasnou proměnnou hlavního programu

**Místo:** `SoundTick` / `ST_load` kolem řádku 2837, volání z `Vbi`;
uživatelé stejných proměnných například `PutStr` (3006), `PutDec2` (2638),
`DrawNext`, `FillPattern`, `TryRotate` a `RemoveFullRows`.

Zvukový sekvencer používá `ptr2`, `ptr2+1` a `tmp4`. Hlavní program v nich
má rozpracovaný cíl textu, data struktury nebo čítač. VBI tyto tři bajty
neukládá ani neobnovuje. Zachování A/X/Y přes OS nechrání obsah RAM.

**Ověření:** připravit efekt MOVE, `ptr=TxtLevel`, `ptr2=$6000`, `tmp4=$7B`
a přerušit vstup do `PutStr` pomocí skutečné rutiny VBI.

| Výsledek | Bez přerušení | S přerušením |
|---|---|---|
| `$6000–$6004` | screen kódy `LEVEL` | zůstávají nuly |
| Prvních pět bajtů `SdMove` | `$40,$A4,$02,$00,$00` | `$2C,$25,$36,$25,$2C` = `LEVEL` |
| `tmp4` | `$7B` | `$00` |

Tedy nejde jen o chybně zobrazený znak: hlavní kód zapisuje do tabulky zvuku.
Změní také délky tónů a ukončení sekvence. U dalších uživatelů `tmp4` hrozí
chybný počet iterací. Tyto další důsledky jsou odvozené z použití proměnné;
přepsání zvukových dat bylo přímo reprodukováno.

Druhý scénář nepotřebuje ručně vložené VBI: při rozpočtu harnessu 8000
instrukcí/snímek projde úvodem, zvolí ADVANCED/level 4 a provede několik
hard dropů. Změní pět bajtů `SdSelect` na `$42C7–$42CB` (adresy tohoto buildu).
S výchozími 10000 instrukcemi stejný scénář data nepoškodil. Změna rozpočtu
testuje jinou fázi přerušení, nikoli přesné časování reálného procesoru.

**Oprava:** vyhradit zvuku vlastní ZP ukazatel a vlastní dočasnou proměnnou,
nebo tyto tři bajty na vstupu VBI uložit a před návratem obnovit. Oddělené
proměnné dávají jasnější kontrakt. `SEI` tuto chybu neřeší, protože VBI je NMI.
Opravit před optimalizacemi a znovu ověřit přerušení u všech uživatelů těchto ZP.

## 2. P2: plánování dema blokuje čtení vstupů a herní krok

**Místo:** `AiPlan` (1898), `AP_drop` (1915), `Evaluate` (1973),
volání z `StSpawn`. Čtení skutečného vstupu je až ve `FrameStep` (1231).

AI v jednom souvislém volání vyhodnotí všechny rotace a polohy, pro každou
opakuje pád po buňkách a průchod celou studnou. Během toho nečte ovládání
a neprovádí běžný herní krok ani jeho časovač.

Na prázdné studni bylo naměřeno:

| Kus | Provedené instrukce v `AiPlan` |
|---|---:|
| I | 94 186 |
| O | 51 197 |
| T | 190 217 |
| S | 95 959 |
| Z | 95 955 |
| J | 190 618 |
| L | 190 576 |

U J to odpovídá zhruba 19 rozpočtům výchozího harnessu po 10000 instrukcích;
není to měření cyklů ani času na skutečném Atari. K plánování se přidává
ještě explicitní čítač přemýšlení AI.

**Ověření dopadu:** při plánování T podržet ESC tři snímky a uvolnit.
Po dokončení výpočtu `AbortFlag=0`, `Demo=1`, display list zůstává herní `$7000`.
Následné delší držení ESC vrátí menu `$7100`. Krátký vstup se úplně ztratí.

**Oprava:** rozdělit hledání do několika kandidátů za herní krok, průběžně
obsluhovat vstupy a uchovat stav hledání. Hypotetický kus musí být před
přerušením hledání odstraněn z `Board`. Samotná mikrooptimalizace výpočtu
neřeší ztrátu vstupu při delším plánování tak spolehlivě.

## 3. P2: pauza nezastaví dokončení levelu

**Místo:** `LevelDoneSeq` / `LDS_l` (1828); obdobná struktura `GameOverSeq` (1847).

`FrameStep` přepne `Paused`, ale sekvence pokračuje v odpočtu bez jeho kontroly.
Uživatel vidí PAUSED, zatímco se v pozadí dokončí level, vymaže studna a načte další.

**Ověření:** během fanfáry stisk P. Před čekáním bylo `Level=1`, `Paused=1`,
`SeqCnt=140`; po dalších 160 snímcích `Level=2`, `Paused=1`, `SeqCnt=0`.
V běžném pádu/mazání řad pauza stavy zastavuje, takže se chová nekonzistentně.
`SPEC.md` už toto současné chování výslovně popisuje; změna vyžaduje aktualizaci zadání.

**Návrh:** reprezentovat dokončení levelu a game over jako další stavy hlavní
smyčky. Jedno místo pak rozhoduje o pauze, ESC a časovačích. Menší zásah je
zastavit odpočet sekvence při pauze; u game over je vhodné jasně určit,
zda vůbec má přijímat pauzu, nebo jen návrat do menu.

## 4. P2: původní test hry nehlídá správnost výsledků

**Místo:** `tools/test_game.py`, model snímku v `tools/emu.py`.

Test vypisuje hodnoty a ukládá PNG, ale neobsahuje aserce pravidel hry.
Může doběhnout s nesprávným skóre, levelem nebo poškozenými daty.
Pevný rozpočet instrukcí navíc opakuje stejné fáze přerušení; chyba z bodu 1
se při jednom rozpočtu projeví a při jiném zůstane skrytá.

**Návrh:** doplnit aserce klíčových stavů, invariant neměnnosti kódu/tabulek,
řízené přerušení uvnitř rutin a více rozpočtů/fází VBI. Obrazové kontroly
zachovat. Přiložený audit část těchto kontrol zavádí, nenahrazuje celou sadu
přejímacích scénářů ze `SPEC.md` ani ověření zvuku a hardwaru.

## 5. P2: build může zakrýt neúspěšný překlad hry

**Místo:** všechny čtyři příkazy v `make.bat`.

Po chybě překladu hry se bez kontroly návratového kódu sestavují prototypy.
Úspěšný poslední příkaz může zakrýt původní chybu; pokud zůstane starý XEX,
uživatel či testovací skript může ověřovat jinou verzi, než právě upravil.
Tento nález vychází z řízení skriptu; aktuální přímý překlad hry prošel.

**Oprava:** po každém překladu ukončit skript při chybě. Hru sestavovat
s labely společně a spouštět testy jen po úspěšném buildu. Samostatný přepínač
pro prototypy může zjednodušit běžný vývojový cyklus.

## Zjednodušení a výkon po opravách

- `RenderGame` při nezměněném obrazu spotřeboval 3228 instrukcí a provedl
  62 zápisů do obrazovky: 22 číslic/oddělovačů panelu a 40 nul zprávového řádku.
  Nejprve stačí přepisovat hodnoty jen po změně a zprávu při změně stavu/fáze
  blikání. Stávající `NextDirty` už podobný princip používá. `DrawBoard` má
  užitečné porovnávání změněných řádků; bez měření bych ho nepřepisoval.
- `RowBuf` (10 B) nemá použití, `DliCnt` se pouze nuluje, `TxtH3` není nikde
  vykreslený. `GROWS` a `MSG_DEMO` jsou nepoužité konstanty. Úklid ušetří
  desítky bajtů a hlavně odstraní matoucí pozůstatky; nepřinese zásadní zrychlení.
- Čtyři `ClearItem0`–`ClearItem3` dělají totéž s jinou adresou. Jedna rutina
  s cílovým ukazatelem či tabulkou adres omezí duplicitu.
- Rozměry mají pojmenované `BW/BH`, ale pole a řada smyček zároveň používají
  pevně 240/239/24. Vyjádřit odpovídající délky přes konstanty a přidat
  kontrolu při překladu, že index plochy stále vyhovuje osmibitové adresaci.
- Hlavička zdroje stále jmenuje BASIC/EXPERT, neexistující `PatternTab`
  a libovolnou klávesu. Jde o komentáře; skutečnou implementaci už popisují
  aktualizované dokumenty. Při opravách sjednotit i tyto komentáře.

## Co prošlo cíleným ověřením

- 10 976 kombinací typu/rotace/pozice pro kolize s okraji na prázdné studni,
  včetně záporných počátků, když skutečné buňky leží uvnitř.
- 120 náhodných ploch s různými kombinacemi 1–4 mazaných řad proti jednoduchému
  referenčnímu posunu řádků.
- 60 kombinací obtížnosti a levelu proti datům startovních struktur.
- 100 převodů čísel 0–99 a 80 kombinací skóre za řady (20 levelů × 4 počty).
- Plánování všech sedmi typů na prázdné ploše po návratu obnovilo původní Board.

Tyto výsledky platí pro uvedené scénáře; nevylučují chybu při jiném stavu
nebo přerušení. Běžný vizuální průchod hrou byl ověřen při předchozí kontrole
dokumentace. Zvuk na skutečném POKEY ani úplný OS audit zde proveden nebyl.

## Opakování auditu

Po úspěšném překladu z `src/tetris`:

```powershell
mads tetris.asm -o:tetris.xex -t:tetris.lab
python tools/audit_tetris.py
```

Audit vyžaduje stejné prostředí jako harness (Python 3 + Pillow).
Vypíše JSON s důkazy a seznamem `detected_issues`; při nálezu vrátí kód 1.
Na kontrolované verzi hlásí přepis proměnných ve VBI, poškození dat při
běžném scénáři, přehlédnutí ESC v demu a přechod levelu během pauzy.
První dvě hlášení mají společnou příčinu popsanou v bodu 1.

Doporučené pořadí práce: uchování stavu přes VBI a jeho regresní kontroly,
spolehlivý build, průběžné plánování AI, sjednocení pauzy, potom drobný úklid
a optimalizace vykreslování.
