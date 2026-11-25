# atari-asm-apps – společné pokyny

Hry a ukázky pro Atari 800XL v assembleru MADS. Tyto pokyny platí pro celé repo; pokyny jednotlivých her jsou
v jejich adresářích (`src/snake`, `src/tetris`) a v tom, co popisují, mají přednost.

## Ověřování

- **Automaticky:** headless harness `src/tetris/tools/emu.py` (obraz do PNG, log zápisů do POKEY); testy a postup
  jsou v `src/tetris/AGENTS.md`. Harness nahrazuje jen část chování OS (přerušení), editor OS ani shadow registry
  neemuluje, takže programy stojící na OS (`src/basics`: `PUTLIN`, `RTCLOK`) ověříš jen v plném emulátoru.
- **Přechodné grafické chyby** (viditelné jen do dalšího kroku) testuj v harnessu deterministicky hned po události,
  ne až po `run(10)`.
- **Plný emulátor je Altirra** (na tomto stroji v `C:\_ByPS\Atari\Altirra\`, verze v názvu podadresáře; když tam
  není, zeptej se). `atari800` z disku H: tu kvůli DirectDraw nejede (zjištěno 9/2026). Spuštění z PowerShellu:
  `Get-Process Altirra* -EA SilentlyContinue | Stop-Process -Force`, pak
  `Start-Process "<Altirra64.exe>" -ArgumentList '"<cesta>.xex"'` a pár sekund počkat. Ovládat ani slyšet ji
  neumíš, okno ale vyfotíš snímkem obrazovky (PowerShell, `System.Drawing`, `Graphics.CopyFromScreen`); poloha okna
  se mění, najdi ho na celém snímku, pak ořízni a zvětši.
- **Zvuk posuzuje uživatel poslechem v Altirře.** Před laděním zvuku se zeptej, jak zní; po změně zvuku nebo
  animace vedle testu nabídni spuštění v Altirře.
