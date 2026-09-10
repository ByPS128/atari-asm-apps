; =====================================================================
;  SNAKE pro Atari XL/XE (6502, MADS assembler)
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
;            = potvrzeni v menu, ESC = zpet do menu.
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
COLPF1   = $D017
COLPF2   = $D018
COLBK    = $D01A
GRACTL   = $D01D

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
CH_WALL  = $80             ; inverzni mezera = plny blok
CH_BODY  = $2F             ; 'O'
CH_HEAD  = $20             ; '@'
CH_APPLE = $0A             ; '*'

; bity vstupu (InRaw / InNew)
IN_UP    = $01
IN_DOWN  = $02
IN_LEFT  = $04
IN_RIGHT = $08
IN_FIRE  = $10
IN_ESC   = $20

; scan kody klaves (KBCODE & $3F)
KEY_MINUS  = $0E           ; CTRL+-  = sipka nahoru
KEY_EQUAL  = $0F           ; CTRL+=  = sipka dolu
KEY_PLUS   = $06           ; CTRL++  = sipka vlevo
KEY_STAR   = $07           ; CTRL+*  = sipka vpravo
KEY_RETURN = $0C
KEY_SPACE  = $21
KEY_ESC    = $1C

; smery
DIR_UP    = 0
DIR_RIGHT = 1
DIR_DOWN  = 2
DIR_LEFT  = 3

; barvy pozadi (COLPF2) jednotlivych obrazovek
COL_MENU  = $94
COL_GAME  = $B2
COL_OVER  = $34
COL_TEXT  = $0E            ; jas textu (COLPF1)

; ---------------------------------------------------------------------
;  Nulta stranka
; ---------------------------------------------------------------------
ScrPtr   = $80             ; ukazatel do videopameti (2 bajty)
TxtPtr   = $82             ; ukazatel na text (2 bajty)
TmpX     = $84
TmpY     = $85
InvMask  = $86             ; $00 / $80 - tisk normalne / inverzne

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

; ---------------------------------------------------------------------
;  Promenne
; ---------------------------------------------------------------------
FrameCnt  .byte 0
InRaw     .byte 0          ; aktualne drzene vstupy
InPrev    .byte 0
InNew     .byte 0          ; vstupy nove stisknute od minuleho snimku
BgColor   .byte COL_MENU   ; COLPF2 nastavovane ve VBI
SndTimer  .byte 0          ; zbyvajici snimky zvuku

Selection .byte 0          ; menu: 0 = START GAME, 1 = ABOUT
Score     .byte 0
SnakeDir  .byte 0          ; smer posledniho kroku
NextDir   .byte 0          ; smer pristiho kroku (z klavesnice/joysticku)
SnakeLen  .byte 0
Delay     .byte 0          ; snimku mezi kroky
Timer     .byte 0
TailX     .byte 0
TailY     .byte 0
Dead      .byte 0
Idx       .byte 0          ; pomocny index

SnakeX    .ds MAX_LEN      ; [0] = hlava
SnakeY    .ds MAX_LEN

; adresy radku videopameti
RowLo   :24 dta <(SCREEN+#*40)
RowHi   :24 dta >(SCREEN+#*40)

; posun hlavy podle smeru (UP, RIGHT, DOWN, LEFT)
DirDX   .byte 0,1,0,$FF
DirDY   .byte $FF,0,1,0

; ---------------------------------------------------------------------
;  Texty (konec $FF). MADS: text v "..." = interni kody, v '...' = ATASCII
; ---------------------------------------------------------------------
txtTitle  .byte "S N A K E",$FF
txtStart  .byte "START GAME",$FF
txtAbout  .byte "ABOUT",$FF
txtHint   .byte "JOYSTICK OR ARROWS, FIRE = SELECT",$FF
txtScore  .byte "SCORE",$FF
txtLength .byte "LENGTH",$FF
txtOver   .byte " GAME OVER ",$FF
txtPress  .byte "PRESS FIRE OR RETURN",$FF
txtAb1    .byte "SNAKE FOR ATARI XL/XE",$FF
txtAb2    .byte "MADS ASSEMBLER, 2025",$FF
txtAb3    .byte "AUTHOR: PETR SKALOUD (BYPS)",$FF
txtAb4    .byte "EAT APPLES (*), AVOID WALLS AND",$FF
txtAb5    .byte "YOUR OWN TAIL. ESC = BACK TO MENU.",$FF

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
        sta SndTimer
        sta InPrev
        lda #3
        sta SKCTL
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
        PRINT 15,4,txtTitle
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
        PRINT 15,10,txtStart
        lda InvMask
        eor #$80                ; ABOUT inverzne v opacnem pripade
        sta InvMask
        PRINT 17,12,txtAbout
        lda #0
        sta InvMask
        rts

; =====================================================================
;  ABOUT
; =====================================================================
About
        jsr ClearScreen
        PRINT 9,6,txtAb1
        PRINT 10,8,txtAb2
        PRINT 6,10,txtAb3
        PRINT 4,14,txtAb4
        PRINT 3,15,txtAb5
        PRINT 10,20,txtPress
        jmp WaitConfirm

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
        jsr ChooseDir
        dec Timer
        bne G_loop
        lda Delay
        sta Timer
        jsr Step
        lda Dead
        beq G_loop
        jmp GameOver
G_esc   rts

; z drzenych vstupu vybere novy smer; zakaze otoceni o 180 stupnu
; (kontroluje se vuci smeru POSLEDNIHO kroku, ne vuci NextDir, aby
; dve rychle klavesy v jednom kroku nemohly hada otocit do sebe)
ChooseDir
        lda InRaw
        and #IN_UP
        beq CD_1
        lda #DIR_UP
        jmp CD_set
CD_1    lda InRaw
        and #IN_DOWN
        beq CD_2
        lda #DIR_DOWN
        jmp CD_set
CD_2    lda InRaw
        and #IN_LEFT
        beq CD_3
        lda #DIR_LEFT
        jmp CD_set
CD_3    lda InRaw
        and #IN_RIGHT
        beq CD_end
        lda #DIR_RIGHT
CD_set  sta TmpX
        clc
        adc #2
        and #3                  ; opacny smer
        cmp SnakeDir
        beq CD_end
        lda TmpX
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
        ; posun segmentu od ocasu k hlave: S[i] = S[i-1]
St_sh   cpy #0
        beq St_head
        lda SnakeX-1,y
        sta SnakeX,y
        lda SnakeY-1,y
        sta SnakeY,y
        dey
        jmp St_sh
St_head
        ; stara hlava (ted uz S[1]) se prekresli na telo
        lda SnakeX+1
        sta TmpX
        lda SnakeY+1
        sta TmpY
        jsr SetPos
        lda #CH_BODY
        sta (ScrPtr),y
        ; smaz ocas
        lda TailX
        sta TmpX
        lda TailY
        sta TmpY
        jsr SetPos
        lda #CH_SPACE
        sta (ScrPtr),y
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
        lda TailX
        sta TmpX
        lda TailY
        sta TmpY
        jsr SetPos              ; ocas vratit na obrazovku
        lda #CH_BODY
        sta (ScrPtr),y
St_e2   jsr SpeedUp
        jsr SoundEat
        jsr PlaceApple
        jsr DrawStatus
        lda SnakeX
        sta TmpX
        lda SnakeY
        sta TmpY
        jsr SetPos
St_draw lda #CH_HEAD
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
        jsr SetPos              ; Y = 0
        lda #CH_BODY
        ldx Idx
        bne DSF_1
        lda #CH_HEAD
DSF_1   sta (ScrPtr),y
        inc Idx
        lda Idx
        cmp SnakeLen
        bne DSF_l
        rts

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
        lda #CH_APPLE
        sta (ScrPtr),y
        rts

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
        ldy #SCREEN_W-1
        lda #CH_WALL
DB_1    sta SCREEN+1*40,y
        sta SCREEN+23*40,y
        dey
        bpl DB_1
        lda #FIELD_Y0
        sta TmpY
DB_2    lda #0
        sta TmpX
        jsr SetPos
        lda #CH_WALL
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
RI_2    sty InRaw
        lda InPrev
        eor #$FF
        and InRaw
        sta InNew
        lda InRaw
        sta InPrev
        rts

KeyMapCode dta KEY_MINUS,KEY_EQUAL,KEY_PLUS,KEY_STAR,KEY_RETURN,KEY_SPACE,KEY_ESC
KeyMapBit  dta IN_UP,IN_DOWN,IN_LEFT,IN_RIGHT,IN_FIRE,IN_FIRE,IN_ESC
KEYMAPLEN  = 7

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
;  Zvuk (odpocitava VBI)
; =====================================================================
SoundEat
        lda #$30
        sta AUDF1
        lda #$A6
        sta AUDC1
        lda #4
        sta SndTimer
        rts

SoundOver
        lda #$F0
        sta AUDF1
        lda #$A8
        sta AUDC1
        lda #30
        sta SndTimer
        rts

; =====================================================================
;  VBI
; =====================================================================
Vbi
        cld
        inc FrameCnt
        lda #<DList
        sta DLISTL
        lda #>DList
        sta DLISTH
        lda #$22
        sta DMACTL
        lda #$E0
        sta CHBASE
        lda #0
        sta COLBK
        lda BgColor
        sta COLPF2
        lda #COL_TEXT
        sta COLPF1
        lda SndTimer
        beq V_end
        dec SndTimer
        bne V_end
        lda #0
        sta AUDC1
V_end   jmp XITVBV

        run start
