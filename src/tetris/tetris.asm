; =====================================================================
;  TETRIS pro Atari XL/XE (6502, MADS assembler)
;
;  - Uvodni obrazovka + menu (start, volba levelu, obtiznost BASIC/EXPERT)
;  - Po ~15 s necinnosti v menu se spusti DEMO (AI simuluje prumerneho
;    hrace); jakykoliv vstup (joystick, klavesa, START/SELECT/OPTION)
;    demo ukonci a vrati se do menu.
;  - Herni plocha 10x20 v rezimu GTIA 10 (9 barev) -> kazdy tvar ma svou
;    klasickou barvu (I cyan, O zluta, T fialova, S zelena, Z cervena,
;    J modra, L oranzova). Texty v ANTIC mode 2 nad/pod plochou.
;  - Level je splnen, kdyz se plocha uplne vyprazdni (styl Tetris Pro):
;    kazdy level zacina s nekolika radky "smeti" a hra zrychluje.
;  - Zvuky: pohyb, rotace, drop, mazani rad, fanfara, game over.
;
;  Ovladani: joystick / sipky = pohyb, FIRE / sipka nahoru / Z = rotace,
;            dolu = soft drop, MEZERNIK = hard drop, ESC = menu,
;            START nebo P = pauza. V menu: SELECT = level, OPTION = skill.
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
;  Pamet obrazovek
; ---------------------------------------------------------------------
BITMAP     = $5010         ; 162 radku x 40 B (ANTIC F + GTIA mode 10, 80 px/radek)
BMLINES    = 162
BITMAP102  = BITMAP+102*40 ; = $6000, hranice 4K -> zde druhy LMS

MENUSCR    = $6A00
MENU_TITLE = MENUSCR       ; mode 7 (20 B)
MENU_SUB   = MENUSCR+$20   ; mode 6 (20 B)
MENU_IT0   = MENUSCR+$40   ; mode 6 polozky menu
MENU_IT1   = MENUSCR+$60
MENU_IT2   = MENUSCR+$80
MENU_H0    = MENUSCR+$100  ; mode 2 (40 B) napoveda
MENU_H1    = MENUSCR+$128
MENU_H2    = MENUSCR+$150
MENU_H3    = MENUSCR+$178
MENU_CR    = MENUSCR+$1A0

GAMETXT    = $6E00
GT_HDR     = GAMETXT       ; hlavicka SCORE/LINES/LEVEL/NEXT
GT_VAL     = GAMETXT+40    ; hodnoty
GT_BOT     = GAMETXT+80    ; spodni hlaska

; ---------------------------------------------------------------------
;  Herni konstanty
; ---------------------------------------------------------------------
BW        = 10             ; sirka plochy
BH        = 20             ; vyska plochy
EMPTY     = 8              ; prazdna bunka (pixel = COLBK)
WHITE     = 7              ; bila (steny, blikani rad)
BX        = 14             ; bajt v radku bitmapy, kde zacina plocha (1 bunka = 1 bajt = 2 GTIA px)
NEXTBX    = 30             ; bajt, kde zacina nahled NEXT (bunka 2 bajty x 16 scanlines)
NEXTLINE  = 8              ; prvni scanline nahledu NEXT

MAXLEVEL  = 20
MAXSEL    = 15             ; nejvyssi level volitelny v menu

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
IdleLo    .byte 0
IdleHi    .byte 0

MenuSel   .byte 0
MenuLevel .byte 1
MenuSkill .byte 0          ; 0 = BASIC, 1 = EXPERT

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

Board     :200 .byte EMPTY
Comp      :200 .byte EMPTY
PrevComp  :200 .byte $FF   ; naposledy vykresleny stav (pro preskoceni nezmenenych radku)

; ---------------------------------------------------------------------
;  Tabulky
; ---------------------------------------------------------------------
; radek plochy -> index (y*10)
RowOff10  .byte 0,10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160,170,180,190

; radek plochy -> adresa prvni scanline v bitmape (BITMAP + y*320)
RowPtrLo  .byte <(BITMAP+0*320),<(BITMAP+1*320),<(BITMAP+2*320),<(BITMAP+3*320),<(BITMAP+4*320)
          .byte <(BITMAP+5*320),<(BITMAP+6*320),<(BITMAP+7*320),<(BITMAP+8*320),<(BITMAP+9*320)
          .byte <(BITMAP+10*320),<(BITMAP+11*320),<(BITMAP+12*320),<(BITMAP+13*320),<(BITMAP+14*320)
          .byte <(BITMAP+15*320),<(BITMAP+16*320),<(BITMAP+17*320),<(BITMAP+18*320),<(BITMAP+19*320)
RowPtrHi  .byte >(BITMAP+0*320),>(BITMAP+1*320),>(BITMAP+2*320),>(BITMAP+3*320),>(BITMAP+4*320)
          .byte >(BITMAP+5*320),>(BITMAP+6*320),>(BITMAP+7*320),>(BITMAP+8*320),>(BITMAP+9*320)
          .byte >(BITMAP+10*320),>(BITMAP+11*320),>(BITMAP+12*320),>(BITMAP+13*320),>(BITMAP+14*320)
          .byte >(BITMAP+15*320),>(BITMAP+16*320),>(BITMAP+17*320),>(BITMAP+18*320),>(BITMAP+19*320)

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
Nib2      .byte $00,$11,$22,$33,$44,$55,$66,$77,$88   ; hodnota bunky -> oba nibbly bajtu
KickTab   .byte 0,$FF,1,$FE,2       ; wall kick posuny

; barvy plochy: pixel 0-3 -> COLPM0-3, 4-7 -> COLPF0-3, 8 -> COLBK
BoardCols .byte $9C,$1C,$5A,$C8,$34,$84,$28,$0E,$00
;               I   O   T   S   Z   J   L  bila cerna

; rychlost (snimku na 1 radek padu) pro level 1..20
SpeedTab  .byte 0,40,36,32,28,24,20,17,14,12,10,8,7,6,5,4,4,3,3,2,2
; pocet radku smeti na startu levelu
GarbTab   .byte 0,2,2,3,3,4,4,5,5,6,6,7,7,8,8,8,8,8,8,8,8

; skore za 1..4 rad (BCD, x level)
LineScLo  .byte 0,$40,$00,$00,$00
LineScHi  .byte 0,$00,$01,$03,$12

Rainbow   .byte $1A,$1C,$2A,$2C,$3A,$3C,$4A,$4C,$5A,$5C,$6A,$6C,$7A,$7C,$8A,$8C
          .byte $9A,$9C,$AA,$AC,$BA,$BC,$CA,$CC,$DA,$DC,$EA,$EC,$FA,$FC,$0A,$0E

; klavesy (KBCODE & $3F) -> bity vstupu
KeyMapCode .byte $06,$07,$0E,$0F,$21,$1C,$0A,$17,$16,$0C
KeyMapBit  .byte IN_LEFT,IN_RIGHT,IN_UP,IN_DOWN,IN_HARD,IN_ESC,IN_PAUSE,IN_FIRE,IN_UP,IN_FIRE
KEYMAPLEN  = 10

; pismena D E M O (5x7 bodu, bit 4 = levy sloupec) pro velky napis v demu
DemoFont  .byte %11110,%10001,%10001,%10001,%10001,%10001,%11110
          .byte %11111,%10000,%10000,%11110,%10000,%10000,%11111
          .byte %10001,%11011,%10101,%10101,%10001,%10001,%10001
          .byte %01110,%10001,%10001,%10001,%10001,%10001,%01110

; ---------------------------------------------------------------------
;  Texty (screen kody, ukonceno $FF)
; ---------------------------------------------------------------------
TxtTitle  dta d'TETRIS',$FF
TxtSub    dta d'ATARI XL/XE EDITION',$FF
TxtPress  dta d'PRESS START OR FIRE',$FF
TxtItem0  dta d'START GAME',$FF
TxtItem1  dta d'LEVEL',$FF
TxtItem2  dta d'SKILL',$FF
TxtBasic  dta d'BASIC ',$FF
TxtExpert dta d'EXPERT',$FF
TxtArrow  dta d'>',$FF
TxtW0     dta d'CLASSIC TETRIS FOR ATARI XL/XE',$FF
TxtW1     dta d'CLEAR THE WHOLE WELL TO FINISH A LEVEL',$FF
TxtW2     dta d'EXPERT SKILL HIDES THE NEXT PIECE',$FF
TxtW3     dta d'WAIT A WHILE TO WATCH THE DEMO',$FF
TxtH0     dta d'STICK/ARROWS MOVE     FIRE/UP/Z ROTATE',$FF
TxtH1     dta d'DOWN SOFT DROP        SPACE HARD DROP',$FF
TxtH2     dta d'SELECT LEVEL   OPTION SKILL   ESC MENU',$FF
TxtH3     dta d'PRESS START OR FIRE TO PLAY',$FF
TxtCr     dta d'(C) 2026 BYPS - MADS ASSEMBLER',$FF
TxtHdr    dta d'SCORE        LINES     LEVEL',$FF
TxtNext   dta d'NEXT',$FF
TxtMsgN   dta d'ESC MENU   START/P PAUSE   SKILL ',$FF
TxtMsgD   dta d'  DEMO PLAY - MOVE STICK OR PRESS A KEY ',$FF
TxtMsgP   dta d'PAUSED - PRESS START OR P TO CONTINUE',$FF
TxtMsgL   dta d'WELL CLEARED! LEVEL COMPLETE - GET READY',$FF
TxtMsgO   dta d'GAME OVER - PRESS FIRE OR START',$FF
TxtMsgOD  dta d'GAME OVER',$FF

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
        jsr ClearBitmap
        jsr SetMenuScreen
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
        PUTS MENU_H2+3, TxtW2
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
        jsr SetMenuScreen
        jsr WaitRelease
        lda #0
        sta TxtOr
        sta MenuSel
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
        bne MS_demo
        lda InNew
        and #IN_UP
        beq MS_1
        dec MenuSel
        bpl MS_snd
        lda #2
        sta MenuSel
MS_snd  SFX SFX_MENU
MS_1    lda InNew
        and #IN_DOWN
        beq MS_2
        inc MenuSel
        lda MenuSel
        cmp #3
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
        jsr MenuAdjUp
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
        beq SkillToggle
        rts
LevelUp
        inc MenuLevel
        lda MenuLevel
        cmp #MAXSEL+1
        bcc LU_ok
        lda #1
        sta MenuLevel
LU_ok   SFX SFX_MENU
        rts
LevelDown
        dec MenuLevel
        bne LD_ok
        lda #MAXSEL
        sta MenuLevel
LD_ok   SFX SFX_MENU
        rts
SkillToggle
        lda MenuSkill
        eor #1
        sta MenuSkill
        SFX SFX_MENU
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
        lda MenuSkill
        bne DMI_exp
        PUTS MENU_IT2+12, TxtBasic
        jmp DMI_arrow
DMI_exp PUTS MENU_IT2+12, TxtExpert
DMI_arrow
        ; sipka na vybranou polozku (blika)
        lda FrameCnt
        and #$08
        bne DMI_done
        lda MenuSel
        beq DMI_a0
        cmp #1
        beq DMI_a1
        PUTS MENU_IT2+1, TxtArrow
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
        jsr ClearBoard
        jsr FillGarbage
        jsr SetLevelSpeed
        jsr RandomPiece
        sta NextType
        lda #1
        sta NextDirty
        rts

SetLevelSpeed
        ldx Level
        lda SpeedTab,x
        sta GravSpeed
        sta GravCnt
        rts

ClearBoard
        ldy #199
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

; smeti na dne plochy podle levelu
FillGarbage
        ldx Level
        lda GarbTab,x
        beq FG_done
        sta tmp4                    ; pocet radku
        lda #BH
        sec
        sbc tmp4
        sta celly                   ; prvni radek smeti
FG_row  ldx celly
        lda RowOff10,x
        sta tmp3                    ; index zacatku radku
FG_try  lda #0
        sta tmp2                    ; pocet plnych
        ldy tmp3
        ldx #0
FG_cell lda RANDOM
        cmp #$A0
        bcs FG_emp
        jsr Rnd7
        sta Board,y
        inc tmp2
        jmp FG_nx
FG_emp  lda #EMPTY
        sta Board,y
FG_nx   iny
        inx
        cpx #BW
        bne FG_cell
        lda tmp2
        cmp #BW
        beq FG_try                  ; plny radek -> znovu
        cmp #3
        bcc FG_try                  ; prilis prazdny -> znovu
        inc celly
        lda celly
        cmp #BH
        bne FG_row
FG_done rts

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
FS_2    lda InNew
        and #IN_PAUSE
        bne FS_tog
        lda ConsNew
        and #CS_START
        beq FS_done
FS_tog  lda Paused
        eor #1
        sta Paused
        SFX SFX_PAUSE
FS_done rts

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
        lda FlashCnt
        cmp #24
        bcc SC_done
        jsr RemoveFullRows
        jsr ScoreLines
        jsr FindFull
        lda FullCnt
        beq SC_nomore
        lda #0
        sta FlashCnt
        SFX SFX_LINE
        rts
SC_nomore
        jsr BoardEmpty
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
        ; Score += LineSc[FullCnt] * Level
        ldx FullCnt
        lda LineScLo,x
        sta tmp
        lda LineScHi,x
        sta tmp2
        ldx Level
SL_mul  jsr AddScore
        dex
        bne SL_mul
        rts

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

; carry = 1 kdyz je plocha prazdna
BoardEmpty
        ldy #199
BE_l    lda Board,y
        cmp #EMPTY
        bne BE_no
        dey
        cpy #$FF
        bne BE_l
        sec
        rts
BE_no   clc
        rts

; ---------------------------------------------------------------------
;  Level dokoncen (plocha prazdna)
; ---------------------------------------------------------------------
LevelDoneSeq
        lda #ST_SPAWN
        sta State
        lda #MSG_LEVEL
        sta MsgId
        SFX SFX_FANF1
        SFX SFX_FANF2
        ; bonus 1000 x level
        lda #$00
        sta tmp
        lda #$10
        sta tmp2
        ldx Level
LDS_b   jsr AddScore
        dex
        bne LDS_b
        lda #150
        sta SeqCnt
LDS_l   jsr FrameStep
        lda AbortFlag
        bne LDS_x
        jsr RenderGame
        dec SeqCnt
        bne LDS_l
        lda Level
        cmp #MAXLEVEL
        bcs LDS_nl
        inc Level
LDS_nl  jsr SetLevelSpeed
        jsr FillGarbage
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
        ; plocha se odspodu zaplni bilou
        lda #BH-1
        sta SeqRow
GOS_fill
        ldx SeqRow
        ldy RowOff10,x
        ldx #BW
        lda #WHITE
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
        jsr ClearBitmap
        jsr DrawWalls
        ldy #199
        lda #$FF
SGS_p   sta PrevComp,y
        dey
        cpy #$FF
        bne SGS_p
        ldy #119
        lda #0
SGS_c   sta GAMETXT,y
        dey
        bpl SGS_c
        lda #0
        sta TxtOr
        PUTS GT_HDR+1, TxtHdr
        lda MenuSkill
        bne SGS_exp
        PUTS GT_HDR+32, TxtNext
SGS_exp lda #$00
        sta TxBk
        lda #$82
        sta TxPf2
        lda #$0E
        sta TxPf1
        lda #<GameDL
        sta DlPtr
        lda #>GameDL
        sta DlPtr+1
        lda #1
        sta DliModeReq
        rts

ClearBitmap
        lda #<$5000
        sta ptr
        lda #>$5000
        sta ptr+1
        ldx #26                     ; $5000-$69FF
        lda #$88
        ldy #0
CBM_l   sta (ptr),y
        iny
        bne CBM_l
        inc ptr+1
        dex
        bne CBM_l
        rts

; bile steny (bajt 13 a 24) + podlaha (radky 160,161)
DrawWalls
        lda #<BITMAP
        sta ptr
        lda #>BITMAP
        sta ptr+1
        ldx #160
DW_l    lda #$77
        ldy #BX-1
        sta (ptr),y
        ldy #BX+BW
        sta (ptr),y
        jsr PtrAdd40
        dex
        bne DW_l
        ldx #2
DW_f    ldy #BX-1
        lda #$77
DW_fc   sta (ptr),y
        iny
        cpy #BX+BW+1
        bne DW_fc
        jsr PtrAdd40
        dex
        bne DW_f
        rts

PtrAdd40
        lda ptr
        clc
        adc #40
        sta ptr
        bcc PA_r
        inc ptr+1
PA_r    rts

RenderGame
        jsr BuildComp
        jsr DrawBoard
        lda NextDirty
        beq RG_n
        lda #0
        sta NextDirty
        jsr DrawNext
RG_n    jsr DrawValues
        jsr DrawMessage
        lda Demo
        beq RG_d
        jsr DrawDemoSign
RG_d    rts

; Comp = Board + padajici kus / blikajici rady
BuildComp
        ldy #199
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

; Comp -> bitmapa (kazda bunka 1 bajt x 7 scanlines + 1 mezera)
DrawBoard
        lda #0
        sta celly
DB_row  ldx celly
        ldy RowOff10,x
        ; zmenil se radek?
        lda Comp,y
        cmp PrevComp,y
        bne DB_draw
        lda Comp+1,y
        cmp PrevComp+1,y
        bne DB_draw
        lda Comp+2,y
        cmp PrevComp+2,y
        bne DB_draw
        lda Comp+3,y
        cmp PrevComp+3,y
        bne DB_draw
        lda Comp+4,y
        cmp PrevComp+4,y
        bne DB_draw
        lda Comp+5,y
        cmp PrevComp+5,y
        bne DB_draw
        lda Comp+6,y
        cmp PrevComp+6,y
        bne DB_draw
        lda Comp+7,y
        cmp PrevComp+7,y
        bne DB_draw
        lda Comp+8,y
        cmp PrevComp+8,y
        bne DB_draw
        lda Comp+9,y
        cmp PrevComp+9,y
        bne DB_draw
        jmp DB_next
DB_draw lda RowPtrLo,x
        sta ptr
        lda RowPtrHi,x
        sta ptr+1
        ldx Comp,y
        lda Nib2,x
        sta RowBuf
        ldx Comp+1,y
        lda Nib2,x
        sta RowBuf+1
        ldx Comp+2,y
        lda Nib2,x
        sta RowBuf+2
        ldx Comp+3,y
        lda Nib2,x
        sta RowBuf+3
        ldx Comp+4,y
        lda Nib2,x
        sta RowBuf+4
        ldx Comp+5,y
        lda Nib2,x
        sta RowBuf+5
        ldx Comp+6,y
        lda Nib2,x
        sta RowBuf+6
        ldx Comp+7,y
        lda Nib2,x
        sta RowBuf+7
        ldx Comp+8,y
        lda Nib2,x
        sta RowBuf+8
        ldx Comp+9,y
        lda Nib2,x
        sta RowBuf+9
        lda #7
        sta tmp
DB_line ldy #BX
        lda RowBuf
        sta (ptr),y
        iny
        lda RowBuf+1
        sta (ptr),y
        iny
        lda RowBuf+2
        sta (ptr),y
        iny
        lda RowBuf+3
        sta (ptr),y
        iny
        lda RowBuf+4
        sta (ptr),y
        iny
        lda RowBuf+5
        sta (ptr),y
        iny
        lda RowBuf+6
        sta (ptr),y
        iny
        lda RowBuf+7
        sta (ptr),y
        iny
        lda RowBuf+8
        sta (ptr),y
        iny
        lda RowBuf+9
        sta (ptr),y
        iny
        jsr PtrAdd40
        dec tmp
        bne DB_line
        ; zapamatuj vykresleny radek
        ldx celly
        ldy RowOff10,x
        ldx #BW
DB_cp   lda Comp,y
        sta PrevComp,y
        iny
        dex
        bne DB_cp
DB_next inc celly
        lda celly
        cmp #BH
        beq DB_done
        jmp DB_row
DB_done rts

; nahled dalsiho kusu (bunka 2 bajty x 14 scanlines), jen v BASIC
DrawNext
        lda #<(BITMAP+NEXTLINE*40)
        sta ptr
        lda #>(BITMAP+NEXTLINE*40)
        sta ptr+1
        ldx #64
DN_clr  ldy #NEXTBX
        lda #$88
DN_c2   sta (ptr),y
        iny
        cpy #NEXTBX+8
        bne DN_c2
        jsr PtrAdd40
        dex
        bne DN_clr
        lda MenuSkill
        bne DN_done
        ldx NextType
        lda Nib2,x
        sta tmp3                    ; barva v obou nibblech
        lda NextType
        asl
        asl
        asl
        asl
        tax                         ; index do PieceTab, rotace 0
        lda #4
        sta tmp4
DN_cell lda PieceTab,x
        and #$0F
        asl
        clc
        adc #NEXTBX
        sta cellx
        lda PieceTab,x
        :4 lsr
        asl
        asl
        asl
        asl
        clc
        adc #NEXTLINE
        jsr LinePtr                 ; ptr = BITMAP + (NEXTLINE + dy*16) * 40
        stx tmp2
        ldx #14
DN_ln   ldy cellx
        lda tmp3
        sta (ptr),y
        iny
        sta (ptr),y
        jsr PtrAdd40
        dex
        bne DN_ln
        ldx tmp2
        inx
        dec tmp4
        bne DN_cell
DN_done rts

; A = cislo scanline -> ptr = BITMAP + A*40
LinePtr
        sta tmp
        lda #0
        sta ptr+1
        lda tmp
        asl
        rol ptr+1
        asl
        rol ptr+1
        asl
        rol ptr+1                   ; A = 8*line (lo), ptr+1 = hi
        sta ptr
        lda ptr+1
        sta tmp2
        lda ptr
        asl
        rol tmp2
        asl
        rol tmp2                    ; 32*line
        clc
        adc ptr                     ; 32+8 = 40
        sta ptr
        lda tmp2
        adc ptr+1
        sta ptr+1
        lda ptr
        clc
        adc #<BITMAP
        sta ptr
        lda ptr+1
        adc #>BITMAP
        sta ptr+1
        rts

; velky blikajici napis DEMO vlevo od plochy (bajty 4..8, 5x7 bodu, bod = 1 bajt x 4 scanlines)
DrawDemoSign
        lda #$88
        sta tmp3                    ; zhasnuto
        lda FrameCnt
        and #$10
        bne DDS_go
        lda #$77
        sta tmp3
DDS_go  lda #12
        sta celly                   ; scanline
        ldx #0                      ; index do DemoFont (0..27)
DDS_row lda DemoFont,x
        sta cellx                   ; vzor radku (5 bitu)
        stx tmp4
        lda celly
        jsr LinePtr
        ldx #4
DDS_bit lda #$88
        lsr cellx
        bcc DDS_nb
        lda tmp3
DDS_nb  sta RowBuf,x
        dex
        bpl DDS_bit
        ldx #4
DDS_l   ldy #4
        lda RowBuf
        sta (ptr),y
        iny
        lda RowBuf+1
        sta (ptr),y
        iny
        lda RowBuf+2
        sta (ptr),y
        iny
        lda RowBuf+3
        sta (ptr),y
        iny
        lda RowBuf+4
        sta (ptr),y
        jsr PtrAdd40
        dex
        bne DDS_l
        lda celly
        clc
        adc #4
        sta celly
        ldx tmp4
        inx
        cpx #28
        beq DDS_done
        cpx #7
        beq DDS_gap
        cpx #14
        beq DDS_gap
        cpx #21
        beq DDS_gap
        jmp DDS_row
DDS_gap lda celly
        clc
        adc #8
        sta celly
        jmp DDS_row
DDS_done
        rts

; hodnoty SCORE / LINES / LEVEL do radku GT_VAL
DrawValues
        lda #0
        sta TxtOr
        ldy #1
        lda Score+2
        jsr PutBcd
        lda Score+1
        jsr PutBcd
        lda Score
        jsr PutBcd
        ldy #14
        lda Lines+1
        jsr PutBcd
        lda Lines
        jsr PutBcd
        ldy #24
        lda Level
        jsr PutDec2
        rts

; A = BCD bajt, Y = sloupec v GT_VAL
PutBcd
        pha
        :4 lsr
        ora #$10
        sta GT_VAL,y
        iny
        pla
        and #$0F
        ora #$10
        sta GT_VAL,y
        iny
        rts

; A = binarni 0..99, Y = sloupec v GT_VAL
PutDec2
        sty tmp4
        ldy #0
        jsr Bin2Dec
        ldy tmp4
        lda tmp2
        ora #$10
        sta GT_VAL,y
        iny
        lda tmp3
        ora #$10
        sta GT_VAL,y
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

; spodni radek s hlaskou
DrawMessage
        ldy #39
        lda #0
DM_c    sta GT_BOT,y
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
        beq DM_norm
        jmp DM_demo
DM_norm PUTS GT_BOT+1, TxtMsgN
        lda MenuSkill
        bne DM_exp
        PUTS GT_BOT+34, TxtBasic
        rts
DM_exp  PUTS GT_BOT+34, TxtExpert
        rts
DM_paused
        PUTS GT_BOT+1, TxtMsgP
        rts
DM_level
        jsr BlinkOr
        PUTS GT_BOT, TxtMsgL
        rts
DM_over lda Demo
        bne DM_overd
        PUTS GT_BOT+4, TxtMsgO
        rts
DM_overd
        PUTS GT_BOT+15, TxtMsgOD
        rts
DM_demo jsr BlinkOr
        PUTS GT_BOT, TxtMsgD
        rts

BlinkOr lda FrameCnt
        and #$10
        beq BO_0
        lda #$80
BO_0    sta TxtOr
        rts

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

; volano z VBI
SoundTick
        ldx #3
ST_ch   lda SndPtrHi,x
        beq ST_next
        lda SndCnt,x
        beq ST_load
        dec SndCnt,x
        jmp ST_next
ST_load lda SndPtrLo,x
        sta ptr2
        lda SndPtrHi,x
        sta ptr2+1
        ldy #2
        lda (ptr2),y
        beq ST_end
        sta SndCnt,x
        txa
        asl
        tay
        stx tmp4
        tax
        ldy #0
        lda (ptr2),y
        sta AUDF1,x
        iny
        lda (ptr2),y
        sta AUDC1,x
        ldx tmp4
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
        lda #$22
        sta DMACTL
        lda #0
        sta PRIOR
        sta DliCnt
        lda TxBk
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
        lda DliCnt
        bne Dli_end
        inc DliCnt
        sta WSYNC
        lda #$80
        sta PRIOR
        ldx #8
Dli_col lda BoardCols,x
        sta COLPM0,x
        dex
        bpl Dli_col
        jmp Dli_out
Dli_end
        sta WSYNC
        lda #0
        sta PRIOR
        lda TxPf1
        sta COLPF1
        lda TxPf2
        sta COLPF2
        lda TxBk
        sta COLBK
        jmp Dli_out
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
        .byte $70                   ; 8 prazdnych radku
        .byte $42
        dta a(GT_HDR)               ; hlavicka (mode 2)
        .byte $C2
        dta a(GT_VAL)               ; hodnoty + DLI (prepnuti na GTIA)
        .byte $00                   ; 1 prazdna scanline
        .byte $4F
        dta a(BITMAP)               ; radek 0
        :101 .byte $0F              ; radky 1..101
        .byte $4F
        dta a(BITMAP102)            ; radek 102 (hranice 4K)
        :58 .byte $0F               ; radky 103..160
        .byte $8F                   ; radek 161 + DLI (zpet na text)
        .byte $00
        .byte $42
        dta a(GT_BOT)
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
        .byte $70,$70
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
