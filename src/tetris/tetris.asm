; =====================================================================
;  TETRIS pro Atari XL/XE (6502, MADS assembler)
;
;  - Uvodni obrazovka + menu (start, volba levelu, obtiznost BASIC/EXPERT)
;  - Po ~15 s necinnosti v menu se spusti DEMO (AI simuluje prumerneho
;    hrace); jakykoliv vstup (joystick, klavesa, START/SELECT/OPTION)
;    demo ukonci a vrati se do menu.
;  - Herni obrazovka: Graphics 0 (ANTIC mode 2) s vlastnim display listem
;    26 radku, studna 10x24 z tenkych car, kostky = plny blok, panel vpravo
;    (NEXT, LEVEL, SCORE, LINES, ROWS, TIME), napoveda vlevo. Barvy pres
;    PMG "filtr" nad textem (konstanty COL_* nize) - viz HANDOFF.md.
;  - Level = rychlost + cil v radcich (ROWS x/y). ADVANCED a EXPERT zacinaji
;    kazdy level se startovnimi strukturami cihel (PatternTab), EXPERT navic
;    neukazuje NEXT. EASY = prazdna plocha, NEXT viditelny.
;  - Zvuky: pohyb, rotace, drop, mazani rad, fanfara, game over.
;
;  Ovladani: joystick / sipky = pohyb, FIRE / sipka nahoru / Z = rotace,
;            dolu = soft drop, MEZERNIK = hard drop, ESC = opustit hru,
;            P nebo START = pauza. V menu: SELECT = level, OPTION = skill.
;
;  Build:  mads tetris.asm -o:tetris.xex   (viz make.bat)
; =====================================================================

; ---------------------------------------------------------------------
;  Hardware / OS
; ---------------------------------------------------------------------
DMACTL   = $D400
DLISTL   = $D402
DLISTH   = $D403
CHBASE   = $D409
WSYNC    = $D40A
NMIEN    = $D40E
VDSLST   = $0200
VVBLKI   = $0222
XITVBV   = $E462

TRIG0    = $D010
HPOSP0   = $D000
SIZEP0   = $D008
PMBASE   = $D407
COLPM0   = $D012           ; $D012-$D015 COLPM0-3, $D016-$D019 COLPF0-3
COLPF0   = $D016
COLPF1   = $D017
COLPF2   = $D018
COLPF3   = $D019
COLBK    = $D01A
PRIOR    = $D01B
GRACTL   = $D01D
CONSOL   = $D01F

PORTA    = $D300
AUDF1    = $D200
AUDC1    = $D201
AUDCTL   = $D208
KBCODE   = $D209
RANDOM   = $D20A
SKSTAT   = $D20F
SKCTL    = $D20F

; ---------------------------------------------------------------------
;  Barvy - ladi se zde (PMG "filtr": pozadi pruhu = barva s jasem 0,
;  rozsvicene pixely textu dostanou odstin + jas COL_TEXT)
; ---------------------------------------------------------------------
COL_HINT   = $B0           ; podbarveni napovedy vlevo (player 0)
COL_PANEL  = $20           ; podbarveni panelu vpravo (player 1)
; barvy kostek - player 2 = aktivni kostka, player 3 = NEXT (vzor design4.asm):
; I tyrkysova, O zluta, T fialova, S zelena, Z cervena, J modra, L oranzova (Tetris Guideline).
; Bunky aktivni kostky a NEXT jsou ve videopameti PRAZDNE, barvu i jas dava jen hrac -> syte barvy.
COL_TEXT   = $0C           ; jas textu a kostek (COLPF1)
COL_BG     = $00           ; pozadi obrazovky (COLPF2, COLBK)

; ---------------------------------------------------------------------
;  Pamet obrazovek
; ---------------------------------------------------------------------
GAMESCR    = $6000         ; herni obrazovka 26 x 40 (mode 2), i HELP
GROWS      = 26
PMAREA     = $5000         ; PMG single-line: P0 $5400, P1 $5500, P2 $5600, P3 $5700

MENUSCR    = $6A00
MENU_TITLE = MENUSCR       ; mode 7 (20 B)
MENU_SUB   = MENUSCR+$20   ; mode 6 (20 B)
MENU_IT0   = MENUSCR+$40   ; mode 6 polozky menu
MENU_IT1   = MENUSCR+$60
MENU_IT2   = MENUSCR+$80
MENU_IT3   = MENUSCR+$A0
MENU_H0    = MENUSCR+$100  ; mode 2 (40 B) napoveda
MENU_H1    = MENUSCR+$128
MENU_H2    = MENUSCR+$150
MENU_H3    = MENUSCR+$178
MENU_CR    = MENUSCR+$1A0

; rozvrzeni herni obrazovky (sloupce / radky znaku) - vzor design3.asm
WELL_COL   = 15            ; prvni sloupec bunek studny (steny na 14 a 25)
WALL_L     = 14
WALL_R     = 25
FLOOR_ROW  = 24            ; dno (radky bunek 0..23)
NEXT_COL   = 31            ; ramecek NEXT 6x6 (sloupce 31..36, radky 1..6), vnitrek 32..35 / 2..5
NEXT_ROW   = 1
PAN_COL    = 30            ; panel: popisky i hodnoty
HINT_COL   = 2             ; napoveda: akce sloupec 2, ovladani sloupec 3
MSG_ROW    = 25            ; radek hlasek
MSG_ADDR   = GAMESCR+MSG_ROW*40

; graficke znaky (interni kody)
G_SOLID    = $80           ; plny blok (inverzni mezera) = kostka
G_TL       = $51
G_TR       = $45
G_BL       = $5A
G_BR       = $43
G_HLINE    = $52
G_VLINE    = $7C

; ---------------------------------------------------------------------
;  Herni konstanty
; ---------------------------------------------------------------------
BW        = 10             ; sirka plochy
BH        = 24             ; vyska plochy (radku)
EMPTY     = 8              ; prazdna bunka
ACTIVE    = $10            ; bit v Comp: bunka aktivni kostky (kresli se prazdna, barvu dava player 2)
WHITE     = 7              ; znacka "blikajici rada" (kresli se jako prazdno)
SK_EASY   = 0
SK_ADV    = 1
SK_EXP    = 2

MAXLEVEL  = 20
MAXSEL    = 15             ; nejvyssi level volitelny v menu (DevMode: MAXLEVEL)
KEY_N     = $23            ; dev: dalsi level
KEY_G     = $3D            ; dev: game over

IN_LEFT   = $01
IN_RIGHT  = $02
IN_DOWN   = $04
IN_UP     = $08
IN_FIRE   = $10
IN_HARD   = $20
IN_ESC    = $40
IN_PAUSE  = $80
CS_START  = $01
CS_SELECT = $02
CS_OPTION = $04

DAS_DELAY = 12             ; snimku do autorepeatu
DAS_RATE  = 4              ; perioda autorepeatu
SOFT_RATE = 2              ; soft drop: 1 bunka za 2 snimky
IDLE_LO   = <750           ; ~15 s necinnosti -> demo (PAL 50 Hz)
IDLE_HI   = >750
AI_DELAY  = 6              ; zakladni tempo tahu AI (snimky)
AI_THINK  = 14             ; "premysleni" po spawnu

ST_SPAWN  = 0
ST_FALL   = 1
ST_CLEAR  = 2

MSG_NORMAL = 0
MSG_DEMO   = 1
MSG_PAUSED = 2
MSG_LEVEL  = 3
MSG_OVER   = 4

; sfx id
SFX_MOVE   = 0
SFX_ROT    = 1
SFX_DROP   = 2
SFX_SOFT   = 3
SFX_LINE   = 4
SFX_TETRIS = 5
SFX_FANF1  = 6
SFX_FANF2  = 7
SFX_OVER   = 8
SFX_MENU   = 9
SFX_SELECT = 10
SFX_PAUSE  = 11
SFX_NOROT  = 12
BEEP_F     = $21           ; pipani napoctu bonusu (~960 Hz), 1 snimek ton + 2 ticho
BEEP_C     = $A8

; ---------------------------------------------------------------------
;  Nulta stranka
; ---------------------------------------------------------------------
        org $80
ptr       .byte 0,0
ptr2      .byte 0,0
tmp       .byte 0
tmp2      .byte 0
tmp3      .byte 0
tmp4      .byte 0
sptr      .byte 0,0        ; jen SoundTick (VBI) - nesmi sdilet ptr/ptr2 s hlavnim kodem
stmp      .byte 0          ; jen SoundTick (VBI)
cellx     .byte 0
celly     .byte 0
FrameCnt  .byte 0
DliCnt    .byte 0
DliMode   .byte 0          ; 0 = titulni obrazovka (duha), 1 = hra
DliModeReq .byte 0         ; pozadovany rezim (prebira VBI spolu s DL)
TxtOr     .byte 0          ; maska OR pro PutStr (inverze / barva mode 6)
TestX     .byte 0
TestY     .byte 0
TestRot   .byte 0

; ---------------------------------------------------------------------
;  Makra
; ---------------------------------------------------------------------
.macro PUTS                ; PUTS cil, retezec
        lda #<(:2)
        sta ptr
        lda #>(:2)
        sta ptr+1
        lda #<(:1)
        sta ptr2
        lda #>(:1)
        sta ptr2+1
        jsr PutStr
.endm

.macro SFX                 ; SFX id
        ldx #:1
        jsr PlaySfx
.endm

; =====================================================================
        org $2000
; ---------------------------------------------------------------------
;  Promenne
; ---------------------------------------------------------------------
DlPtr     .byte 0,0
TxBk     .byte 0          ; barvy zapisovane kazdy VBI (textova cast)
TxPf0    .byte 0
TxPf1    .byte 0
TxPf2    .byte 0
TxPf3    .byte 0

InRaw     .byte 0
InNew     .byte 0
InPrev    .byte 0
ConsRaw   .byte 0
ConsNew   .byte 0
ConsPrev  .byte 0
KeyCode   .byte $FF
KeyPrev   .byte $FF
KeyNew    .byte $FF        ; kod prave stisknute klavesy (jen 1 snimek), jinak $FF
DevMode   .byte 0          ; 1 = OPTION drzen pri startu
LevelMax  .byte MAXSEL
IdleLo    .byte 0
IdleHi    .byte 0

MenuSel   .byte 0
MenuLevel .byte 1
MenuSkill .byte 0          ; SK_EASY / SK_ADV / SK_EXP

Demo      .byte 0
Level     .byte 1
Score     .byte 0,0,0      ; BCD, nejnizsi bajt prvni
Lines     .byte 0,0        ; BCD
State     .byte 0
Paused    .byte 0
AbortFlag .byte 0
GameOverFlag .byte 0
MsgId     .byte 0
NextDirty .byte 0
PmOn      .byte 0          ; 1 = PMG podbarveni zapnuto (herni obrazovka)
PcHpos    .byte 0          ; player 2 (aktivni kostka): HPOS, barva, prvni radek dat ($FF = nic)
PcCol     .byte 0
PcPrevRow .byte $FF        ; radek dat P2 aktualne zobrazeny (spravuje VBI)
PcRow     .byte $FF        ; radek, kam VBI zkopiruje PcBuf ($FF = kostka neni)
PcBuf     :32 .byte 0      ; 4 radky x 8 scanlinu pripravene hlavnim kodem
NxBuf     :32 .byte 0      ; totez pro NEXT (pevne radky NEXT_ROW+1..+4)
NxHpos    .byte 0          ; player 3 (NEXT): HPOS, barva
NxCol     .byte 0
RowsInLevel .byte 0        ; smazane rady v aktualnim levelu (binarne)
RowsTarget .byte 0         ; cil levelu
TimeFrm   .byte 0          ; snimky do sekundy
TimeSec   .byte 0          ; BCD
TimeMin   .byte 0          ; BCD

CurType   .byte 0
CurRot    .byte 0
CurX      .byte 0
CurY      .byte 0
NextType  .byte 0
GravSpeed .byte 0
GravCnt   .byte 0
DasCnt    .byte 0
SoftCnt   .byte 0
SoftArmed .byte 0
FullCnt   .byte 0
FullRows  .byte 0,0,0,0
FlashCnt  .byte 0
FlashPhase .byte 0
DropCells .byte 0
LinesNow  .byte 0
ScoreRem  .byte 0,0        ; zbyvajici bonus za rady v jednotkach 10 bodu (binarne, lo/hi)
ScoreN    .byte 0,0        ; celkovy bonus v jednotkach (N)
ScoreAcc  .byte 0,0        ; akumulator: kazdy snimek += N, za kazdych ScoreLen jedna jednotka
ScoreLen  .byte 0          ; delka animace skore ve snimcich (rady 24, level 48)
ScoreBeep .byte 0          ; 1 = napocet pipa (jen bonus za level), BeepCnt = faze 0..2
BeepCnt   .byte 0
SeqCnt    .byte 0          ; citac snimku pro blokujici sekvence (level done, game over)
SeqRow    .byte 0

AiRot     .byte 0
AiX       .byte 0
AiHard    .byte 0
AiTimer   .byte 0
AiPhase   .byte 0          ; 0 = rotuj/posun, 1 = drzi dolu
BestLo    .byte 0
BestHi    .byte 0
BestRot   .byte 0
BestX     .byte 0
EvalLo    .byte 0
EvalHi    .byte 0
ColH      :10 .byte 0
ColFill   :10 .byte 0
FullL     .byte 0
Holes     .byte 0
Agg       .byte 0
Bump      .byte 0
MaxH      .byte 0

CellIdx   .byte 0,0,0,0
RowBuf    :10 .byte 0

SndPtrLo  .byte 0,0,0,0
SndPtrHi  .byte 0,0,0,0
SndCnt    .byte 0,0,0,0

Board     :240 .byte EMPTY
Comp      :240 .byte EMPTY
PrevComp  :240 .byte $FF   ; naposledy vykresleny stav (pro preskoceni nezmenenych radku)

; ---------------------------------------------------------------------
;  Tabulky
; ---------------------------------------------------------------------
; radek plochy -> index (y*10)
RowOff10  .byte 0,10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160,170,180,190,200,210,220,230

; radek obrazovky -> adresa (GAMESCR + r*40)
RowPtrLo  .byte <(GAMESCR+0*40),<(GAMESCR+1*40),<(GAMESCR+2*40),<(GAMESCR+3*40),<(GAMESCR+4*40),<(GAMESCR+5*40),<(GAMESCR+6*40),<(GAMESCR+7*40),<(GAMESCR+8*40),<(GAMESCR+9*40),<(GAMESCR+10*40),<(GAMESCR+11*40),<(GAMESCR+12*40),<(GAMESCR+13*40),<(GAMESCR+14*40),<(GAMESCR+15*40),<(GAMESCR+16*40),<(GAMESCR+17*40),<(GAMESCR+18*40),<(GAMESCR+19*40),<(GAMESCR+20*40),<(GAMESCR+21*40),<(GAMESCR+22*40),<(GAMESCR+23*40),<(GAMESCR+24*40),<(GAMESCR+25*40)
RowPtrHi  .byte >(GAMESCR+0*40),>(GAMESCR+1*40),>(GAMESCR+2*40),>(GAMESCR+3*40),>(GAMESCR+4*40),>(GAMESCR+5*40),>(GAMESCR+6*40),>(GAMESCR+7*40),>(GAMESCR+8*40),>(GAMESCR+9*40),>(GAMESCR+10*40),>(GAMESCR+11*40),>(GAMESCR+12*40),>(GAMESCR+13*40),>(GAMESCR+14*40),>(GAMESCR+15*40),>(GAMESCR+16*40),>(GAMESCR+17*40),>(GAMESCR+18*40),>(GAMESCR+19*40),>(GAMESCR+20*40),>(GAMESCR+21*40),>(GAMESCR+22*40),>(GAMESCR+23*40),>(GAMESCR+24*40),>(GAMESCR+25*40)

; tvary: 7 kusu x 4 rotace x 4 bunky, bajt = dy*16 + dx
PieceTab
; I
        .byte $10,$11,$12,$13, $02,$12,$22,$32, $20,$21,$22,$23, $01,$11,$21,$31
; O
        .byte $01,$02,$11,$12, $01,$02,$11,$12, $01,$02,$11,$12, $01,$02,$11,$12
; T
        .byte $10,$11,$12,$01, $01,$11,$21,$12, $10,$11,$12,$21, $01,$11,$21,$10
; S
        .byte $01,$02,$10,$11, $01,$11,$12,$22, $11,$12,$20,$21, $00,$10,$11,$21
; Z
        .byte $00,$01,$11,$12, $02,$11,$12,$21, $10,$11,$21,$22, $01,$10,$11,$20
; J
        .byte $00,$10,$11,$12, $01,$02,$11,$21, $10,$11,$12,$22, $01,$11,$20,$21
; L
        .byte $02,$10,$11,$12, $01,$11,$21,$22, $10,$11,$12,$20, $00,$01,$11,$21

RotCount  .byte 2,1,4,2,2,4,4       ; pocet odlisnych rotaci (pro AI)
PieceCol  .byte $9A,$EE,$48,$B8,$34,$76,$1A   ; I O T S Z J L (syte: bunka je prazdna, barvu dava jen hrac)
CellMask  .byte $C0,$30,$0C,$03     ; bity hrace (dvojnasobna sirka) pro bunku dx 0..3
KickTab   .byte 0,$FF,1,$FE,2       ; wall kick posuny

; rychlost (snimku na 1 radek padu) pro level 1..20
SpeedTab  .byte 0,40,36,32,28,24,20,17,14,12,10,8,7,6,5,4,4,3,3,2,2
; cil radku pro level 1..20 (roste podlinearne)
TargetTab .byte 0,5,7,9,11,12,13,14,15,16,17,18,18,19,19,20,20,20,20,20,20

; startovni struktury (ADVANCED/EXPERT): pocet radku, pak radky shora dolu,
; 10 znaku, '#' = cihla. Zrcadlove symetricke, nikdy plna rada.
PatternLo .byte 0,<Pat1,<Pat2,<Pat3,<Pat4,<Pat5,<Pat6,<Pat7,<Pat8,<Pat9,<Pat10,<Pat11,<Pat12
PatternHi .byte 0,>Pat1,>Pat2,>Pat3,>Pat4,>Pat5,>Pat6,>Pat7,>Pat8,>Pat9,>Pat10,>Pat11,>Pat12
Pat1    .byte 1
        dta c'.#......#.'
Pat2    .byte 4
        dta c'#........#'
        dta c'#........#'
        dta c'##......##'
        dta c'###....###'
Pat3    .byte 6
        dta c'....##....'
        dta c'..........'
        dta c'#........#'
        dta c'##......##'
        dta c'###....###'
        dta c'####..####'
Pat4    .byte 6
        dta c'..#....#..'
        dta c'.##....##.'
        dta c'###....###'
        dta c'#.#....#.#'
        dta c'#........#'
        dta c'###.##.###'
Pat5    .byte 7
        dta c'##......##'
        dta c'#........#'
        dta c'#..####..#'
        dta c'#..#..#..#'
        dta c'#..####..#'
        dta c'#........#'
        dta c'####..####'
Pat6    .byte 8
        dta c'.#......#.'
        dta c'.#......#.'
        dta c'.#..##..#.'
        dta c'.#..##..#.'
        dta c'.#......#.'
        dta c'##......##'
        dta c'##.####.##'
        dta c'##.#..#.##'
Pat7    .byte 8
        dta c'###....###'
        dta c'..#....#..'
        dta c'..........'
        dta c'.###..###.'
        dta c'.#......#.'
        dta c'.#......#.'
        dta c'##..##..##'
        dta c'#...##...#'
Pat8    .byte 9
        dta c'#........#'
        dta c'#.##..##.#'
        dta c'#.#....#.#'
        dta c'#........#'
        dta c'#.######.#'
        dta c'#........#'
        dta c'##.#..#.##'
        dta c'#..#..#..#'
        dta c'#.##..##.#'
Pat9    .byte 10
        dta c'....##....'
        dta c'....##....'
        dta c'.#......#.'
        dta c'.##....##.'
        dta c'.##.##.##.'
        dta c'.##....##.'
        dta c'.#......#.'
        dta c'##......##'
        dta c'#.#.##.#.#'
        dta c'#.#....#.#'
Pat10    .byte 11
        dta c'#.#....#.#'
        dta c'###....###'
        dta c'..........'
        dta c'.########.'
        dta c'.#......#.'
        dta c'.#.####.#.'
        dta c'.#......#.'
        dta c'.########.'
        dta c'..........'
        dta c'##.#..#.##'
        dta c'#..#..#..#'
Pat11    .byte 12
        dta c'#........#'
        dta c'##......##'
        dta c'#.#....#.#'
        dta c'#..#..#..#'
        dta c'#...##...#'
        dta c'#..#..#..#'
        dta c'#.#....#.#'
        dta c'##......##'
        dta c'#........#'
        dta c'#.######.#'
        dta c'#........#'
        dta c'###.##.###'
Pat12    .byte 14
        dta c'.#.#..#.#.'
        dta c'.#.#..#.#.'
        dta c'.#.#..#.#.'
        dta c'.###..###.'
        dta c'..........'
        dta c'########..'
        dta c'..........'
        dta c'..########'
        dta c'..........'
        dta c'##.####.##'
        dta c'#..#..#..#'
        dta c'#.##..##.#'
        dta c'#........#'
        dta c'###.##.###'
; vyplnove rady pro levely nad 12 (pridavaji se odspodu, stridave)
FillerA dta c'#.##.###.#'
FillerB dta c'##.#.#.##.'

; skore za 1..4 rad (BCD, x level)
UnitTab   .byte 0,4,10,30,120       ; body za 1-4 rady / 10 (x level), pricitaji se behem blikani
FLASH_LEN = 24                      ; delka blikani ve snimcich
BONUS_LEN = 48                      ; delka animace bonusu za level

Rainbow   .byte $1A,$1C,$2A,$2C,$3A,$3C,$4A,$4C,$5A,$5C,$6A,$6C,$7A,$7C,$8A,$8C
          .byte $9A,$9C,$AA,$AC,$BA,$BC,$CA,$CC,$DA,$DC,$EA,$EC,$FA,$FC,$0A,$0E

; klavesy (KBCODE & $3F) -> bity vstupu
KeyMapCode .byte $06,$07,$0E,$0F,$21,$1C,$0A,$17,$16,$0C
KeyMapBit  .byte IN_LEFT,IN_RIGHT,IN_UP,IN_DOWN,IN_HARD,IN_ESC,IN_PAUSE,IN_FIRE,IN_UP,IN_FIRE
KEYMAPLEN  = 10

; ---------------------------------------------------------------------
;  Texty (screen kody, ukonceno $FF)
; ---------------------------------------------------------------------
TxtTitle  dta d'TETRIS',$FF
TxtSub    dta d'ATARI XL/XE EDITION',$FF
TxtPress  dta d'PRESS START OR FIRE',$FF
TxtItem0  dta d'START GAME',$FF
TxtItem1  dta d'LEVEL',$FF
TxtItem2  dta d'SKILL',$FF
TxtItem3  dta d'HELP',$FF
TxtSkill0 dta d'EASY    ',$FF
TxtSkill1 dta d'ADVANCED',$FF
TxtSkill2 dta d'EXPERT  ',$FF
TxtArrow  dta d'>',$FF
TxtW0     dta d'CLASSIC TETRIS FOR ATARI XL/XE',$FF
TxtW1     dta d'CLEAR THE ROW TARGET TO FINISH A LEVEL',$FF
TxtW2     dta d'ADVANCED: OBSTACLES  EXPERT: NO NEXT',$FF
TxtW3     dta d'WAIT A WHILE TO WATCH THE DEMO',$FF
TxtH0     dta d'STICK/ARROWS MOVE     FIRE/UP/Z ROTATE',$FF
TxtH1     dta d'DOWN SOFT DROP        SPACE HARD DROP',$FF
TxtH2     dta d'SELECT LEVEL   OPTION SKILL   ESC MENU',$FF
TxtH3     dta d'PRESS START OR FIRE TO PLAY',$FF
TxtCr     dta d'(C) 2026 BYPS - MADS ASSEMBLER',$FF
TxtNext   dta d'NEXT',$FF
TxtLevel  dta d'LEVEL',$FF
TxtScore  dta d'SCORE',$FF
TxtLines  dta d'LINES',$FF
TxtRows   dta d'ROWS',$FF
TxtTime   dta d'TIME',$FF
TxtHn1a   dta d'MOVE',$FF
TxtHn1b   dta d'STICK',$FF
TxtHn2a   dta d'ROTATE',$FF
TxtHn2b   dta d'FIRE',$FF
TxtHn3a   dta d'DROP',$FF
TxtHn3b   dta d'DOWN',$FF
TxtHn4a   dta d'HARD',$FF
TxtHn4b   dta d'SPACE',$FF
TxtHn5a   dta d'PAUSE',$FF
TxtHn5b   dta d'P',$FF
TxtHn6a   dta d'MENU',$FF
TxtHn6b   dta d'ESC',$FF
TxtDemo   dta d'DEMO',$FF
TxtDev    dta d'DEV',$FF
TxtMsgD   dta d'DEMO PLAY - MOVE STICK OR PRESS A KEY',$FF
TxtMsgP   dta d'PAUSED - PRESS P TO CONTINUE',$FF
TxtMsgL   dta d'LEVEL COMPLETE - GET READY',$FF
TxtMsgO   dta d'GAME OVER - PRESS FIRE OR START',$FF
TxtMsgOD  dta d'GAME OVER',$FF
; HELP obrazovka (radek, sloupec, text)
HelpTab
        .byte 1,13
        dta d'TETRIS - HELP',$FF
        .byte 3,1
        dta d'SKILL',$FF
        .byte 4,1
        dta d'EASY     EMPTY WELL, NEXT PIECE SHOWN',$FF
        .byte 5,1
        dta d'ADVANCED OBSTACLES IN THE WELL AT THE',$FF
        .byte 6,1
        dta d'         START OF EVERY LEVEL',$FF
        .byte 7,1
        dta d'EXPERT   OBSTACLES AND NO NEXT PIECE',$FF
        .byte 9,1
        dta d'LEVELS',$FF
        .byte 10,1
        dta d'EACH LEVEL HAS A ROW TARGET (ROWS X/Y)',$FF
        .byte 11,1
        dta d'AND A FALLING SPEED. CLEAR THE TARGET',$FF
        .byte 12,1
        dta d'TO ADVANCE. THE GAME ENDS WHEN A NEW',$FF
        .byte 13,1
        dta d'PIECE CANNOT ENTER THE WELL.',$FF
        .byte 15,1
        dta d'CONTROLS',$FF
        .byte 16,1
        dta d'STICK OR ARROWS    MOVE LEFT / RIGHT',$FF
        .byte 17,1
        dta d'FIRE, UP, Z, X     ROTATE',$FF
        .byte 18,1
        dta d'DOWN               SOFT DROP',$FF
        .byte 19,1
        dta d'SPACE              HARD DROP',$FF
        .byte 20,1
        dta d'P OR START         PAUSE',$FF
        .byte 21,1
        dta d'ESC                ABANDON GAME',$FF
        .byte 22,1
        dta d'SELECT / OPTION    LEVEL / SKILL (MENU)',$FF
        .byte 24,2
        dta d'ANY KEY = NEXT PAGE     ESC = MENU',$FF
        .byte $FF

; HELP strana 2: bodovani
HelpTab2
        .byte 1,12
        dta d'TETRIS - SCORING',$FF
        .byte 3,1
        dta d'ROWS CLEARED AT ONCE     POINTS',$FF
        .byte 4,1
        dta d'1 ROW                 40 X LEVEL',$FF
        .byte 5,1
        dta d'2 ROWS               100 X LEVEL',$FF
        .byte 6,1
        dta d'3 ROWS               300 X LEVEL',$FF
        .byte 7,1
        dta d'4 ROWS (TETRIS)     1200 X LEVEL',$FF
        .byte 9,1
        dta d'THE MORE ROWS YOU CLEAR WITH ONE',$FF
        .byte 10,1
        dta d'PIECE, THE MORE EACH ROW IS WORTH.',$FF
        .byte 12,1
        dta d'SOFT DROP (DOWN)       1 PER CELL',$FF
        .byte 13,1
        dta d'HARD DROP (SPACE)      2 PER CELL',$FF
        .byte 14,1
        dta d'LEVEL COMPLETE       1000 X LEVEL',$FF
        .byte 16,1
        dta d'LEVEL',$FF
        .byte 17,1
        dta d'EACH LEVEL FALLS FASTER AND NEEDS',$FF
        .byte 18,1
        dta d'MORE ROWS (SEE ROWS X/Y). A HIGHER',$FF
        .byte 19,1
        dta d'START LEVEL MEANS MORE POINTS.',$FF
        .byte 24,2
        dta d'ANY KEY = BACK TO MENU',$FF
        .byte $FF

; =====================================================================
;  START
; =====================================================================
start
        sei
        lda #0
        sta NMIEN
        sta DMACTL
        sta AUDCTL
        sta GRACTL
        sta AUDC1
        sta AUDC1+2
        sta AUDC1+4
        sta AUDC1+6
        sta SndPtrHi
        sta SndPtrHi+1
        sta SndPtrHi+2
        sta SndPtrHi+3
        lda #3
        sta SKCTL
        lda #<Dli
        sta VDSLST
        lda #>Dli
        sta VDSLST+1
        lda #<Vbi
        sta VVBLKI
        lda #>Vbi
        sta VVBLKI+1
        jsr InitPMG
        lda CONSOL                  ; OPTION drzen pri startu -> vyvojarsky rezim
        and #CS_OPTION
        bne NoDev
        lda #1
        sta DevMode
        lda #MAXLEVEL
        sta LevelMax
NoDev   jsr SetMenuScreen
        lda #$C0
        sta NMIEN
        cli

MainLoop
        jsr TitleScreen
        bne ML_demo
ML_menu
        jsr MenuScreen
        bne ML_demo
        lda #0
        sta Demo
        jsr RunGame
        jmp ML_menu
ML_demo
        lda #1
        sta Demo
        jsr RunGame
        jmp ML_menu

; =====================================================================
;  UVODNI OBRAZOVKA
;  vraci A=0 -> pokracuj do menu, A=1 -> necinnost, spust demo
; =====================================================================
TitleScreen
        jsr SetMenuScreen
        jsr WaitRelease
        lda #0
        sta TxtOr
        PUTS MENU_H0+5, TxtW0
        PUTS MENU_H1+1, TxtW1
        PUTS MENU_H2+2, TxtW2
        PUTS MENU_H3+5, TxtW3
        PUTS MENU_CR+5, TxtCr
        jsr ResetIdle
TS_loop
        jsr WaitFrame
        jsr ReadInputs
        ; blikajici vyzva (mode 6, barva PF0 / PF1)
        lda FrameCnt
        and #$10
        beq TS_c1
        lda #$40
TS_c1   sta TxtOr
        PUTS MENU_IT1, TxtPress
        jsr IdleTick
        bne TS_demo
        lda InNew
        ora ConsNew
        beq TS_loop
        SFX SFX_SELECT
        lda #0
        rts
TS_demo lda #1
        rts

; =====================================================================
;  MENU
;  vraci A=0 -> start hry, A=1 -> demo
; =====================================================================
MenuScreen
        lda #0
        sta MenuSel
MS_restart
        jsr SetMenuScreen
        jsr WaitRelease
        lda #0
        sta TxtOr
        PUTS MENU_H0+1, TxtH0
        PUTS MENU_H1+1, TxtH1
        PUTS MENU_H2+1, TxtH2
        PUTS MENU_CR+5, TxtCr
        jsr ResetIdle
MS_loop
        jsr WaitFrame
        jsr ReadInputs
        jsr DrawMenuItems
        jsr IdleTick
        beq MS_go
        jmp MS_demo
MS_go   lda InNew
        and #IN_UP
        beq MS_1
        dec MenuSel
        bpl MS_snd
        lda #3
        sta MenuSel
MS_snd  SFX SFX_MENU
MS_1    lda InNew
        and #IN_DOWN
        beq MS_2
        inc MenuSel
        lda MenuSel
        cmp #4
        bcc MS_snd2
        lda #0
        sta MenuSel
MS_snd2 SFX SFX_MENU
MS_2    lda InNew
        and #IN_LEFT
        beq MS_3
        jsr MenuAdjDown
MS_3    lda InNew
        and #IN_RIGHT
        beq MS_4
        jsr MenuAdjUp
MS_4    lda InNew
        and #IN_FIRE
        beq MS_5
        lda MenuSel
        beq MS_start
        cmp #3
        bne MS_adj
        SFX SFX_SELECT
        jsr HelpScreen
        jmp MS_restart
MS_adj  jsr MenuAdjUp
MS_5    lda ConsNew
        and #CS_START
        bne MS_start
        lda ConsNew
        and #CS_SELECT
        beq MS_6
        jsr LevelUp
MS_6    lda ConsNew
        and #CS_OPTION
        beq MS_7
        jsr SkillToggle
MS_7    jmp MS_loop
MS_start
        SFX SFX_SELECT
        lda #0
        rts
MS_demo lda #1
        rts

MenuAdjUp
        lda MenuSel
        cmp #1
        beq LevelUp
        cmp #2
        beq SkillToggle
        rts
MenuAdjDown
        lda MenuSel
        cmp #1
        beq LevelDown
        cmp #2
        beq SkillPrev
        rts
LevelUp
        inc MenuLevel
        lda MenuLevel
        cmp LevelMax
        beq LU_ok
        bcc LU_ok
        lda #1
        sta MenuLevel
LU_ok   SFX SFX_MENU
        rts
LevelDown
        dec MenuLevel
        bne LD_ok
        lda LevelMax
        sta MenuLevel
LD_ok   SFX SFX_MENU
        rts
SkillToggle
        inc MenuSkill
        lda MenuSkill
        cmp #3
        bcc ST_ok
        lda #0
        sta MenuSkill
ST_ok   SFX SFX_MENU
        rts
SkillPrev
        dec MenuSkill
        bpl SP_ok
        lda #2
        sta MenuSkill
SP_ok   SFX SFX_MENU
        rts

; jmeno obtiznosti -> ptr (podle MenuSkill)
SkillName
        lda MenuSkill
        cmp #SK_ADV
        beq SN_adv
        bcs SN_exp
        lda #<TxtSkill0
        sta ptr
        lda #>TxtSkill0
        sta ptr+1
        rts
SN_adv  lda #<TxtSkill1
        sta ptr
        lda #>TxtSkill1
        sta ptr+1
        rts
SN_exp  lda #<TxtSkill2
        sta ptr
        lda #>TxtSkill2
        sta ptr+1
        rts

; vykresli tri polozky menu (mode 6), vybrana bile s sipkou
DrawMenuItems
        ldx #0
        jsr MenuItemColor
        jsr ClearItem0
        PUTS MENU_IT0+3, TxtItem0
        ldx #1
        jsr MenuItemColor
        jsr ClearItem1
        PUTS MENU_IT1+3, TxtItem1
        lda MenuLevel
        ldy #0
        jsr Bin2Dec
        lda tmp2
        ora #$10
        ora TxtOr
        sta MENU_IT1+12
        lda tmp3
        ora #$10
        ora TxtOr
        sta MENU_IT1+13
        ldx #2
        jsr MenuItemColor
        jsr ClearItem2
        PUTS MENU_IT2+3, TxtItem2
        jsr SkillName
        lda #<(MENU_IT2+12)
        sta ptr2
        lda #>(MENU_IT2+12)
        sta ptr2+1
        jsr PutStr
        ldx #3
        jsr MenuItemColor
        jsr ClearItem3
        PUTS MENU_IT3+3, TxtItem3
        ; sipka na vybranou polozku (blika)
        lda FrameCnt
        and #$08
        bne DMI_done
        lda MenuSel
        beq DMI_a0
        cmp #1
        beq DMI_a1
        cmp #2
        beq DMI_a2
        PUTS MENU_IT3+1, TxtArrow
        rts
DMI_a2  PUTS MENU_IT2+1, TxtArrow
        rts
DMI_a0  PUTS MENU_IT0+1, TxtArrow
        rts
DMI_a1  PUTS MENU_IT1+1, TxtArrow
DMI_done
        rts

; X = index polozky -> TxtOr = $40 (PF1, vybrana) nebo 0 (PF0)
MenuItemColor
        lda #0
        cpx MenuSel
        bne MIC_s
        lda #$40
MIC_s   sta TxtOr
        rts

ClearItem0
        ldy #19
        lda #0
CI0     sta MENU_IT0,y
        dey
        bpl CI0
        rts
ClearItem1
        ldy #19
        lda #0
CI1     sta MENU_IT1,y
        dey
        bpl CI1
        rts
ClearItem2
        ldy #19
        lda #0
CI2     sta MENU_IT2,y
        dey
        bpl CI2
        rts
ClearItem3
        ldy #19
        lda #0
CI3     sta MENU_IT3,y
        dey
        bpl CI3
        rts

; ---------------------------------------------------------------------
;  HELP obrazovka, 2 stranky (pouziva herni DL bez PMG); libovolny vstup
;  = dalsi stranka / navrat, ESC = navrat hned
; ---------------------------------------------------------------------
HelpScreen
        jsr ClearGameScr
        lda #0
        sta TxtOr
        sta PmOn
        lda #COL_BG
        sta TxBk
        sta TxPf2
        lda #COL_TEXT
        sta TxPf1
        lda #<GameDL
        sta DlPtr
        lda #>GameDL
        sta DlPtr+1
        lda #1
        sta DliModeReq
        lda #<HelpTab
        sta ptr
        lda #>HelpTab
        sta ptr+1
        jsr HelpPage
        lda InNew
        and #IN_ESC
        bne HS_x                    ; ESC = rovnou do menu
        jsr ClearGameScr
        lda #<HelpTab2
        sta ptr
        lda #>HelpTab2
        sta ptr+1
        jsr HelpPage
HS_x    jsr WaitRelease
        rts

; vykresli stranku (ptr -> tabulka radek,sloupec,text; konec $FF) a ceka na vstup
HelpPage
HS_line ldy #0
        lda (ptr),y
        cmp #$FF
        beq HS_wait
        tax                         ; radek
        iny
        lda (ptr),y
        clc
        adc RowPtrLo,x
        sta ptr2
        lda RowPtrHi,x
        adc #0
        sta ptr2+1
        ; ptr += 2 -> text
        lda ptr
        clc
        adc #2
        sta ptr
        bcc HS_p
        inc ptr+1
HS_p    jsr PutStr                  ; Y = delka textu
        tya
        sec                         ; +1 za $FF
        adc ptr
        sta ptr
        bcc HS_line
        inc ptr+1
        jmp HS_line
HS_wait jsr WaitRelease
HS_l    jsr WaitFrame
        jsr ReadInputs
        lda InNew
        ora ConsNew
        beq HS_l
        SFX SFX_SELECT
        rts

; ---------------------------------------------------------------------
;  Priprava titulni obrazovky (DL, barvy, titulek)
; ---------------------------------------------------------------------
SetMenuScreen
        ; vymaz pamet obrazovky menu ($6A00-$6BFF)
        ldy #0
        tya
SMS_clr sta MENUSCR,y
        sta MENUSCR+$100,y
        iny
        bne SMS_clr
        lda #0
        sta TxtOr
        PUTS MENU_TITLE+7, TxtTitle
        lda #$C0
        sta TxtOr
        PUTS MENU_SUB, TxtSub
        lda #0
        sta TxtOr
        lda #$92
        sta TxBk
        sta TxPf2
        lda #$CA
        sta TxPf0
        lda #$0E
        sta TxPf1
        lda #$28
        sta TxPf3
        lda #<MenuDL
        sta DlPtr
        lda #>MenuDL
        sta DlPtr+1
        lda #0
        sta DliModeReq
        sta PmOn
        rts

; ---------------------------------------------------------------------
;  Necinnost -> demo. Vraci A=1 (Z=0) kdyz je cas na demo.
; ---------------------------------------------------------------------
ResetIdle
        lda #0
        sta IdleLo
        sta IdleHi
        rts
IdleTick
        lda InRaw
        ora ConsRaw
        bne IT_reset
        inc IdleLo
        bne IT_1
        inc IdleHi
IT_1    lda IdleHi
        cmp #IDLE_HI
        bcc IT_no
        lda IdleLo
        cmp #IDLE_LO
        bcc IT_no
        jsr ResetIdle
        lda #1
        rts
IT_reset
        jsr ResetIdle
IT_no   lda #0
        rts

; =====================================================================
;  HRA
; =====================================================================
RunGame
        jsr InitGame
        jsr SetGameScreen
        jsr WaitRelease
        jsr RenderGame
RG_loop
        jsr FrameStep
        lda AbortFlag
        bne RG_exit
        lda Paused
        bne RG_draw
        jsr StateStep
        lda AbortFlag
        bne RG_exit
        lda GameOverFlag
        bne RG_exit
RG_draw
        jsr RenderGame
        jmp RG_loop
RG_exit
        jsr SilenceAll
        jsr WaitRelease
        rts

InitGame
        lda MenuLevel
        sta Level
        lda #0
        sta Score
        sta Score+1
        sta Score+2
        sta Lines
        sta Lines+1
        sta Paused
        sta AbortFlag
        sta GameOverFlag
        sta MsgId
        sta State
        sta DasCnt
        sta SoftCnt
        sta TimeFrm
        sta TimeSec
        sta TimeMin
        jsr ClearBoard
        jsr StartLevel
        jsr RandomPiece
        sta NextType
        lda #1
        sta NextDirty
        rts

; priprava levelu: rychlost, cil radku, startovni struktury
StartLevel
        ldx Level
        lda SpeedTab,x
        sta GravSpeed
        sta GravCnt
        lda TargetTab,x
        sta RowsTarget
        lda #0
        sta RowsInLevel
        jsr FillPattern
        rts

ClearBoard
        ldy #239
        lda #EMPTY
CB_l    sta Board,y
        dey
        cpy #$FF
        bne CB_l
        rts

; nahodny typ kusu 0..6 (s jednim prehozenim, kdyz se shoduje s NextType)
RandomPiece
        jsr Rnd7
        cmp NextType
        bne RP_ok
        jsr Rnd7
RP_ok   rts
Rnd7    lda RANDOM
        and #7
        cmp #7
        beq Rnd7
        rts

; startovni struktury (jen ADVANCED / EXPERT)
FillPattern
        lda MenuSkill
        bne FP_go
        rts
FP_go   ; extra vyplnove rady = (Level-1)/12, max 6
        lda Level
        sec
        sbc #1
        lsr
        lsr                         ; /4
        sta tmp4
        lda #0
        sta tmp3                    ; extra
FP_div  lda tmp4
        cmp #3
        bcc FP_ex
        sbc #3
        sta tmp4
        inc tmp3
        bne FP_div
FP_ex   lda tmp3
        cmp #7
        bcc FP_ex2
        lda #6
        sta tmp3
FP_ex2  ; index vzoru: Level, nad 12 cyklicky 7..12
        lda Level
FP_idx  cmp #13
        bcc FP_iok
        sbc #6
        bne FP_idx
FP_iok  tax
        lda PatternLo,x
        sta ptr
        lda PatternHi,x
        sta ptr+1
        ; vyplnove rady odspodu
        lda #BH
        sta celly                   ; radek pod kterym uz je vyplneno (exkluzivne)
        lda #0
        sta tmp4                    ; citac extra
FP_fill lda tmp4
        cmp tmp3
        bcs FP_pat
        dec celly
        lda tmp4
        and #1
        bne FP_fb
        lda #<FillerA
        sta ptr2
        lda #>FillerA
        sta ptr2+1
        jmp FP_fput
FP_fb   lda #<FillerB
        sta ptr2
        lda #>FillerB
        sta ptr2+1
FP_fput jsr PatRow
        inc tmp4
        jmp FP_fill
FP_pat  ; radky vzoru: pocet N v (ptr),0; radek i (shora) -> celly - N + i
        ldy #0
        lda (ptr),y
        sta tmp4                    ; N
        lda celly
        sec
        sbc tmp4
        sta celly                   ; radek prvniho (horniho) radku vzoru
        lda ptr
        clc
        adc #1
        sta ptr2
        lda ptr+1
        adc #0
        sta ptr2+1
FP_prow lda tmp4
        beq FP_done
        jsr PatRow
        inc celly
        dec tmp4
        lda ptr2
        clc
        adc #10
        sta ptr2
        bcc FP_prow
        inc ptr2+1
        jmp FP_prow
FP_done rts

; zapise 10 znaku z (ptr2) do radku celly plochy ('#' = cihla)
PatRow
        ldx celly
        lda RowOff10,x
        sta tmp2
        ldy #0
PR_l    lda (ptr2),y
        cmp #'#'
        bne PR_e
        lda #1
        bne PR_put
PR_e    lda #EMPTY
PR_put  sty tmp
        ldy tmp2
        sta Board,y
        inc tmp2
        ldy tmp
        iny
        cpy #BW
        bne PR_l
        rts

; ---------------------------------------------------------------------
;  Jeden snimek: cekani, vstupy, preruseni dema / ESC / pauza
; ---------------------------------------------------------------------
FrameStep
        jsr WaitFrame
        jsr ReadInputs
        lda Demo
        beq FS_normal
        lda InRaw
        ora ConsRaw
        beq FS_done
        lda #1
        sta AbortFlag
        rts
FS_normal
        lda InNew
        and #IN_ESC
        beq FS_2
        lda #1
        sta AbortFlag
        rts
FS_2    lda DevMode
        beq FS_2b
        lda KeyNew
        cmp #KEY_N
        beq FS_devN
        cmp #KEY_G
        beq FS_devG
FS_2b   lda InNew
        and #IN_PAUSE
        bne FS_tog
        lda ConsNew
        and #CS_START
        beq FS_done
FS_tog  lda Paused
        eor #1
        sta Paused
        SFX SFX_PAUSE
FS_done ; herni cas (bezi mimo pauzu a game over)
        lda Paused
        ora GameOverFlag
        bne FS_t
        inc TimeFrm
        lda TimeFrm
        cmp #50
        bcc FS_t
        lda #0
        sta TimeFrm
        sed
        clc
        lda TimeSec
        adc #1
        sta TimeSec
        cmp #$60
        bcc FS_tc
        lda #0
        sta TimeSec
        lda TimeMin
        clc
        adc #1
        sta TimeMin
FS_tc   cld
FS_t    rts
FS_devN ; dev: skok na dalsi level
        lda Level
        cmp #MAXLEVEL
        bcs FS_dn1
        inc Level
FS_dn1  jsr ClearBoard
        jsr StartLevel
        lda #ST_SPAWN
        sta State
        SFX SFX_SELECT
        jmp FS_done
FS_devG ; dev: vynutit game over (zaplni horni dva radky)
        ldy #19
        lda #1
FS_dg   sta Board,y
        dey
        bpl FS_dg
        lda #ST_SPAWN
        sta State
        jmp FS_done

; ---------------------------------------------------------------------
;  Stavovy automat hry
; ---------------------------------------------------------------------
StateStep
        lda State
        beq StSpawn
        cmp #ST_FALL
        beq StFall
        jmp StClear

; ---- novy kus ----
StSpawn
        lda NextType
        sta CurType
        jsr RandomPiece
        sta NextType
        lda #1
        sta NextDirty
        lda #0
        sta CurRot
        sta CurY
        sta DasCnt
        sta SoftCnt
        sta SoftArmed
        lda #3
        sta CurX
        jsr CurToTest
        jsr Fits
        bcs SS_ok
        jmp GameOverSeq
SS_ok   lda GravSpeed
        sta GravCnt
        lda #ST_FALL
        sta State
        lda Demo
        beq SS_done
        jsr AiPlan
SS_done rts

; ---- kus pada ----
StFall
        lda Demo
        beq SF_in
        jsr AiStep
SF_in
        ; --- vlevo / vpravo s autorepeatem ---
        lda InRaw
        and #IN_LEFT|IN_RIGHT
        beq SF_dasreset
        lda InNew
        and #IN_LEFT|IN_RIGHT
        beq SF_held
        lda #0
        sta DasCnt
        jsr MoveByInput
        jmp SF_rot
SF_held inc DasCnt
        lda DasCnt
        cmp #DAS_DELAY
        bcc SF_rot
        lda #DAS_DELAY-DAS_RATE
        sta DasCnt
        jsr MoveByInput
        jmp SF_rot
SF_dasreset
        lda #0
        sta DasCnt
SF_rot
        ; --- rotace ---
        lda InNew
        and #IN_UP|IN_FIRE
        beq SF_hard
        jsr TryRotate
SF_hard
        ; --- hard drop ---
        lda InNew
        and #IN_HARD
        beq SF_soft
        jsr HardDrop
        rts
SF_soft
        ; --- soft drop ---
        lda InRaw
        and #IN_DOWN
        bne SF_softheld
        lda #1
        sta SoftArmed
        lda #0
        sta SoftCnt
        jmp SF_grav
SF_softheld
        lda SoftArmed
        beq SF_grav
        inc SoftCnt
        lda SoftCnt
        cmp #SOFT_RATE
        bcc SF_grav
        lda #0
        sta SoftCnt
        jsr TryDown
        bcc SF_lock
        lda #1
        sta tmp
        lda #0
        sta tmp2
        jsr AddScore
        SFX SFX_SOFT
        lda GravSpeed
        sta GravCnt
        rts
SF_grav
        ; --- gravitace ---
        dec GravCnt
        bne SF_done
        lda GravSpeed
        sta GravCnt
        jsr TryDown
        bcs SF_done
SF_lock jsr LockPiece
SF_done rts

; ---- blikani a mazani plnych rad ----
StClear
        inc FlashCnt
        lda FlashCnt
        lsr
        lsr
        and #1
        sta FlashPhase
        jsr ScoreTick               ; skore roste behem blikani
        lda FlashCnt
        cmp #FLASH_LEN
        bcc SC_done
        jsr ScoreFlush              ; pojistka: co zbylo, pricist naraz
        jsr RemoveFullRows
        jsr ScoreLines
        jsr FindFull
        lda FullCnt
        beq SC_nomore
        lda #0
        sta FlashCnt
        jsr StartClearScore
        SFX SFX_LINE
        rts
SC_nomore
        lda RowsInLevel
        cmp RowsTarget
        bcc SC_next
        jmp LevelDoneSeq
SC_next lda #ST_SPAWN
        sta State
SC_done rts

; ---------------------------------------------------------------------
;  Pohyb kusu
; ---------------------------------------------------------------------
CurToTest
        lda CurX
        sta TestX
        lda CurY
        sta TestY
        lda CurRot
        sta TestRot
        rts

MoveByInput
        lda InRaw
        and #IN_LEFT
        beq MBI_r
        lda #$FF
        jmp TryMove
MBI_r   lda InRaw
        and #IN_RIGHT
        beq MBI_no
        lda #1
        jmp TryMove
MBI_no  rts

; A = posun (+1 / -1)
TryMove
        sta tmp
        jsr CurToTest
        lda CurX
        clc
        adc tmp
        sta TestX
        jsr Fits
        bcc TM_fail
        lda TestX
        sta CurX
        SFX SFX_MOVE
TM_fail rts

; carry = 1 kdyz se kus posunul dolu
TryDown
        jsr CurToTest
        inc TestY
        jsr Fits
        bcc TD_fail
        lda TestY
        sta CurY
        sec
        rts
TD_fail clc
        rts

TryRotate
        lda CurRot
        clc
        adc #1
        and #3
        sta TestRot
        lda CurY
        sta TestY
        ldx #0
TR_loop lda CurX
        clc
        adc KickTab,x
        sta TestX
        stx tmp4
        jsr Fits
        bcs TR_ok
        ldx tmp4
        inx
        cpx #5
        bne TR_loop
        SFX SFX_NOROT
        rts
TR_ok   lda TestX
        sta CurX
        lda TestRot
        sta CurRot
        SFX SFX_ROT
        rts

HardDrop
        lda #0
        sta DropCells
HD_l    jsr TryDown
        bcc HD_done
        inc DropCells
        jmp HD_l
HD_done lda DropCells
        asl
        jsr Bin2BcdAdd              ; +2 body za bunku
        jsr LockPiece
        rts

; A = binarni cislo 0..99 -> pricti ke skore
Bin2BcdAdd
        ldy #0
        jsr Bin2Dec                 ; tmp2 = desitky, tmp3 = jednotky
        lda tmp2
        asl
        asl
        asl
        asl
        ora tmp3
        sta tmp
        lda #0
        sta tmp2
        jmp AddScore

; ---------------------------------------------------------------------
;  Test kolize: TestX (signed), TestY, TestRot, CurType -> C=1 vejde se
; ---------------------------------------------------------------------
PieceIndex
        lda TestRot
        asl
        asl
        sta tmp
        lda CurType
        asl
        asl
        asl
        asl
        ora tmp
        tax
        rts

Fits
        jsr PieceIndex
        lda #4
        sta tmp2
F_loop  lda PieceTab,x
        and #$0F
        clc
        adc TestX
        cmp #BW
        bcs F_fail
        sta cellx
        lda PieceTab,x
        :4 lsr
        clc
        adc TestY
        cmp #BH
        bcs F_fail
        tay
        lda RowOff10,y
        clc
        adc cellx
        tay
        lda Board,y
        cmp #EMPTY
        bne F_fail
        inx
        dec tmp2
        bne F_loop
        sec
        rts
F_fail  clc
        rts

; indexy 4 bunek kusu (Test*) do CellIdx (predpoklada platnou pozici)
CalcCells
        jsr PieceIndex
        ldy #0
CC_loop lda PieceTab,x
        and #$0F
        clc
        adc TestX
        sta cellx
        lda PieceTab,x
        :4 lsr
        clc
        adc TestY
        sty tmp2
        tay
        lda RowOff10,y
        clc
        adc cellx
        ldy tmp2
        sta CellIdx,y
        inx
        iny
        cpy #4
        bne CC_loop
        rts

; A = hodnota -> zapis do Board na CellIdx
PutCells
        sta tmp
        ldx #3
PC_l    ldy CellIdx,x
        lda tmp
        sta Board,y
        dex
        bpl PC_l
        rts

; ---------------------------------------------------------------------
;  Zamknuti kusu do plochy
; ---------------------------------------------------------------------
LockPiece
        jsr CurToTest
        jsr CalcCells
        lda CurType
        jsr PutCells
        jsr FindFull
        lda FullCnt
        beq LP_nolines
        lda #ST_CLEAR
        sta State
        lda #0
        sta FlashCnt
        lda #1
        sta FlashPhase
        jsr StartClearScore
        lda FullCnt
        cmp #4
        beq LP_tetris
        SFX SFX_LINE
        rts
LP_tetris
        SFX SFX_TETRIS
        rts
LP_nolines
        SFX SFX_DROP
        lda #ST_SPAWN
        sta State
        rts

; najde plne rady -> FullRows / FullCnt
FindFull
        lda #0
        sta FullCnt
        sta celly
FF_row  ldx celly
        ldy RowOff10,x
        lda #0
        sta tmp
        ldx #BW
FF_cell lda Board,y
        cmp #EMPTY
        beq FF_nx
        inc tmp
FF_nx   iny
        dex
        bne FF_cell
        lda tmp
        cmp #BW
        bne FF_next
        ldx FullCnt
        cpx #4
        bcs FF_next                 ; pojistka: vic nez 4 rady nemuze nastat
        lda celly
        sta FullRows,x
        inc FullCnt
FF_next inc celly
        lda celly
        cmp #BH
        bne FF_row
        rts

; odstrani plne rady (vzestupne), vse nad nimi sesedne
RemoveFullRows
        lda #0
        sta tmp4
RFR_l   lda tmp4
        cmp FullCnt
        bcs RFR_done
        tax
        lda FullRows,x
        sta celly
RFR_shift
        lda celly
        beq RFR_top
        tax
        lda RowOff10,x
        sta tmp2                    ; cil
        dex
        lda RowOff10,x
        sta tmp3                    ; zdroj
        ldx #BW
RFR_cp  ldy tmp3
        lda Board,y
        ldy tmp2
        sta Board,y
        inc tmp2
        inc tmp3
        dex
        bne RFR_cp
        dec celly
        jmp RFR_shift
RFR_top ldy #BW-1
        lda #EMPTY
RFR_clr sta Board,y
        dey
        bpl RFR_clr
        inc tmp4
        jmp RFR_l
RFR_done
        rts

; skore a pocet rad za FullCnt smazanych rad
ScoreLines
        lda FullCnt
        sta LinesNow
        clc
        adc RowsInLevel
        sta RowsInLevel
        ; Lines += FullCnt (BCD)
        sed
        clc
        lda Lines
        adc LinesNow
        sta Lines
        lda Lines+1
        adc #0
        sta Lines+1
        cld
        rts

; ---------------------------------------------------------------------
;  Animace skore: bonus (rady behem blikani FLASH_LEN snimku, level BONUS_LEN snimku)
;  se pricita postupne. N = jednotek po 10 bodech (binarne, max 1800).
;  Rozlozeni bez deleni (Bresenham): kazdy snimek ScoreAcc += N a za kazdych
;  ScoreLen v akumulatoru se pricte 1 jednotka -> po ScoreLen snimcich presne N,
;  rovnomerne i pro male bonusy (40 bodu = 4 dily po 6 snimcich). Bonus za level
;  navic pipa (ScoreBeep): kanal 0 primo z ScoreTick, 1 snimek ton + 2 ticho
;  (jako napocet v Ghostbusters), rady jsou bez zvuku.
; ---------------------------------------------------------------------
StartClearScore
        ldx FullCnt
        lda UnitTab,x
        ldy #FLASH_LEN
; A = jednotek na level, Y = delka animace -> N = A * Level, animace bezi pres ScoreTick
StartScoreAnim
        sta tmp
        sty ScoreLen
        lda #0
        sta ScoreBeep
        sta BeepCnt
        sta ScoreN
        sta ScoreN+1
        sta ScoreAcc
        sta ScoreAcc+1
        ldx Level
SCS_m   lda ScoreN                  ; ScoreN += UnitTab (Level krat)
        clc
        adc tmp
        sta ScoreN
        bcc SCS_1
        inc ScoreN+1
SCS_1   dex
        bne SCS_m
        lda ScoreN
        sta ScoreRem
        lda ScoreN+1
        sta ScoreRem+1
        rts

; jeden snimek blikani: ScoreAcc += N, pricist ScoreAcc / FLASH_LEN jednotek
ScoreTick
        lda ScoreRem
        ora ScoreRem+1
        beq ST_none
        lda ScoreAcc
        clc
        adc ScoreN
        sta ScoreAcc
        lda ScoreAcc+1
        adc ScoreN+1
        sta ScoreAcc+1
        ldx #0                      ; X = jednotek ted
ST_d    lda ScoreAcc
        sec
        sbc ScoreLen
        tay
        lda ScoreAcc+1
        sbc #0
        bcc ST_add
        sty ScoreAcc
        sta ScoreAcc+1
        inx
        bne ST_d
ST_add  txa
        beq ST_snd
        jsr AddUnits
ST_snd  lda ScoreBeep               ; pipani: kazdy treti snimek 1 snimek tonu (kanal 0)
        beq ST_none
        lda ScoreRem
        ora ScoreRem+1
        beq ST_off                  ; dopocitano -> ticho
        inc BeepCnt
        lda BeepCnt
        cmp #3
        bcc ST_off
        lda #0
        sta BeepCnt
        lda #BEEP_F
        sta AUDF1
        lda #BEEP_C
        sta AUDC1
        rts
ST_off  lda #0
        sta AUDC1
ST_none rts

; A = pocet jednotek (< 100) -> odecist ze ScoreRem (max do 0) a pricist A*10 ke skore
AddUnits
        sta tmp3
        lda ScoreRem+1
        bne AU_1
        lda ScoreRem
        cmp tmp3
        bcs AU_1
        sta tmp3                    ; zbyva mene nez pozadovano
AU_1    lda ScoreRem
        sec
        sbc tmp3
        sta ScoreRem
        bcs AU_2
        dec ScoreRem+1
AU_2    lda tmp3
        ldy #0
        jsr Bin2Dec                 ; tmp2 = desitky, tmp3 = jednotky
        lda tmp3
        asl
        asl
        asl
        asl
        sta tmp                     ; lo bajt: jednotky*10
        jmp AddScore                ; hi bajt = tmp2 = stovky

; pojistka na konci blikani: pricist vse, co zbylo
ScoreFlush
        lda ScoreRem
        ora ScoreRem+1
        beq SF_e
        lda #99
        jsr AddUnits
        jmp ScoreFlush
SF_e    rts

; Score += tmp/tmp2 (BCD 16 bit)
AddScore
        sed
        clc
        lda Score
        adc tmp
        sta Score
        lda Score+1
        adc tmp2
        sta Score+1
        lda Score+2
        adc #0
        sta Score+2
        cld
        rts

; ---------------------------------------------------------------------
;  Level dokoncen (splnen cil radku)
; ---------------------------------------------------------------------
LevelDoneSeq
        lda #ST_SPAWN
        sta State
        lda #MSG_LEVEL
        sta MsgId
        SFX SFX_FANF1
        SFX SFX_FANF2
        ; bonus 1000 x level = 100 x level jednotek, naskakuje BONUS_LEN snimku s tiky
        lda #100
        ldy #BONUS_LEN
        jsr StartScoreAnim
        lda #1
        sta ScoreBeep
        lda #150
        sta SeqCnt
LDS_l   jsr FrameStep
        lda AbortFlag
        bne LDS_x
        jsr ScoreTick
        jsr RenderGame
        dec SeqCnt
        bne LDS_l
        jsr ScoreFlush
        lda #0
        sta ScoreBeep
        sta AUDC1
        lda Level
        cmp #MAXLEVEL
        bcs LDS_nl
        inc Level
LDS_nl  jsr ClearBoard
        jsr StartLevel
        lda #MSG_NORMAL
        sta MsgId
LDS_x   rts

; ---------------------------------------------------------------------
;  Konec hry (neni kam spawnout)
; ---------------------------------------------------------------------
GameOverSeq
        lda #1
        sta GameOverFlag
        lda #MSG_OVER
        sta MsgId
        SFX SFX_OVER
        ; plocha se odspodu zaplni
        lda #BH-1
        sta SeqRow
GOS_fill
        ldx SeqRow
        ldy RowOff10,x
        ldx #BW
        lda #1
GOS_c   sta Board,y
        iny
        dex
        bne GOS_c
        jsr FrameStep
        lda AbortFlag
        bne GOS_x
        jsr RenderGame
        jsr FrameStep
        lda AbortFlag
        bne GOS_x
        jsr RenderGame
        dec SeqRow
        bpl GOS_fill
        ; cekej na FIRE/START (demo: ~3 s)
        lda #150
        sta SeqCnt
GOS_w   jsr FrameStep
        lda AbortFlag
        bne GOS_x
        jsr RenderGame
        lda Demo
        beq GOS_key
        dec SeqCnt
        bne GOS_w
        rts
GOS_key lda InNew
        and #IN_FIRE|IN_HARD|IN_UP
        bne GOS_x
        lda ConsNew
        and #CS_START
        beq GOS_w
GOS_x   rts

; =====================================================================
;  AI (demo) - vyber cile pro aktualni kus
; =====================================================================
AiPlan
        lda #$FF
        sta BestLo
        sta BestHi
        lda #0
        sta BestRot
        lda #3
        sta BestX
        lda #0
        sta TestRot
AP_rot  lda #$FE
        sta TestX
AP_x    lda #0
        sta TestY
        jsr Fits
        bcc AP_nextx
        ; spust dolu
AP_drop inc TestY
        jsr Fits
        bcs AP_drop
        dec TestY
        jsr CalcCells
        lda CurType
        jsr PutCells
        jsr Evaluate
        lda #EMPTY
        jsr PutCells
        ; sum -> "prumerny hrac"
        lda RANDOM
        and #$1F
        clc
        adc EvalLo
        sta EvalLo
        bcc AP_cmp
        inc EvalHi
AP_cmp  lda EvalHi
        cmp BestHi
        bcc AP_better
        bne AP_nextx
        lda EvalLo
        cmp BestLo
        bcs AP_nextx
AP_better
        lda EvalLo
        sta BestLo
        lda EvalHi
        sta BestHi
        lda TestRot
        sta BestRot
        lda TestX
        sta BestX
AP_nextx
        inc TestX
        lda TestX
        cmp #BW
        bne AP_x
        inc TestRot
        ldx CurType
        lda TestRot
        cmp RotCount,x
        bcc AP_rot
        lda BestRot
        sta AiRot
        lda BestX
        sta AiX
        lda RANDOM
        and #1
        sta AiHard
        lda #AI_THINK
        sta AiTimer
        lda #0
        sta AiPhase
        rts

; ohodnoceni plochy -> EvalLo/Hi (nizsi = lepsi)
Evaluate
        ldx #9
EV_i    lda #0
        sta ColH,x
        sta ColFill,x
        dex
        bpl EV_i
        lda #0
        sta FullL
        sta celly
        tay
EV_row  lda #0
        sta tmp
        ldx #0
EV_cell lda Board,y
        cmp #EMPTY
        beq EV_emp
        inc tmp
        inc ColFill,x
        lda ColH,x
        bne EV_emp
        lda #BH
        sec
        sbc celly
        sta ColH,x
EV_emp  iny
        inx
        cpx #BW
        bne EV_cell
        lda tmp
        cmp #BW
        bne EV_nf
        inc FullL
EV_nf   inc celly
        lda celly
        cmp #BH
        bne EV_row
        ; agregace
        lda #0
        sta Agg
        sta Holes
        sta Bump
        sta MaxH
        ldx #0
EV_agg  lda ColH,x
        clc
        adc Agg
        sta Agg
        lda ColH,x
        sec
        sbc ColFill,x
        clc
        adc Holes
        sta Holes
        lda ColH,x
        cmp MaxH
        bcc EV_nm
        sta MaxH
EV_nm   cpx #BW-1
        beq EV_an
        lda ColH,x
        sec
        sbc ColH+1,x
        bcs EV_pos
        eor #$FF
        clc
        adc #1
EV_pos  clc
        adc Bump
        sta Bump
EV_an   inx
        cpx #BW
        bne EV_agg
        ; smazane rady snizi vysku
        lda FullL
        beq EV_cost
        asl
        asl
        asl
        adc FullL
        adc FullL                   ; 10*FullL
        sta tmp
        lda Agg
        sec
        sbc tmp
        sta Agg
        lda MaxH
        sec
        sbc FullL
        sta MaxH
EV_cost
        ; cost = 1000 + 3*Agg + 12*Holes + 2*Bump + 6*MaxH - 24*FullL
        lda #<1000
        sta EvalLo
        lda #>1000
        sta EvalHi
        lda Agg
        ldx #3
        jsr AddTimes
        lda Holes
        ldx #12
        jsr AddTimes
        lda Bump
        ldx #2
        jsr AddTimes
        lda MaxH
        ldx #6
        jsr AddTimes
        lda FullL
        asl
        asl
        asl
        sta tmp                     ; 8*FullL
        asl
        clc
        adc tmp                     ; 24*FullL
        sta tmp
        lda EvalLo
        sec
        sbc tmp
        sta EvalLo
        bcs EV_done
        dec EvalHi
EV_done rts

; Eval += A * X
AddTimes
        sta tmp3
AT_l    lda EvalLo
        clc
        adc tmp3
        sta EvalLo
        bcc AT_n
        inc EvalHi
AT_n    dex
        bne AT_l
        rts

; jeden tah AI za snimek -> InRaw / InNew
AiStep
        lda #0
        sta InRaw
        sta InNew
        lda AiPhase
        bne AS_hold
        lda AiTimer
        beq AS_act
        dec AiTimer
        rts
AS_act  lda RANDOM
        and #3
        clc
        adc #AI_DELAY
        sta AiTimer
        lda CurRot
        cmp AiRot
        beq AS_x
        lda #IN_UP
        jmp AS_out
AS_x    lda CurX
        clc
        adc #2
        sta tmp
        lda AiX
        clc
        adc #2
        cmp tmp
        beq AS_reach
        bcc AS_left
        lda #IN_RIGHT
        jmp AS_out
AS_left lda #IN_LEFT
        jmp AS_out
AS_reach
        lda AiHard
        beq AS_soft
        lda #IN_HARD
        jmp AS_out
AS_soft lda #1
        sta AiPhase
AS_hold lda #IN_DOWN
        sta InRaw
        rts
AS_out  sta InRaw
        sta InNew
        rts

; =====================================================================
;  VYKRESLOVANI HERNI OBRAZOVKY
; =====================================================================
SetGameScreen
        jsr ClearGameScr
        ldy #239
        lda #$FF
SGS_p   sta PrevComp,y
        dey
        cpy #$FF
        bne SGS_p
        lda #0
        sta TxtOr
        ; studna: steny radky 0..23, dno radek 24
        ldx #0
SGS_w   lda RowPtrLo,x
        sta ptr
        lda RowPtrHi,x
        sta ptr+1
        lda #G_VLINE
        ldy #WALL_L
        sta (ptr),y
        ldy #WALL_R
        sta (ptr),y
        inx
        cpx #BH
        bne SGS_w
        lda RowPtrLo+FLOOR_ROW
        sta ptr
        lda RowPtrHi+FLOOR_ROW
        sta ptr+1
        ldy #WALL_L
        lda #G_BL
        sta (ptr),y
        iny
        lda #G_HLINE
SGS_f   sta (ptr),y
        iny
        cpy #WALL_R
        bne SGS_f
        lda #G_BR
        sta (ptr),y
        ; NEXT (ne v EXPERT)
        lda MenuSkill
        cmp #SK_EXP
        beq SGS_nn
        PUTS GAMESCR+0*40+NEXT_COL+1, TxtNext
        jsr NextBox
SGS_nn  ; panel
        PUTS GAMESCR+9*40+PAN_COL, TxtLevel
        PUTS GAMESCR+12*40+PAN_COL, TxtScore
        PUTS GAMESCR+15*40+PAN_COL, TxtLines
        PUTS GAMESCR+18*40+PAN_COL, TxtRows
        PUTS GAMESCR+21*40+PAN_COL, TxtTime
        ; napoveda
        PUTS GAMESCR+2*40+HINT_COL, TxtHn1a
        PUTS GAMESCR+3*40+HINT_COL+1, TxtHn1b
        PUTS GAMESCR+5*40+HINT_COL, TxtHn2a
        PUTS GAMESCR+6*40+HINT_COL+1, TxtHn2b
        PUTS GAMESCR+8*40+HINT_COL, TxtHn3a
        PUTS GAMESCR+9*40+HINT_COL+1, TxtHn3b
        PUTS GAMESCR+11*40+HINT_COL, TxtHn4a
        PUTS GAMESCR+12*40+HINT_COL+1, TxtHn4b
        PUTS GAMESCR+14*40+HINT_COL, TxtHn5a
        PUTS GAMESCR+15*40+HINT_COL+1, TxtHn5b
        PUTS GAMESCR+17*40+HINT_COL, TxtHn6a
        PUTS GAMESCR+18*40+HINT_COL+1, TxtHn6b
        lda DevMode
        beq SGS_nd
        PUTS GAMESCR+24*40+HINT_COL, TxtDev
SGS_nd  jsr SkillName
        lda #<(GAMESCR+22*40+HINT_COL)
        sta ptr2
        lda #>(GAMESCR+22*40+HINT_COL)
        sta ptr2+1
        jsr PutStr
        ; barvy, DL, PMG
        lda #COL_BG
        sta TxBk
        sta TxPf2
        lda #COL_TEXT
        sta TxPf1
        lda #<GameDL
        sta DlPtr
        lda #>GameDL
        sta DlPtr+1
        lda #1
        sta DliModeReq
        sta PmOn
        rts

; ramecek NEXT 6x6 (radky NEXT_ROW..+5, sloupce NEXT_COL..+5)
NextBox
        ldx #NEXT_ROW
        lda RowPtrLo,x
        sta ptr
        lda RowPtrHi,x
        sta ptr+1
        ldy #NEXT_COL
        lda #G_TL
        sta (ptr),y
        iny
        lda #G_HLINE
NB_t    sta (ptr),y
        iny
        cpy #NEXT_COL+5
        bne NB_t
        lda #G_TR
        sta (ptr),y
        ldx #NEXT_ROW+1
NB_v    lda RowPtrLo,x
        sta ptr
        lda RowPtrHi,x
        sta ptr+1
        lda #G_VLINE
        ldy #NEXT_COL
        sta (ptr),y
        ldy #NEXT_COL+5
        sta (ptr),y
        inx
        cpx #NEXT_ROW+5
        bne NB_v
        lda RowPtrLo,x
        sta ptr
        lda RowPtrHi,x
        sta ptr+1
        ldy #NEXT_COL
        lda #G_BL
        sta (ptr),y
        iny
        lda #G_HLINE
NB_b    sta (ptr),y
        iny
        cpy #NEXT_COL+5
        bne NB_b
        lda #G_BR
        sta (ptr),y
        rts

ClearGameScr
        lda #<GAMESCR
        sta ptr
        lda #>GAMESCR
        sta ptr+1
        ldx #5                      ; 5 stranek = 1280 B (>= 1040)
        lda #0
        tay
CGS_l   sta (ptr),y
        iny
        bne CGS_l
        inc ptr+1
        dex
        bne CGS_l
        rts

; PMG masky: P0 radky 1..23 (napoveda), P1 radky 8..23 (panel), P2/P3 radky 0..24 (studna)
; radek r zacina na scanline 16+8*r (8 prazdnych linek + 8 VBLANK offset)
InitPMG
        ldy #0
        tya
IP_c    sta PMAREA+$300,y
        sta PMAREA+$400,y
        sta PMAREA+$500,y
        sta PMAREA+$600,y
        sta PMAREA+$700,y
        iny
        bne IP_c
        ldx #16+8*1
IP_0    lda #$FF
        sta PMAREA+$400,x
        inx
        cpx #16+8*24
        bne IP_0
        ldx #16+8*8
IP_1    lda #$FF
        sta PMAREA+$500,x
        inx
        cpx #16+8*24
        bne IP_1
        lda #0
        sta PcHpos
        sta NxHpos
        lda #$FF
        sta PcPrevRow
        sta PcRow
        rts

; ---------------------------------------------------------------------
;  Player 2 = aktivni kostka: data hrace podle CurType/CurRot/CurX/CurY.
;  Hlavni kod jen pripravi PcBuf (32 scanlinu) + PcRow/PcHpos/PcCol; do pameti
;  hrace je prepise az VBI (jinak paprsek uprostred prepisu ukaze pul kostky
;  sede - videno v Altirre). Radek bunky r = scanline 16+8*r; bunka dx -> CellMask.
;  Vola se kazdy snimek z RenderGame (po DrawBoard), kostka je videt jen v ST_FALL.
; ---------------------------------------------------------------------
UpdatePiecePM
        ldx #31                     ; buffer vynulovat
        lda #0
UP_e    sta PcBuf,x
        dex
        bpl UP_e
        lda State
        cmp #ST_FALL
        beq UP_2
        lda #$FF
        sta PcRow
        rts
UP_2    jsr CurToTest
        jsr PieceIndex
        lda #4
        sta tmp4
UP_c    lda PieceTab,x
        :4 lsr
        asl
        asl
        asl
        sta tmp2                    ; prvni scanline bunky v bufferu
        lda PieceTab,x
        and #$0F
        stx tmp3
        tax
        lda CellMask,x
        sta tmp
        ldx tmp2
        ldy #8
UP_l    lda PcBuf,x
        ora tmp
        sta PcBuf,x
        inx
        dey
        bne UP_l
        ldx tmp3
        inx
        dec tmp4
        bne UP_c
        lda CurX
        clc
        adc #WELL_COL
        asl
        asl
        clc
        adc #48
        sta PcHpos
        ldx CurType
        lda PieceCol,x
        sta PcCol
        lda CurY
        asl
        asl
        asl
        clc
        adc #16
        sta PcRow                   ; VBI zkopiruje PcBuf sem
        rts

RenderGame
        jsr BuildComp
        jsr DrawBoard
        jsr UpdatePiecePM
        lda NextDirty
        beq RG_n
        lda #0
        sta NextDirty
        jsr DrawNext
RG_n    jsr DrawValues
        jsr DrawMessage
        lda Demo
        beq RG_d
        jsr BlinkOr
        PUTS GAMESCR+0*40+HINT_COL, TxtDemo
        lda #0
        sta TxtOr
RG_d    rts

; Comp = Board + padajici kus / blikajici rady
BuildComp
        ldy #239
BC_l    lda Board,y
        sta Comp,y
        dey
        cpy #$FF
        bne BC_l
        lda State
        cmp #ST_FALL
        bne BC_clear
        jsr CurToTest
        jsr CalcCells
        ldx #3
BC_p    ldy CellIdx,x
        lda CurType
        ora #ACTIVE
        sta Comp,y
        dex
        bpl BC_p
        rts
BC_clear
        cmp #ST_CLEAR
        bne BC_done
        lda FlashPhase
        beq BC_done
        ldx #0
BC_r    cpx FullCnt
        beq BC_done
        stx tmp4
        lda FullRows,x
        tax
        ldy RowOff10,x
        ldx #BW
        lda #WHITE
BC_w    sta Comp,y
        iny
        dex
        bne BC_w
        ldx tmp4
        inx
        jmp BC_r
BC_done rts

; Comp -> obrazovka (jen zmenene radky); bunka = G_SOLID, EMPTY/WHITE = mezera
DrawBoard
        lda #0
        sta celly
DB_row  ldx celly
        ldy RowOff10,x
        sty tmp2
        ldx #BW
DB_cmp  lda Comp,y
        cmp PrevComp,y
        bne DB_draw
        iny
        dex
        bne DB_cmp
        jmp DB_next
DB_draw ldx celly
        lda RowPtrLo,x
        sta ptr
        lda RowPtrHi,x
        sta ptr+1
        ldx #0
DB_c    txa
        clc
        adc tmp2
        tay
        lda Comp,y
        sta PrevComp,y
        cmp #EMPTY
        beq DB_e
        cmp #WHITE
        beq DB_e
        and #ACTIVE                 ; aktivni kostka: prazdno, vykresli ji player 2
        bne DB_e
        lda #G_SOLID
        bne DB_p
DB_e    lda #0
DB_p    sta tmp3
        txa
        clc
        adc #WELL_COL
        tay
        lda tmp3
        sta (ptr),y
        inx
        cpx #BW
        bne DB_c
DB_next inc celly
        lda celly
        cmp #BH
        bne DB_row
        rts

; nahled dalsiho kusu 1:1 ve vnitrku ramecku (4x4), spawn rotace, vycentrovany
DrawNext
        lda MenuSkill
        cmp #SK_EXP
        bne DN_go
        lda #0
        sta NxHpos
        rts
DN_go   ; vymaz vnitrek: radky NEXT_ROW+1..+4, sloupce NEXT_COL+1..+4
        ldx #NEXT_ROW+1
DN_clr  lda RowPtrLo,x
        sta ptr
        lda RowPtrHi,x
        sta ptr+1
        lda #0
        ldy #NEXT_COL+1
        sta (ptr),y
        iny
        sta (ptr),y
        iny
        sta (ptr),y
        iny
        sta (ptr),y
        inx
        cpx #NEXT_ROW+5
        bne DN_clr
        ; bounding box kusu (rotace 0)
        lda NextType
        asl
        asl
        asl
        asl
        tax
        lda #9
        sta tmp                     ; minx
        sta tmp3                    ; miny
        lda #0
        sta tmp2                    ; maxx
        sta tmp4                    ; maxy
        ldy #4
DN_bb   lda PieceTab,x
        and #$0F
        cmp tmp
        bcs DN_b1
        sta tmp
DN_b1   cmp tmp2
        bcc DN_b2
        sta tmp2
DN_b2   lda PieceTab,x
        :4 lsr
        cmp tmp3
        bcs DN_b3
        sta tmp3
DN_b3   cmp tmp4
        bcc DN_b4
        sta tmp4
DN_b4   inx
        dey
        bne DN_bb
        ; sloupec pro dx=0: NEXT_COL+1 + (3 - (maxx-minx))/2 - minx
        lda #3
        sec
        sbc tmp2
        clc
        adc tmp
        lsr
        sec
        sbc tmp
        clc
        adc #NEXT_COL+1
        sta cellx
        lda #3
        sec
        sbc tmp4
        clc
        adc tmp3
        lsr
        sec
        sbc tmp3
        clc
        adc #NEXT_ROW+1
        sta celly                   ; radek pro dy=0
        lda NextType
        asl
        asl
        asl
        asl
        tax
        lda #4
        sta tmp4
DN_cell lda PieceTab,x
        :4 lsr
        clc
        adc celly
        stx tmp2
        tax
        lda RowPtrLo,x
        sta ptr
        lda RowPtrHi,x
        sta ptr+1
        ldx tmp2
        lda PieceTab,x
        and #$0F
        clc
        adc cellx
        tay
        lda #0                      ; bunka prazdna, barvu dava player 3
        sta (ptr),y
        inx
        dec tmp4
        bne DN_cell
        ; player 3: pripravit NxBuf (radky NEXT_ROW+1..+4), do PMG kopiruje VBI
        ldx #31
        lda #0
DN_pe   sta NxBuf,x
        dex
        bpl DN_pe
        lda NextType
        asl
        asl
        asl
        asl
        tax
        lda #4
        sta tmp4
DN_pc   lda PieceTab,x
        :4 lsr
        clc
        adc celly                   ; radek obrazovky
        sec
        sbc #NEXT_ROW+1             ; -> 0..3 v bufferu
        asl
        asl
        asl
        sta tmp2
        lda PieceTab,x
        and #$0F
        stx tmp3
        tax
        lda CellMask,x
        sta tmp
        ldx tmp2
        ldy #8
DN_pl   lda NxBuf,x
        ora tmp
        sta NxBuf,x
        inx
        dey
        bne DN_pl
        ldx tmp3
        inx
        dec tmp4
        bne DN_pc
        lda cellx                   ; sloupec pro dx=0
        asl
        asl
        clc
        adc #48
        sta NxHpos
        ldx NextType
        lda PieceCol,x
        sta NxCol
        rts

; hodnoty panelu
DrawValues
        ldx #10
        jsr RowPtr2
        ldy #PAN_COL
        lda Level
        jsr PutDec2
        ldx #13
        jsr RowPtr2
        ldy #PAN_COL
        lda Score+2
        jsr PutBcd
        lda Score+1
        jsr PutBcd
        lda Score
        jsr PutBcd
        ldx #16
        jsr RowPtr2
        ldy #PAN_COL
        lda Lines+1
        jsr PutBcd
        lda Lines
        jsr PutBcd
        ldx #19
        jsr RowPtr2
        ldy #PAN_COL
        lda RowsInLevel
        jsr PutDec2
        lda #$0F                    ; '/'
        sta (ptr2),y
        iny
        lda RowsTarget
        jsr PutDec2
        ldx #22
        jsr RowPtr2
        ldy #PAN_COL
        lda TimeMin
        jsr PutBcd
        lda #$1A                    ; ':'
        sta (ptr2),y
        iny
        lda TimeSec
        jsr PutBcd
        rts

; X = radek -> ptr2 = adresa radku
RowPtr2
        lda RowPtrLo,x
        sta ptr2
        lda RowPtrHi,x
        sta ptr2+1
        rts

; A = BCD bajt, Y = sloupec -> (ptr2),y ; Y += 2
PutBcd
        pha
        :4 lsr
        ora #$10
        sta (ptr2),y
        iny
        pla
        and #$0F
        ora #$10
        sta (ptr2),y
        iny
        rts

; A = binarni 0..99, Y = sloupec -> (ptr2),y ; Y += 2
PutDec2
        sty tmp4
        ldy #0
        jsr Bin2Dec
        ldy tmp4
        lda tmp2
        ora #$10
        sta (ptr2),y
        iny
        lda tmp3
        ora #$10
        sta (ptr2),y
        iny
        rts

; A = 0..99 -> tmp2 = desitky, tmp3 = jednotky (Y musi byt 0)
Bin2Dec
B2D_l   cmp #10
        bcc B2D_d
        sbc #10
        iny
        jmp B2D_l
B2D_d   sta tmp3
        sty tmp2
        rts

; radek hlasek (MSG_ROW)
DrawMessage
        ldy #39
        lda #0
DM_c    sta MSG_ADDR,y
        dey
        bpl DM_c
        lda #0
        sta TxtOr
        lda Paused
        bne DM_paused
        lda MsgId
        cmp #MSG_LEVEL
        beq DM_level
        cmp #MSG_OVER
        beq DM_over
        lda Demo
        beq DM_done
        jsr BlinkOr
        PUTS MSG_ADDR+1, TxtMsgD
DM_done rts
DM_paused
        jsr BlinkSlow               ; pauza blika pomaleji nez DEMO
        PUTS MSG_ADDR+6, TxtMsgP
        rts
DM_level
        jsr BlinkOr
        PUTS MSG_ADDR+7, TxtMsgL
        rts
DM_over lda Demo
        bne DM_overd
        PUTS MSG_ADDR+4, TxtMsgO
        rts
DM_overd
        PUTS MSG_ADDR+15, TxtMsgOD
        rts

BlinkOr lda FrameCnt
        and #$10                    ; 16 snimku inverzne / 16 normalne
        bne BO_1
BO_0    sta TxtOr
        rts
BO_1    lda #$80
        bne BO_0
BlinkSlow
        lda FrameCnt
        and #$20                    ; 32 snimku inverzne / 32 normalne
        bne BO_1
        beq BO_0

; =====================================================================
;  Vstupy
; =====================================================================
ReadInputs
        ldy #0
        lda PORTA
        sta tmp
        lsr tmp
        bcs RI_1
        ldy #IN_UP
RI_1    lsr tmp
        bcs RI_2
        tya
        ora #IN_DOWN
        tay
RI_2    lsr tmp
        bcs RI_3
        tya
        ora #IN_LEFT
        tay
RI_3    lsr tmp
        bcs RI_4
        tya
        ora #IN_RIGHT
        tay
RI_4    lda TRIG0
        bne RI_5
        tya
        ora #IN_FIRE
        tay
RI_5    lda SKSTAT
        and #4
        bne RI_keyup
        lda KBCODE
        and #$3F
        sta KeyCode
        ldx #KEYMAPLEN-1
RI_kl   cmp KeyMapCode,x
        beq RI_kf
        dex
        bpl RI_kl
        bmi RI_6
RI_kf   tya
        ora KeyMapBit,x
        tay
        jmp RI_6
RI_keyup
        lda #$FF
        sta KeyCode
RI_6    sty InRaw
        lda #$FF
        sta KeyNew
        lda KeyPrev
        cmp #$FF
        bne RI_kp
        lda KeyCode
        sta KeyNew                  ; nova klavesa (predtim nic)
RI_kp   lda KeyCode
        sta KeyPrev
        lda InPrev
        eor #$FF
        and InRaw
        sta InNew
        lda InRaw
        sta InPrev
        lda CONSOL
        eor #$FF
        and #7
        sta ConsRaw
        lda ConsPrev
        eor #$FF
        and ConsRaw
        sta ConsNew
        lda ConsRaw
        sta ConsPrev
        rts

; ceka, az jsou vsechny vstupy v klidu
WaitRelease
        jsr WaitFrame
        jsr ReadInputs
        lda InRaw
        ora ConsRaw
        bne WaitRelease
        rts

WaitFrame
        lda FrameCnt
WF_l    cmp FrameCnt
        beq WF_l
        rts

; =====================================================================
;  Zvuk
; =====================================================================
; X = id -> spusti efekt na jeho kanalu
PlaySfx
        lda SfxChan,x
        tay
        lda #0
        sta SndPtrHi,y              ; nejdriv vypnout (VBI cte Hi jako priznak)
        sta SndCnt,y
        lda SfxLo,x
        sta SndPtrLo,y
        lda SfxHi,x
        sta SndPtrHi,y
        rts

SilenceAll
        ldx #3
        lda #0
SA_l    sta SndPtrHi,x
        sta SndCnt,x
        dex
        bpl SA_l
        sta AUDC1
        sta AUDC1+2
        sta AUDC1+4
        sta AUDC1+6
        rts

; volano z VBI - pouziva VYHRADNE sptr/stmp, protoze prerusi hlavni kod
; uprostred prace s ptr/ptr2/tmp* (jinak PutStr zapise mimo a hra spadne)
SoundTick
        ldx #3
ST_ch   lda SndPtrHi,x
        beq ST_next
        lda SndCnt,x
        beq ST_load
        dec SndCnt,x
        jmp ST_next
ST_load lda SndPtrLo,x
        sta sptr
        lda SndPtrHi,x
        sta sptr+1
        ldy #2
        lda (sptr),y
        beq ST_end
        sta SndCnt,x
        txa
        asl
        tay
        stx stmp
        tax
        ldy #0
        lda (sptr),y
        sta AUDF1,x
        iny
        lda (sptr),y
        sta AUDC1,x
        ldx stmp
        lda SndPtrLo,x
        clc
        adc #3
        sta SndPtrLo,x
        bcc ST_next
        inc SndPtrHi,x
        jmp ST_next
ST_end  lda #0
        sta SndPtrHi,x
        txa
        asl
        tay
        lda #0
        sta AUDC1,y
ST_next dex
        bpl ST_ch
        rts

; sfx tabulky: kanal + adresa dat
SfxChan .byte 0,0,1,1,2,2,2,3,2,0,0,1,0
SfxLo   .byte <SdMove,<SdRot,<SdDrop,<SdSoft,<SdLine,<SdTetris,<SdFanf1,<SdFanf2,<SdOver,<SdMenu,<SdSelect,<SdPause,<SdNoRot
SfxHi   .byte >SdMove,>SdRot,>SdDrop,>SdSoft,>SdLine,>SdTetris,>SdFanf1,>SdFanf2,>SdOver,>SdMenu,>SdSelect,>SdPause,>SdNoRot

; data: AUDF, AUDC, delka (snimky); delka 0 = konec
SdMove   .byte $40,$A4,2, 0,0,0
SdRot    .byte $30,$A6,2, $20,$A6,2, 0,0,0
SdNoRot  .byte $80,$C4,3, 0,0,0
SdDrop   .byte $60,$88,2, $FF,$86,3, $FF,$83,3, 0,0,0
SdSoft   .byte $70,$A2,1, 0,0,0
SdLine   .byte $60,$A8,3, $50,$A8,3, $40,$A8,3, $30,$A8,3, $20,$AA,5, 0,0,0
SdTetris .byte $60,$AA,3, $48,$AA,3, $40,$AA,3, $30,$AA,3, $24,$AA,3, $1E,$AC,4, $18,$AC,8, 0,0,0
SdFanf1  .byte $3C,$A8,8, $2F,$A8,8, $28,$A8,8, $1D,$AA,6, $28,$A6,4, $1D,$AC,24, $1D,$A6,10, $1D,$A3,10, 0,0,0
SdFanf2  .byte $79,$A6,8, $5F,$A6,8, $50,$A6,8, $3C,$A8,6, $50,$A4,4, $3C,$A8,24, $3C,$A4,10, $3C,$A2,10, 0,0,0
SdOver   .byte $28,$A8,10, $2F,$A8,10, $3C,$A8,10, $50,$A8,10, $79,$AA,25, $FF,$88,10, $FF,$85,10, $FF,$82,10, 0,0,0
SdMenu   .byte $28,$A4,1, $20,$A4,1, 0,0,0
SdSelect .byte $20,$A6,3, $10,$A8,5, 0,0,0
SdPause  .byte $40,$A6,3, $60,$A6,3, 0,0,0
; =====================================================================
;  Preruseni
; =====================================================================
Vbi
        cld
        inc FrameCnt
        lda #8
        sta CONSOL
        lda DlPtr
        sta DLISTL
        lda DlPtr+1
        sta DLISTH
        lda DliModeReq
        sta DliMode
        lda #$E0
        sta CHBASE
        lda #0
        sta DliCnt
        lda PmOn
        bne V_pmon
        jmp V_pmoff
V_pmon  lda #$3E                    ; DL + player/missile DMA, single-line
        sta DMACTL
        lda #>PMAREA
        sta PMBASE
        lda #3
        sta GRACTL
        lda #1                      ; playeri nad playfieldem = barevny filtr
        sta PRIOR
        lda #COL_HINT
        sta COLPM0
        lda #COL_PANEL
        sta COLPM0+1
        lda PcCol
        sta COLPM0+2
        lda NxCol
        sta COLPM0+3
        lda #48+4*(HINT_COL-1)      ; P0 quad: HINT_COL-1 .. +6
        sta HPOSP0
        lda #48+4*(PAN_COL-1)       ; P1 quad: PAN_COL-1 .. +6
        sta HPOSP0+1
        ; P2: smazat stare radky, zkopirovat PcBuf na PcRow (atomicky ve vblanku)
        ldx PcPrevRow
        cpx #$FF
        beq V_p2n
        lda #0
        ldy #32
V_p2e   sta PMAREA+$600,x
        inx
        dey
        bne V_p2e
V_p2n   ldx PcRow
        stx PcPrevRow
        cpx #$FF
        beq V_p2h
        ldy #0
V_p2c   lda PcBuf,y
        sta PMAREA+$600,x
        inx
        iny
        cpy #32
        bne V_p2c
        lda PcHpos                  ; P2 double: aktivni kostka (4 bunky)
        bne V_p2s
V_p2h   lda #0
V_p2s   sta HPOSP0+2
        ; P3: NEXT z NxBuf na pevne radky
        ldx #0
V_p3c   lda NxBuf,x
        sta PMAREA+$700+16+8*(NEXT_ROW+1),x
        inx
        cpx #32
        bne V_p3c
        lda NxHpos                  ; P3 double: kostka v NEXT
        sta HPOSP0+3
        lda #3
        sta SIZEP0
        sta SIZEP0+1
        lda #1
        sta SIZEP0+2
        sta SIZEP0+3
        jmp V_col
V_pmoff lda #$22
        sta DMACTL
        lda #0
        sta GRACTL
        sta PRIOR
        sta HPOSP0
        sta HPOSP0+1
        sta HPOSP0+2
        sta HPOSP0+3
V_col   lda TxBk
        sta COLBK
        lda TxPf0
        sta COLPF0
        lda TxPf1
        sta COLPF1
        lda TxPf2
        sta COLPF2
        lda TxPf3
        sta COLPF3
        jsr SoundTick
        jmp XITVBV

Dli
        pha
        txa
        pha
        tya
        pha
        cld
        lda DliMode
        beq Dli_title
        jmp Dli_out                 ; herni obrazovka DLI nepouziva
Dli_title
        lda FrameCnt
        lsr
        and #31
        tax
        ldy #16
Dli_rb  lda Rainbow,x
        sta WSYNC
        sta COLPF0
        inx
        txa
        and #31
        tax
        dey
        bne Dli_rb
        sta WSYNC
        lda TxPf0
        sta COLPF0
Dli_out
        pla
        tay
        pla
        tax
        pla
        rti

; ---------------------------------------------------------------------
;  Vypis retezce (ptr -> retezec $FF-ukonceny, ptr2 -> cil), OR TxtOr
; ---------------------------------------------------------------------
PutStr
        ldy #0
PS_l    lda (ptr),y
        cmp #$FF
        beq PS_e
        ora TxtOr
        sta (ptr2),y
        iny
        bne PS_l
PS_e    rts

; =====================================================================
;  Display listy
; =====================================================================
        org $7000
GameDL
        .byte $70                   ; 8 prazdnych linek nahore
        .byte $42
        dta a(GAMESCR)              ; radek 0
        :25 .byte $02               ; radky 1..25
        .byte $41
        dta a(GameDL)

        org $7100
MenuDL
        .byte $70,$70,$F0           ; 24 prazdnych, DLI (duha titulku)
        .byte $47
        dta a(MENU_TITLE)           ; mode 7: TETRIS
        .byte $70
        .byte $46
        dta a(MENU_SUB)             ; mode 6: podtitul
        .byte $70,$70
        .byte $46
        dta a(MENU_IT0)
        .byte $70
        .byte $46
        dta a(MENU_IT1)
        .byte $70
        .byte $46
        dta a(MENU_IT2)
        .byte $70
        .byte $46
        dta a(MENU_IT3)
        .byte $70
        .byte $42
        dta a(MENU_H0)
        .byte $42
        dta a(MENU_H1)
        .byte $42
        dta a(MENU_H2)
        .byte $42
        dta a(MENU_H3)
        .byte $70
        .byte $42
        dta a(MENU_CR)
        .byte $41
        dta a(MenuDL)

        run start
