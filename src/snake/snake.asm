; =====================================================================
;  SNAKE pro Atari XL/XE (6502, MADS assembler)
;
;  - Vlastni znakova sada: had z glyfu 6 px silnych, ktere navazuji
;    v zatackach (snake_font.inc generuje gen_font.py), ohrada z ramecovych
;    znaku ROM, titulek v ANTIC mode 6 (menu ma vlastni display list).
;  - Zvuky jako tabulky AUDF/AUDC po snimcich prehravane ve VBI (krup pri
;    sezrani, alert pri zakazane otocce, ton pri game over).
;  - Pauza P / START, ESC = konec hry.
;
;  - Menu (START GAME / ABOUT), hra, obrazovka GAME OVER.
;  - Graphics 0 (ANTIC mode 2) s vlastnim display listem, vlastni VBI
;    (citac snimku, barvy, zvuk). OS shadow registry se nepouzivaji,
;    vsechno se cte primo z HW (PORTA, TRIG0, KBCODE/SKSTAT) - diky tomu
;    hra bezi i v headless harnessu ../tetris/tools/emu.py (bez OS).
;  - Hraci plocha 40x24: radek 0 = skore, radky 1-23 = ohrada (inverzni
;    mezera), uvnitr 38x21 policek. Had se kresli inkrementalne (smaze se
;    ocas, prikresli hlava), kolize se detekuji ctenim videopameti.
;  - Rychlost roste s kazdym tretim sezranym jablkem (SPEED_STEP).
;
;  Ovladani: joystick / sipky (CTRL + - = + *), FIRE / RETURN / MEZERNIK
;            = potvrzeni v menu, P / START = pauza, ESC = zpet do menu.
;
;  Build:  mads snake.asm -o:snake.xex -t:snake.lab   (viz make.bat)
;  Test:   python test_snake.py                        (harness emu.py)
; =====================================================================

; ---------------------------------------------------------------------
;  Hardware / OS
; ---------------------------------------------------------------------
DMACTL   = $D400
DLISTL   = $D402
DLISTH   = $D403
CHBASE   = $D409
NMIEN    = $D40E
VVBLKI   = $0222
XITVBV   = $E462

TRIG0    = $D010
COLPF0   = $D016
COLPF1   = $D017
COLPF2   = $D018
COLPF3   = $D019
COLBK    = $D01A
GRACTL   = $D01D
HPOSP0   = $D000
SIZEP0   = $D008
COLPM0   = $D012
PRIOR    = $D01B
PMBASE   = $D407
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
;  Konstanty
; ---------------------------------------------------------------------
SCREEN   = $3000           ; 40x24 = 960 bajtu videopameti
FONT     = $3400           ; kopie ROM fontu + glyfy hada (1 KB, zarovnano)
ROMFONT  = $E000
PMAREA   = $3800           ; PMG single-line (2 KB zarovnano); P0 data na +$400
P0DATA   = PMAREA+$400
P1DATA   = PMAREA+$500
PM_Y0    = 32              ; index radku 0 v datech hrace (8 + 3x8 prazdnych radku DL)
SCREEN_W = 40
SCREEN_H = 24

FIELD_X0 = 1               ; vnitrek ohrady (vcetne)
FIELD_X1 = 38
FIELD_Y0 = 2
FIELD_Y1 = 22

MAX_LEN     = 200          ; max. delka hada (segmentu)
START_LEN   = 3
START_DELAY = 10           ; snimku mezi kroky na zacatku
MIN_DELAY   = 3
SPEED_STEP  = 3            ; kazde N-te jablko zrychli o 1 snimek

; znaky ve videopameti (interni kody!)
CH_SPACE = $00
CH_APPLE = $6E             ; glyf jablka (snake_font.inc)
GLYPH0   = $60             ; prvni glyf hada v znakove sade
; ramecek z ROM znaku (ATASCII CTRL-Q/E/Z/C/R a '|')
CH_TL    = $51             ; rohy
CH_TR    = $45
CH_BL    = $5A
CH_BR    = $43
CH_HOR   = $52
CH_VER   = $7C

; bity vstupu (InRaw / InNew)
IN_UP    = $01
IN_DOWN  = $02
IN_LEFT  = $04
IN_RIGHT = $08
IN_FIRE  = $10
IN_ESC   = $20
IN_PAUSE = $40             ; P nebo START

; scan kody klaves (KBCODE & $3F)
KEY_MINUS  = $0E           ; CTRL+-  = sipka nahoru
KEY_EQUAL  = $0F           ; CTRL+=  = sipka dolu
KEY_PLUS   = $06           ; CTRL++  = sipka vlevo
KEY_STAR   = $07           ; CTRL+*  = sipka vpravo
KEY_RETURN = $0C
KEY_SPACE  = $21
KEY_ESC    = $1C
KEY_P      = $0A

; smery
DIR_UP    = 0
DIR_RIGHT = 1
DIR_DOWN  = 2
DIR_LEFT  = 3

; barvy pozadi (COLPF2) jednotlivych obrazovek
COL_MENU  = $94
COL_GAME  = $74
COL_OVER  = $04
COL_TEXT  = $0E            ; jas textu (COLPF1)
COL_TITLE = $2A            ; titulek SNAKE v mode 6 (COLPF3)
COL_APPLE = $24            ; telo jablka (player 0)
COL_LEAF  = $C8            ; stopka a listek (player 1)

; ---------------------------------------------------------------------
;  Nulta stranka
; ---------------------------------------------------------------------
ScrPtr   = $80             ; ukazatel do videopameti (2 bajty)
TxtPtr   = $82             ; ukazatel na text (2 bajty)
TmpX     = $84
TmpY     = $85
InvMask  = $86             ; $00 / $80 - tisk normalne / inverzne
SndPtr   = $87             ; ukazatel na prehravany zvuk (2 bajty, hi = 0 -> ticho)

; ---------------------------------------------------------------------
;  Makro: tisk textu na (x, y); inverzi ridi InvMask
; ---------------------------------------------------------------------
        .macro PRINT            ; PRINT x,y,text
        lda #:1
        sta TmpX
        lda #:2
        sta TmpY
        lda #<:3
        ldx #>:3
        jsr PrintAt
        .endm

; =====================================================================
        org $2000

; ---------------------------------------------------------------------
;  Display list: 3x8 prazdnych radku, 24 radku ANTIC 2
; ---------------------------------------------------------------------
DList   dta $70,$70,$70
        dta $42,a(SCREEN)
        :23 dta $02
        dta $41,a(DList)

; menu: titulek v ANTIC mode 6 (20 znaku dvojnasobne sirky; $47 = mode 7,
; navic dvojnasobna vyska), pak text od radku 4 videopameti
DListMenu
        dta $70,$70,$70,$70
        dta $46,a(TitleBuf)
        dta $70,$70
        dta $42,a(SCREEN+4*40)
        :19 dta $02
        dta $41,a(DListMenu)

; "SNAKE" uprostred 20 znaku; bity 6-7 = $C0 -> barva COLPF3
TitleBuf
        :7 dta 0
        dta $33+$C0,$2E+$C0,$21+$C0,$2B+$C0,$25+$C0
        :8 dta 0

; ---------------------------------------------------------------------
;  Promenne
; ---------------------------------------------------------------------
FrameCnt  .byte 0
InRaw     .byte 0          ; aktualne drzene vstupy
InPrev    .byte 0
InNew     .byte 0          ; vstupy nove stisknute od minuleho snimku
BgColor   .byte COL_MENU   ; COLPF2 nastavovane ve VBI
DlPtr     .word DListMenu  ; display list nastavovany ve VBI

Selection .byte 0          ; menu: 0 = START GAME, 1 = ABOUT
Score     .byte 0
SnakeDir  .byte 0          ; smer posledniho kroku
NextDir   .byte 0          ; smer pristiho kroku (z klavesnice/joysticku)
SnakeLen  .byte 0
Delay     .byte 0          ; snimku mezi kroky
Timer     .byte 0
TailX     .byte 0
TailY     .byte 0
TailDir   .byte 0
Dead      .byte 0
Idx       .byte 0          ; pomocny index
Idx2      .byte 0
Blink     .byte 0          ; About: snimku do zmeny stavu oci
Eyes      .byte 0          ; About: 0 = otevrene, 1 = zavrene
AppleHpos .byte 0          ; HPOSP0 (0 = sprite mimo obraz)
ApplePmY  .byte 0          ; index prvniho radku jablka v P0DATA

SnakeX    .ds MAX_LEN      ; [0] = hlava
SnakeY    .ds MAX_LEN
SegDir    .ds MAX_LEN      ; smer od segmentu k predchozimu (blize hlave)

; adresy radku videopameti
RowLo   :24 dta <(SCREEN+#*40)
RowHi   :24 dta >(SCREEN+#*40)

; posun hlavy podle smeru (UP, RIGHT, DOWN, LEFT)
DirDX   .byte 0,1,0,$FF
DirDY   .byte $FF,0,1,0

; glyfy hada podle smeru (UP, RIGHT, DOWN, LEFT)
HeadTab .byte GLYPH0+6,GLYPH0+7,GLYPH0+8,GLYPH0+9
TailTab .byte GLYPH0+10,GLYPH0+11,GLYPH0+12,GLYPH0+13
; telo podle smeru prijezdu (in) a odjezdu (out): BodyTab[in*4+out]
; rovne = BODY_V/BODY_H, zatacka = roh spojujici vstupni a vystupni stranu
BodyTab .byte GLYPH0+1,GLYPH0+5,GLYPH0+1,GLYPH0+3   ; in UP:    -,RD,-,LD
        .byte GLYPH0+2,GLYPH0+0,GLYPH0+3,GLYPH0+0   ; in RIGHT: LU,-,LD,-
        .byte GLYPH0+1,GLYPH0+4,GLYPH0+1,GLYPH0+2   ; in DOWN:  -,RU,-,LU
        .byte GLYPH0+4,GLYPH0+0,GLYPH0+5,GLYPH0+0   ; in LEFT:  RU,-,RD,-

; jablko: telo = player 0, stopka + listek = player 1 (1 bit = 2 px znaku,
; pouzit jen horni nibble = 1 znak); oba na stejnem HPOS
AppleSprite dta $00,$00,$60,$F0,$F0,$F0,$F0,$60
LeafSprite  dta $20,$E0,$00,$00,$00,$00,$00,$00

; bity vstupu -> smer (poradi bitu UP, DOWN, LEFT, RIGHT)
BitTab  .byte IN_UP,IN_DOWN,IN_LEFT,IN_RIGHT
BitDir  .byte DIR_UP,DIR_DOWN,DIR_LEFT,DIR_RIGHT

        icl 'snake_font.inc'

; ---------------------------------------------------------------------
;  Texty (konec $FF). MADS: text v "..." = interni kody, v '...' = ATASCII
; ---------------------------------------------------------------------
txtSub    .byte "FOR ATARI XL/XE",$FF
txtStart  .byte " START GAME ",$FF
txtAbout  .byte " ABOUT ",$FF
txtHint   .byte "JOYSTICK OR ARROWS, FIRE = SELECT",$FF
txtScore  .byte "SCORE",$FF
txtLength .byte "LENGTH",$FF
txtOver   .byte " GAME OVER ",$FF
txtPress  .byte "PRESS FIRE OR RETURN",$FF
txtPause  .byte " PAUSED ",$FF
txtNoPause .byte "        ",$FF
txtAb1    .byte "SNAKE FOR ATARI XL/XE",$FF
txtAb2    .byte "MADS ASSEMBLER, 2025",$FF
txtAb3    .byte "AUTHOR: PETR SKALOUD (BYPS)",$FF
txtAb4    .byte "EAT APPLES ",CH_APPLE,", AVOID WALLS AND",$FF
AB_AX   = 4+11             ; pozice jablka v txtAb4
AB_AY   = 14
txtAb5    .byte "YOUR OWN TAIL. P = PAUSE, ESC = MENU.",$FF

; =====================================================================
;  START
; =====================================================================
start
        sei
        lda #0
        sta NMIEN
        sta DMACTL
        sta GRACTL
        sta AUDCTL
        sta AUDC1
        sta SndPtr
        sta SndPtr+1
        sta InPrev
        lda #3
        sta SKCTL
        jsr InitFont
        jsr InitPMG
        lda #<Vbi
        sta VVBLKI
        lda #>Vbi
        sta VVBLKI+1
        lda #$40
        sta NMIEN
        cli

MainLoop
        jsr Menu
        lda Selection
        bne ML_about
        jsr Game
        jmp MainLoop
ML_about
        jsr About
        jmp MainLoop

; =====================================================================
;  MENU
; =====================================================================
Menu
        lda #COL_MENU
        sta BgColor
        jsr ClearScreen
        lda #<DListMenu
        sta DlPtr
        lda #>DListMenu
        sta DlPtr+1
        PRINT 12,6,txtSub
        PRINT 3,20,txtHint
        jsr WaitRelease
Menu_l  jsr DrawMenuItems
        jsr WaitFrame
        jsr ReadInputs
        lda InNew
        and #IN_UP
        beq Menu_1
        lda #0
        sta Selection
Menu_1  lda InNew
        and #IN_DOWN
        beq Menu_2
        lda #1
        sta Selection
Menu_2  lda InNew
        and #IN_FIRE
        beq Menu_l
        rts

; vykresli obe polozky, vybrana inverzne
DrawMenuItems
        lda Selection           ; 0 = START GAME, 1 = ABOUT
        beq DMI_0
        lda #$80
DMI_0   eor #$80                ; START GAME inverzne, kdyz Selection = 0
        sta InvMask
        PRINT 14,10,txtStart
        lda InvMask
        eor #$80                ; ABOUT inverzne v opacnem pripade
        sta InvMask
        PRINT 16,12,txtAbout
        lda #0
        sta InvMask
        rts

; =====================================================================
;  ABOUT
; =====================================================================
About
        jsr ClearScreen
        jsr UseGameDList
        PRINT 9,6,txtAb1
        PRINT 10,8,txtAb2
        PRINT 6,10,txtAb3
        PRINT 4,AB_AY,txtAb4
        lda #AB_AX
        sta TmpX
        lda #AB_AY
        sta TmpY
        jsr SetPos
        jsr AppleShow
        PRINT 3,16,txtAb5
        PRINT 10,20,txtPress
        ; dekorace: had (7 znaku) v levem hornim rohu, hlava mrka
        ldx #0
AB_s    lda AboutSnake,x
        sta TmpX
        lda AboutSnake+1,x
        sta TmpY
        lda AboutSnake+2,x
        pha
        txa
        pha
        jsr SetPos
        pla
        tax
        pla
        sta (ScrPtr),y
        inx
        inx
        inx
        cpx #7*3
        bne AB_s
        lda #0
        sta Eyes
        lda #50
        sta Blink
        jsr WaitRelease
AB_l    jsr WaitFrame
        jsr ReadInputs
        lda InNew
        and #IN_FIRE|IN_ESC
        bne AB_end
        dec Blink
        bne AB_l
        ; zmena stavu oci: zavrit na 6 snimku, otevrit na 60-187 snimku
        lda Eyes
        eor #1
        sta Eyes
        beq AB_open
        lda #6
        sta Blink
        lda #GLYPH0+15          ; hlava se zavrenyma ocima
        bne AB_head
AB_open lda RANDOM
        and #$7F
        clc
        adc #60
        sta Blink
        lda #GLYPH0+7           ; hlava doprava
AB_head sta SCREEN+AB_HY*40+AB_HX
        jmp AB_l
AB_end  rts

; had na About: (x, y, glyf) - ocas dole, svisle nahoru, roh, vodorovne, hlava
AB_HX   = 4
AB_HY   = 1
AboutSnake
        dta 1,4,GLYPH0+10       ; TAIL_U
        dta 1,3,GLYPH0+1        ; BODY_V
        dta 1,2,GLYPH0+1
        dta 1,1,GLYPH0+5        ; roh RD (prijel zdola, jede vpravo)
        dta 2,1,GLYPH0+0        ; BODY_H
        dta 3,1,GLYPH0+0
        dta AB_HX,AB_HY,GLYPH0+7 ; HEAD_R

; ceka na FIRE / RETURN / MEZERNIK / ESC (nejdriv na uvolneni vseho)
WaitConfirm
        jsr WaitRelease
WC_l    jsr WaitFrame
        jsr ReadInputs
        lda InNew
        and #IN_FIRE|IN_ESC
        beq WC_l
        rts

; =====================================================================
;  HRA
; =====================================================================
Game
        lda #COL_GAME
        sta BgColor
        jsr ClearScreen
        jsr UseGameDList
        jsr DrawBorder
        lda #0
        sta Score
        sta Dead
        lda #START_LEN
        sta SnakeLen
        lda #DIR_RIGHT
        sta SnakeDir
        sta NextDir
        lda #START_DELAY
        sta Delay
        sta Timer
        ; had vodorovne uprostred, hlava vpravo
        ; hlava [0] je nejvic vpravo: x = 20 - i, y = 12
        ldy #0
G_init  sty TmpX
        lda #20
        sec
        sbc TmpX
        sta SnakeX,y
        lda #12
        sta SnakeY,y
        lda #DIR_RIGHT
        sta SegDir,y
        iny
        cpy SnakeLen
        bne G_init
        jsr DrawSnakeFull
        jsr PlaceApple
        jsr DrawStatus
        jsr WaitRelease

G_loop  jsr WaitFrame
        jsr ReadInputs
        lda InNew
        and #IN_ESC
        bne G_esc
        lda InNew
        and #IN_PAUSE
        beq G_nop
        jsr Pause
        bne G_esc               ; ESC v pauze = konec hry
G_nop   jsr ChooseDir
        dec Timer
        bne G_loop
        lda Delay
        sta Timer
        jsr Step
        lda Dead
        beq G_loop
        jmp GameOver
G_esc   rts

; pauza: PAUSED na stavovem radku; P/START = pokracovat (vraci Z=1),
; ESC = ukoncit hru (vraci Z=0)
Pause
        lda #$80
        sta InvMask
        PRINT 16,0,txtPause
        lda #0
        sta InvMask
P_l     jsr WaitFrame
        jsr ReadInputs
        lda InNew
        and #IN_ESC
        bne P_end
        lda InNew
        and #IN_PAUSE
        beq P_l
        PRINT 16,0,txtNoPause
        lda #0
P_end   rts

; z drzenych vstupu vybere novy smer; zakaze otoceni o 180 stupnu
; (kontroluje se vuci smeru POSLEDNIHO kroku, ne vuci NextDir, aby
; dve rychle klavesy v jednom kroku nemohly hada otocit do sebe)
ChooseDir
        ldx #3
CD_l    lda InRaw
        and BitTab,x
        bne CD_hit
        dex
        bpl CD_l
        rts
CD_hit  sta Idx                 ; bit stisknuteho smeru
        lda BitDir,x
        sta TmpX
        clc
        adc #2
        and #3                  ; opacny smer
        cmp SnakeDir
        bne CD_ok
        lda InNew               ; zakazana otocka: zvuk jen pri novem stisku
        and Idx
        beq CD_end
        jmp SoundDenied
CD_ok   lda TmpX
        sta NextDir
CD_end  rts

; jeden krok hada
Step
        lda NextDir
        sta SnakeDir
        ; zapamatuj ocas
        ldy SnakeLen
        dey
        lda SnakeX,y
        sta TailX
        lda SnakeY,y
        sta TailY
        lda SegDir,y
        sta TailDir
        ; posun segmentu od ocasu k hlave: S[i] = S[i-1]
St_sh   cpy #0
        beq St_head
        lda SnakeX-1,y
        sta SnakeX,y
        lda SnakeY-1,y
        sta SnakeY,y
        lda SegDir-1,y
        sta SegDir,y
        dey
        jmp St_sh
St_head
        lda SnakeDir
        sta SegDir              ; hlava
        ; stara hlava (ted uz S[1]) se prekresli na telo: rovne nebo roh
        lda SnakeX+1
        sta TmpX
        lda SnakeY+1
        sta TmpY
        jsr SetPos
        lda SegDir+1            ; smer prijezdu
        asl
        asl
        ora SnakeDir            ; smer odjezdu
        tax
        lda BodyTab,x
        sta (ScrPtr),y
        ; smaz ocas a novy ocas prekresli na spicku
        lda TailX
        sta TmpX
        lda TailY
        sta TmpY
        jsr SetPos
        lda #CH_SPACE
        sta (ScrPtr),y
        jsr DrawTail
        ; nova hlava
        ldx SnakeDir
        lda SnakeX
        clc
        adc DirDX,x
        sta SnakeX
        lda SnakeY
        clc
        adc DirDY,x
        sta SnakeY
        ; co je na novem policku?
        lda SnakeX
        sta TmpX
        lda SnakeY
        sta TmpY
        jsr SetPos
        lda (ScrPtr),y
        cmp #CH_APPLE
        beq St_eat
        cmp #CH_SPACE
        beq St_draw
        ; zed nebo telo -> konec
        lda #1
        sta Dead
        jmp St_draw
St_eat  inc Score
        bne St_e1
        dec Score               ; strop 255
St_e1   lda SnakeLen
        cmp #MAX_LEN
        beq St_e2
        inc SnakeLen
        ldy SnakeLen
        dey
        lda TailX
        sta SnakeX,y
        lda TailY
        sta SnakeY,y
        lda TailDir
        sta SegDir,y
        dey
        jsr DrawBodySeg         ; byvaly ocas (ted predposledni) zpet na telo
        jsr DrawTail            ; ocas vratit na obrazovku
St_e2   jsr SpeedUp
        jsr SoundEat
        jsr PlaceApple
        jsr DrawStatus
        lda SnakeX
        sta TmpX
        lda SnakeY
        sta TmpY
        jsr SetPos
St_draw ldx SnakeDir
        lda HeadTab,x
        sta (ScrPtr),y
        rts

; nakresli spicku ocasu na posledni segment (glyf podle jeho smeru)
; prekresli segment Y (1..len-2) jako telo: in = SegDir[Y], out = SegDir[Y-1]
DrawBodySeg
        lda SnakeX,y
        sta TmpX
        lda SnakeY,y
        sta TmpY
        lda SegDir,y
        asl
        asl
        ora SegDir-1,y
        tax
        jsr SetPos
        lda BodyTab,x
        sta (ScrPtr),y
        rts

DrawTail
        ldy SnakeLen
        dey
        lda SnakeX,y
        sta TmpX
        lda SnakeY,y
        sta TmpY
        ldx SegDir-1,y          ; smer k dalsimu segmentu (blize hlave)
        jsr SetPos
        lda TailTab,x
        sta (ScrPtr),y
        rts

; kazde SPEED_STEP-te jablko zkrati Delay o 1 (min. MIN_DELAY)
SpeedUp
        lda Score
SU_l    cmp #SPEED_STEP
        bcc SU_chk
        sec
        sbc #SPEED_STEP
        jmp SU_l
SU_chk  tax
        bne SU_end              ; Score % SPEED_STEP != 0
        lda Delay
        cmp #MIN_DELAY+1
        bcc SU_end
        dec Delay
SU_end  rts

; nakresli celeho hada (hlava + telo)
DrawSnakeFull
        lda #0
        sta Idx
DSF_l   ldy Idx
        lda SnakeX,y
        sta TmpX
        lda SnakeY,y
        sta TmpY
        ldx SegDir,y
        jsr SetPos              ; Y = 0
        lda Idx
        bne DSF_1
        lda HeadTab,x           ; hlava
        jmp DSF_put
DSF_1   ldy Idx
        lda SegDir-1,y          ; telo: in = SegDir[i], out = SegDir[i-1]
        sta Idx2
        txa
        asl
        asl
        ora Idx2
        tax
        lda BodyTab,x
        ldy #0
DSF_put sta (ScrPtr),y
        inc Idx
        lda Idx
        cmp SnakeLen
        bne DSF_l
        jmp DrawTail

; nahodne umisti jablko na volne policko
PlaceApple
PA_x    lda RANDOM
        and #$3F
        cmp #FIELD_X0
        bcc PA_x
        cmp #FIELD_X1+1
        bcs PA_x
        sta TmpX
PA_y    lda RANDOM
        and #$1F
        cmp #FIELD_Y0
        bcc PA_y
        cmp #FIELD_Y1+1
        bcs PA_y
        sta TmpY
        jsr SetPos
        lda (ScrPtr),y
        bne PA_x                ; obsazeno
        jmp AppleShow

; zobrazi jablko na (TmpX, TmpY): znak (ScrPtr uz nastaven SetPos) + sprite
AppleShow
        jsr AppleHide
        lda #CH_APPLE
        sta (ScrPtr),y
        lda TmpX
        asl
        asl
        clc
        adc #48
        sta AppleHpos
        lda TmpY
        asl
        asl
        asl
        clc
        adc #PM_Y0
        sta ApplePmY
        tax
        ldy #0
AS_l    lda AppleSprite,y
        sta P0DATA,x
        lda LeafSprite,y
        sta P1DATA,x
        inx
        iny
        cpy #8
        bne AS_l
        rts

; schova sprite jablka (znak maze volajici)
AppleHide
        ldx ApplePmY
        beq AH_end
        lda #0
        ldy #8
AH_l    sta P0DATA,x
        sta P1DATA,x
        inx
        dey
        bne AH_l
        sta ApplePmY
        sta AppleHpos
AH_end  rts

; radek 0: SCORE nnn   LENGTH nnn
DrawStatus
        lda #0
        sta InvMask
        PRINT 1,0,txtScore
        lda #7
        sta TmpX
        lda Score
        jsr PrintDec3
        PRINT 28,0,txtLength
        lda #35
        sta TmpX
        lda SnakeLen
        jmp PrintDec3

; ohrada: radek 1 a 23 plny, sloupce 0 a 39 na radcich 2-22
DrawBorder
        ldy #SCREEN_W-2
        lda #CH_HOR
DB_1    sta SCREEN+1*40,y
        sta SCREEN+23*40,y
        dey
        bne DB_1
        lda #CH_TL
        sta SCREEN+1*40
        lda #CH_TR
        sta SCREEN+1*40+39
        lda #CH_BL
        sta SCREEN+23*40
        lda #CH_BR
        sta SCREEN+23*40+39
        lda #FIELD_Y0
        sta TmpY
DB_2    lda #0
        sta TmpX
        jsr SetPos
        lda #CH_VER
        sta (ScrPtr),y
        ldy #SCREEN_W-1
        sta (ScrPtr),y
        inc TmpY
        lda TmpY
        cmp #FIELD_Y1+1
        bne DB_2
        rts

; =====================================================================
;  GAME OVER
; =====================================================================
GameOver
        lda #COL_OVER
        sta BgColor
        jsr SoundOver
        lda #$80
        sta InvMask
        PRINT 14,11,txtOver
        lda #0
        sta InvMask
        PRINT 10,13,txtPress
        jmp WaitConfirm

; =====================================================================
;  Vstupy
; =====================================================================
; InRaw = drzene vstupy, InNew = nove stisknute od minuleho volani
ReadInputs
        lda PORTA
        eor #$FF
        and #$0F                ; bit0 up, bit1 down, bit2 left, bit3 right
        tay
        lda TRIG0
        bne RI_1
        tya
        ora #IN_FIRE
        tay
RI_1    lda SKSTAT
        and #4
        bne RI_2                ; zadna klavesa
        lda KBCODE
        and #$3F
        ldx #KEYMAPLEN-1
RI_kl   cmp KeyMapCode,x
        beq RI_kf
        dex
        bpl RI_kl
        bmi RI_2
RI_kf   tya
        ora KeyMapBit,x
        tay
RI_2    lda CONSOL
        and #1                  ; START (0 = stisknuto)
        bne RI_3
        tya
        ora #IN_PAUSE
        tay
RI_3    sty InRaw
        lda InPrev
        eor #$FF
        and InRaw
        sta InNew
        lda InRaw
        sta InPrev
        rts

KeyMapCode dta KEY_MINUS,KEY_EQUAL,KEY_PLUS,KEY_STAR,KEY_RETURN,KEY_SPACE,KEY_ESC,KEY_P
KeyMapBit  dta IN_UP,IN_DOWN,IN_LEFT,IN_RIGHT,IN_FIRE,IN_FIRE,IN_ESC,IN_PAUSE
KEYMAPLEN  = 8

; ceka, az jsou vsechny vstupy v klidu
WaitRelease
        jsr WaitFrame
        jsr ReadInputs
        lda InRaw
        bne WaitRelease
        rts

WaitFrame
        lda FrameCnt
WF_l    cmp FrameCnt
        beq WF_l
        rts

; =====================================================================
;  Obrazovka / tisk
; =====================================================================
ClearScreen
        jsr AppleHide
        lda #CH_SPACE
        ldx #0
CS_l    sta SCREEN,x
        sta SCREEN+$100,x
        sta SCREEN+$200,x
        sta SCREEN+$300,x
        inx
        bne CS_l
        rts

; ScrPtr = adresa policka (TmpX, TmpY); Y = 0
SetPos
        ldy TmpY
        lda RowLo,y
        clc
        adc TmpX
        sta ScrPtr
        lda RowHi,y
        adc #0
        sta ScrPtr+1
        ldy #0
        rts

; tiskne text (A = lo, X = hi adresy) na (TmpX, TmpY), OR InvMask;
; po navratu TmpX ukazuje za text
PrintAt
        sta TxtPtr
        stx TxtPtr+1
        jsr SetPos
PA_l    lda (TxtPtr),y
        cmp #$FF
        beq PA_end
        ora InvMask
        sta (ScrPtr),y
        inc TmpX
        iny
        bne PA_l
PA_end  rts

; tiskne A jako 3 cislice na (TmpX, TmpY)
PrintDec3
        ldx #0
PD_100  cmp #100
        bcc PD_1
        sbc #100
        inx
        bne PD_100
PD_1    pha
        txa
        jsr PutDigit
        pla
        ldx #0
PD_10   cmp #10
        bcc PD_2
        sbc #10
        inx
        bne PD_10
PD_2    pha
        txa
        jsr PutDigit
        pla
        ; pokracuje do PutDigit (jednotky)
PutDigit
        pha
        jsr SetPos
        pla
        clc
        adc #$10                ; interni kod '0'
        ora InvMask
        sta (ScrPtr),y
        inc TmpX
        rts

; =====================================================================
;  Zvuk: tabulky dvojic AUDF1,AUDC1 po snimcich, konec $FF; prehrava VBI
; =====================================================================
; spusti zvuk (A = lo, X = hi adresy tabulky); novy zvuk utne predchozi
PlaySound
        sta SndPtr
        stx SndPtr+1
        rts

SoundEat                        ; krup - mix bzucak/ton/sum (podle Worm)
        lda #<SfxEat
        ldx #>SfxEat
        bne PlaySound
SoundDenied                     ; alert - klesavy dvouton
        lda #<SfxDenied
        ldx #>SfxDenied
        bne PlaySound
SoundOver                       ; hluboky ton
        lda #<SfxOver
        ldx #>SfxOver
        bne PlaySound

SfxEat    dta $5F,$44, $5C,$A6, $57,$84, $5C,$A6, $5C,$A4, $44,$0E, $FF
SfxDenied dta $50,$AA, $50,$AA, $50,$AA, $78,$AA, $78,$AA, $78,$AA, $78,$A6, $FF
SfxOver   :30 dta $F0,$A8
          dta $FF

; =====================================================================
;  Znakova sada, display listy
; =====================================================================
; zkopiruje ROM font do RAM a prepise glyfy hada od GLYPH0
InitFont
        lda #<ROMFONT
        sta TxtPtr
        lda #>ROMFONT
        sta TxtPtr+1
        lda #<FONT
        sta ScrPtr
        lda #>FONT
        sta ScrPtr+1
        ldx #4                  ; 4 stranky
IF_p    ldy #0
IF_l    lda (TxtPtr),y
        sta (ScrPtr),y
        iny
        bne IF_l
        inc TxtPtr+1
        inc ScrPtr+1
        dex
        bne IF_p
        ldx #SNAKE_GLYPHS*8-1
IF_g    lda SnakeGlyphs,x
        sta FONT+GLYPH0*8,x
        dex
        bpl IF_g
        rts

; vynuluje data hracu 0 a 1 (jablko: telo + listek)
InitPMG
        lda #0
        sta ApplePmY
        sta AppleHpos
        tax
IP_l    sta P0DATA,x
        sta P1DATA,x
        inx
        bne IP_l
        rts

UseGameDList
        lda #<DList
        sta DlPtr
        lda #>DList
        sta DlPtr+1
        rts

; =====================================================================
;  VBI
; =====================================================================
Vbi
        cld
        inc FrameCnt
        lda DlPtr
        sta DLISTL
        lda DlPtr+1
        sta DLISTH
        lda #$3A                ; DL + player DMA, single-line
        sta DMACTL
        lda #>FONT
        sta CHBASE
        lda #>PMAREA
        sta PMBASE
        lda #2                  ; playeri zapnuti
        sta GRACTL
        lda #1                  ; playeri nad playfieldem: pixel textu nad hracem
        sta PRIOR               ; dostane odstin hrace + jas PF1
        lda #0
        sta SIZEP0
        sta SIZEP0+1
        lda #COL_APPLE
        sta COLPM0
        lda #COL_LEAF
        sta COLPM0+1
        lda AppleHpos
        sta HPOSP0
        sta HPOSP0+1
        lda #0
        sta COLPF0
        lda #COL_TITLE
        sta COLPF3
        lda BgColor
        sta COLBK               ; okraj i pozadi titulku (mode 6) = pozadi textu
        lda BgColor
        sta COLPF2
        lda #COL_TEXT
        sta COLPF1
        ; zvuk: dalsi dvojice z tabulky
        lda SndPtr+1
        beq V_end
        ldy #0
        lda (SndPtr),y
        cmp #$FF
        beq V_soff
        sta AUDF1
        iny
        lda (SndPtr),y
        sta AUDC1
        lda SndPtr
        clc
        adc #2
        sta SndPtr
        bcc V_end
        inc SndPtr+1
        bne V_end
V_soff  lda #0
        sta AUDC1
        sta SndPtr+1
V_end   jmp XITVBV

        run start
