# snake – pokyny pro práci v tomto adresáři

Kontext a mechaniky hry jsou v `README.md`; architektura kódu v hlavičce `snake.asm`.

## Pravidla

- **Build:** `make.bat` (`mads snake.asm -o:snake.xex -t:snake.lab`). `*.xex` a `*.lab`
  se necommitují (`.gitignore`).
- **Glyfy hada** (`snake_font.inc`) NEeditovat ručně – jsou generované z `gen_font.py`
  (vzor jednoho glyfu, rotace/zrcadlení). Změna vzhledu = úprava vzoru + `python gen_font.py`.
- **Po každé změně spusť `python test_snake.py`** – jediný způsob ověření, žádný GUI
  emulátor na tomto stroji nejede (viz `../tetris/HANDOFF.md`). Test musí končit `ALL OK`.
  Nové mechaniky pokryj v testu.
- **Bez OS.** Hra si vlastní display list, VBI (`Vbi` → `XITVBV`) a čte hardware přímo
  (`PORTA`, `TRIG0`, `SKSTAT`/`KBCODE`, `RANDOM`). Nepoužívej OS shadow registry
  (`STICK0`, `CH`, `SAVMSC`, `RTCLOK`) – harness je neemuluje.
- **Texty v `.byte "..."` (dvojité uvozovky) = interní kódy** obrazovky, které se
  zapisují přímo do videopaměti. Apostrofy (`'...'`) dávají ATASCII a na obrazovce
  vyjdou špatně; prefix `c` u dvojitých uvozovek konverzi ruší. Konec textu `$FF`.
  Číslice: interní kód `'0'` je `$10`.
- **Konvence zápisu** stejné jako `../tetris/tetris.asm`: malá písmena mnemonik,
  labely bez dvojtečky, lokální labely `Prefix_x`, konstanty velkými písmeny,
  komentáře bez diakritiky (ASCII), dokumentace s diakritikou.
- Parametry rutin předávej přes ZP (`TmpX`, `TmpY`, `TxtPtr`) a registry, **nikdy
  inline daty za `JSR`** (to byla příčina původního BOOT ERROR).
