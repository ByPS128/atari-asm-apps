; =====================================================================
;  TETRIS - vizualni demo designu v textovem rezimu (ANTIC mode 4 + PMG)
;  - 40x24 znaku, vlastni znakova sada (charset4.inc): kostky (plna/duta),
;    4px pismo ve dvou barvach, ramecky, podlaha
;  - steny studny = dva playeri (sprites) v sede, s cihlovym vzorem
;  - barvy: PF0 cyan (I plna, J duta), PF1 zluta (O, L), PF2 cervena (Z, T),
;    PF3 zelena (S), pozadi cerna, playeri seda
;  Build:  mads design2.asm -o:design2.xex
; =====================================================================
DMACTL   = $D400
DLISTL   = $D402
DLISTH   = $D403
CHBASE   = $D409
NMIEN    = $D40E
PMBASE   = $D407
VVBLKI   = $0222
XITVBV   = $E462
HPOSP0   = $D000
HPOSP1   = $D001
SIZEP0   = $D008
SIZEP1   = $D009
COLPM0   = $D012
COLPM1   = $D013
COLPF0   = $D016
COLPF1   = $D017
COLPF2   = $D018
COLPF3   = $D019
COLBK    = $D01A
PRIOR    = $D01B
GRACTL   = $D01D
CONSOL   = $D01F
SKCTL    = $D20F

SCREEN   = $6000           ; 24 x 40
PMAREA   = $5000           ; 2K, single-line
PM_P0    = PMAREA+$400
PM_P1    = PMAREA+$500

; znaky
CH_FONTA = 0               ; pismo barva PF0 (cyan) - popisky
CH_FONTB = 40              ; pismo barva PF1 (zluta) - hodnoty
CH_FTOP  = 80
CH_FBOT  = 81
CH_FLEFT = 82
CH_FRIGHT = 83
CH_FTL   = 84
CH_FTR   = 85
CH_FBL   = 86
CH_FBR   = 87
CH_I     = 90              ; cyan plna
CH_J     = 91              ; cyan duta
CH_O     = 92              ; zluta plna
CH_L     = 93              ; zluta duta
CH_Z     = 94              ; cervena plna
CH_T     = 95              ; cervena duta
CH_S     = 94+128          ; zelena plna (PF3)
CH_FLOOR = 96

WELL_COL = 16              ; prvni sloupec bunek studny
WALL_L   = 14              ; sloupce sten (2 znaky siroke): 14-15 a 26-27
WALL_R   = 26

        org $80
ptr      .byte 0,0
sptr     .byte 0,0
tmp      .byte 0

.macro TEXT               ; TEXT sloupec, radek, retezec, barva(0=A,40=B)
        lda #<(SCREEN+:2*40+:1)
        sta ptr
        lda #>(SCREEN+:2*40+:1)
        sta ptr+1
        lda #<:3
        sta sptr
        lda #>:3
        sta sptr+1
        lda #:4
        sta tmp
        jsr PutStr
.endm

.macro CELL               ; CELL sloupec_studny, radek_studny(0..19), znak
        lda #:3
        sta SCREEN+(:2+1)*40+WELL_COL+:1
.endm

        org $2000
start
        sei
        lda #0
        sta NMIEN
        sta DMACTL
        lda #3
        sta SKCTL
        lda #<Vbi
        sta VVBLKI
        lda #>Vbi
        sta VVBLKI+1
        jsr ClearScreen
        jsr InitPMG
        jsr DrawMockup
        lda #$40
        sta NMIEN
        cli
Loop    jmp Loop

Vbi
        cld
        lda #8
        sta CONSOL
        lda #<DL
        sta DLISTL
        lda #>DL
        sta DLISTH
        lda #>Charset4
        sta CHBASE
        lda #$3A                    ; DL + player DMA, single-line, normalni sirka
        sta DMACTL
        lda #>PMAREA
        sta PMBASE
        lda #2
        sta GRACTL
        lda #1                      ; playeri nad playfieldem
        sta PRIOR
        lda #$00
        sta COLBK
        lda #$9A
        sta COLPF0
        lda #$1C
        sta COLPF1
        lda #$38
        sta COLPF2
        lda #$C8
        sta COLPF3
        lda #$08
        sta COLPM0
        sta COLPM1
        lda #48+4*WALL_L
        sta HPOSP0
        lda #48+4*WALL_R
        sta HPOSP1
        lda #0
        sta SIZEP0
        sta SIZEP1
        jmp XITVBV

ClearScreen
        ldy #0
        tya
CS_l    sta SCREEN,y
        sta SCREEN+$100,y
        sta SCREEN+$200,y
        sta SCREEN+$300,y
        iny
        bne CS_l
        rts

; steny: scanline 40..199 (radky 1..20), cihly 4 linky vysoke se sparou
InitPMG
        ldy #0
        tya
IP_c    sta PMAREA+$400,y
        sta PMAREA+$500,y
        iny
        bne IP_c
        ldx #0
IP_l    txa
        and #3
        cmp #3
        beq IP_seam
        txa
        and #4
        beq IP_a
        lda #$EF                    ; svisla spara vpravo
        bne IP_put
IP_a    lda #$FD                    ; svisla spara vlevo
        bne IP_put
IP_seam lda #$00
IP_put  sta PM_P0+40,x
        sta PM_P1+40,x
        inx
        cpx #160
        bne IP_l
        rts

; ---------------------------------------------------------------------
DrawMockup
        ; podlaha
        ldx #WALL_L
        lda #CH_FLOOR
DM_f    sta SCREEN+21*40,x
        inx
        cpx #WALL_R+2
        bne DM_f
        ; ukazkovy obsah studny
        CELL 4,1,CH_T
        CELL 3,2,CH_T
        CELL 4,2,CH_T
        CELL 5,2,CH_T
        CELL 0,19,CH_I
        CELL 1,19,CH_I
        CELL 2,19,CH_I
        CELL 3,19,CH_I
        CELL 4,19,CH_L
        CELL 5,19,CH_J
        CELL 6,19,CH_J
        CELL 7,19,CH_Z
        CELL 8,19,CH_Z
        CELL 9,19,CH_L
        CELL 0,18,CH_Z
        CELL 1,18,CH_Z
        CELL 4,18,CH_L
        CELL 5,18,CH_J
        CELL 6,18,CH_O
        CELL 7,18,CH_O
        CELL 8,18,CH_S
        CELL 9,18,CH_S
        CELL 1,17,CH_Z
        CELL 2,17,CH_Z
        CELL 4,17,CH_L
        CELL 6,17,CH_O
        CELL 7,17,CH_O
        CELL 9,17,CH_S
        CELL 9,16,CH_S
        ; pravy panel
        TEXT 30,1,TxNext,CH_FONTA
        jsr NextBox
        lda #CH_S
        sta SCREEN+4*40+33
        sta SCREEN+4*40+34
        sta SCREEN+5*40+32
        sta SCREEN+5*40+33
        TEXT 30,9,TxLevel,CH_FONTA
        TEXT 30,10,TxLevelV,CH_FONTB
        TEXT 30,12,TxScore,CH_FONTA
        TEXT 30,13,TxScoreV,CH_FONTB
        TEXT 30,15,TxLines,CH_FONTA
        TEXT 30,16,TxLinesV,CH_FONTB
        TEXT 30,18,TxRows,CH_FONTA
        TEXT 30,19,TxRowsV,CH_FONTB
        TEXT 30,21,TxTime,CH_FONTA
        TEXT 30,22,TxTimeV,CH_FONTB
        ; napoveda vlevo
        TEXT 1,2,TxH1a,CH_FONTA
        TEXT 3,3,TxH1b,CH_FONTB
        TEXT 1,5,TxH2a,CH_FONTA
        TEXT 3,6,TxH2b,CH_FONTB
        TEXT 1,8,TxH3a,CH_FONTA
        TEXT 3,9,TxH3b,CH_FONTB
        TEXT 1,11,TxH4a,CH_FONTA
        TEXT 3,12,TxH4b,CH_FONTB
        TEXT 1,14,TxH5a,CH_FONTA
        TEXT 3,15,TxH5b,CH_FONTB
        TEXT 1,17,TxH6a,CH_FONTA
        TEXT 3,18,TxH6b,CH_FONTB
        TEXT 1,21,TxSkill,CH_FONTA
        rts

; ramecek NEXT: radky 2..7, sloupce 29..38
NextBox
        lda #CH_FTL
        sta SCREEN+2*40+29
        lda #CH_FTR
        sta SCREEN+2*40+38
        lda #CH_FBL
        sta SCREEN+7*40+29
        lda #CH_FBR
        sta SCREEN+7*40+38
        ldx #30
NB_h    lda #CH_FTOP
        sta SCREEN+2*40,x
        lda #CH_FBOT
        sta SCREEN+7*40,x
        inx
        cpx #38
        bne NB_h
        ldx #3
NB_v    stx tmp
        lda RowLo,x
        sta ptr
        lda RowHi,x
        sta ptr+1
        ldy #29
        lda #CH_FLEFT
        sta (ptr),y
        ldy #38
        lda #CH_FRIGHT
        sta (ptr),y
        ldx tmp
        inx
        cpx #7
        bne NB_v
        rts

RowLo   .byte <(SCREEN),<(SCREEN+40),<(SCREEN+80),<(SCREEN+120),<(SCREEN+160),<(SCREEN+200),<(SCREEN+240),<(SCREEN+280)
RowHi   .byte >(SCREEN),>(SCREEN+40),>(SCREEN+80),>(SCREEN+120),>(SCREEN+160),>(SCREEN+200),>(SCREEN+240),>(SCREEN+280)

; retezec (screen kody, $FF konec) -> indexy fontu (+tmp = barva)
PutStr
        ldy #0
PS_l    lda (sptr),y
        cmp #$FF
        beq PS_e
        jsr MapChar
        clc
        adc tmp
        sta (ptr),y
        iny
        bne PS_l
PS_e    rts

; screen kod -> index fontu (0 mezera, 1-10 cislice, 11-36 pismena, 37 ':', 38 '/', 39 '-')
MapChar
        cmp #0
        beq MC_r
        cmp #$1A
        bne MC_1
        lda #37
        rts
MC_1    cmp #$0F
        bne MC_2
        lda #38
        rts
MC_2    cmp #$0D
        bne MC_3
        lda #39
        rts
MC_3    cmp #33
        bcc MC_dig
        sec
        sbc #33-11
        rts
MC_dig  sec
        sbc #15
MC_r    rts

TxNext   dta d'NEXT',$FF
TxLevel  dta d'LEVEL',$FF
TxLevelV dta d'03',$FF
TxScore  dta d'SCORE',$FF
TxScoreV dta d'001985',$FF
TxLines  dta d'LINES',$FF
TxLinesV dta d'0013',$FF
TxRows   dta d'ROWS',$FF
TxRowsV  dta d'03',$FF
TxTime   dta d'TIME',$FF
TxTimeV  dta d'03:42',$FF
TxH1a    dta d'MOVE',$FF
TxH1b    dta d'STICK',$FF
TxH2a    dta d'ROTATE',$FF
TxH2b    dta d'FIRE',$FF
TxH3a    dta d'DROP',$FF
TxH3b    dta d'DOWN',$FF
TxH4a    dta d'HARD',$FF
TxH4b    dta d'SPACE',$FF
TxH5a    dta d'PAUSE',$FF
TxH5b    dta d'START',$FF
TxH6a    dta d'MENU',$FF
TxH6b    dta d'ESC',$FF
TxSkill  dta d'BASIC',$FF

        org $7000
        icl 'charset4.inc'

        org $7400
DL
        .byte $70,$70,$70
        .byte $44
        dta a(SCREEN)
        :23 .byte $04
        .byte $41
        dta a(DL)

        run start
