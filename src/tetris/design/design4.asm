; =====================================================================
;  TETRIS - design 4: jako design3, ale studna se nebarvi; uvolneny P2 barvi
;  AKTIVNI kostku a P3 kostku v NEXT, oba v dvojnasobne sirce (1 bit = 2 barevne
;  hodiny = pul znaku, 8 bitu = 4 bunky). Barvy podle Tetris guideline:
;  I tyrkysova, O zluta, T fialova, S zelena, Z cervena, J modra, L oranzova.
;  Kostka = plny blok, takze vsechny pixely jsou "text" -> odstin hrace + jas PF1.
;  Usazene kostky zustavaji sede (bez hrace).
;  Build:  mads design4.asm -o:design4.xex
; =====================================================================
DMACTL   = $D400
DLISTL   = $D402
DLISTH   = $D403
CHBASE   = $D409
NMIEN    = $D40E
VVBLKI   = $0222
XITVBV   = $E462
VDSLST   = $0200
WSYNC    = $D40A
PMBASE   = $D407
HPOSP0   = $D000
HPOSP1   = $D001
HPOSP2   = $D002
HPOSP3   = $D003
SIZEP0   = $D008
COLPM0   = $D012
COLPF1   = $D017
COLPF2   = $D018
COLBK    = $D01A
PRIOR    = $D01B
GRACTL   = $D01D
CONSOL   = $D01F
SKCTL    = $D20F

SCREEN   = $6000           ; 26 x 40 (vlastni DL, 208 scanlinu)
PMAREA   = $5000           ; PMG, single-line: P0 $5400, P1 $5500, P2 $5600, P3 $5700
ROWS     = 26
WELL_H   = 24              ; vyska studny v bunkach (radky 0..23), dno na radku 24

; interni kody grafickych znaku (ATASCII 0-31 -> +$40, inverze +$80)
G_SOLID  = $80             ; plny blok (inverzni mezera)
G_BALL   = $54             ; kulicka
G_IBALL  = $D4             ; inverzni kulicka
G_DIA    = $60             ; karo
G_IDIA   = $E0             ; inverzni karo
G_CROSS  = $53             ; kriz
G_ICROSS = $D3             ; inverzni kriz
G_RHALF  = $42             ; prava polovina bloku
G_LHALF  = $59             ; leva polovina bloku
G_UHALF  = $D5             ; horni polovina bloku (inverzni dolni pulblok)
G_TL     = $51             ; rohy a cary ramecku
G_TR     = $45
G_BL     = $5A
G_BR     = $43
G_HLINE  = $52
G_VLINE  = $7C

; vsechny kostky = plny blok 8x8
CH_I = G_SOLID
CH_O = G_SOLID
CH_T = G_SOLID
CH_S = G_SOLID
CH_Z = G_SOLID
CH_J = G_SOLID
CH_L = G_SOLID

WELL_COL = 15              ; prvni sloupec bunek (steny na 14 a 25)
NEXT_IN  = 32              ; prvni sloupec vnitrku ramecku NEXT

; barvy kostek (odstin; jas dodava COLPF1)
; POZOR: jas dava COLPF1 ($0C), takze vsechny barvy jsou stejne svetle (pastelove);
; syte cervene se pri tomto jasu nedosahne, nejblizsi je $30. Tmavsi paleta = snizit COLPF1.
COL_I = $90                ; tyrkysova
COL_O = $E0                ; zluta
COL_T = $60                ; fialova
COL_S = $B0                ; zelena
COL_Z = $30                ; cervena (ruzovocervena)
COL_J = $70                ; modra
COL_L = $10                ; oranzova

        org $80
ptr      .byte 0,0
sptr     .byte 0,0
tmp      .byte 0
DliRow   .byte 0

.macro TEXT               ; TEXT sloupec, radek, retezec
        lda #<(SCREEN+:2*40+:1)
        sta ptr
        lda #>(SCREEN+:2*40+:1)
        sta ptr+1
        lda #<:3
        sta sptr
        lda #>:3
        sta sptr+1
        jsr PutStr
.endm

.macro CELL               ; CELL sloupec_studny, radek_studny(0..23), znak
        lda #:3
        sta SCREEN+(:2)*40+WELL_COL+:1
.endm

        org $2000
start
        sei
        lda #0
        sta NMIEN
        sta DMACTL
        sta GRACTL
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
        lda #$E0
        sta CHBASE
        lda #$3E                    ; DL + player + missile DMA, single-line
        sta DMACTL
        lda #>PMAREA
        sta PMBASE
        lda #3
        sta GRACTL
        lda #1                      ; playeri nad playfieldem -> "barevny filtr" pres text
        sta PRIOR
        lda #0
        sta COLBK                   ; cerny okraj
        sta COLPF2                  ; cerne pozadi (radek 0; dalsi radky prebarvuje DLI)
        lda #$0C                    ; jas textu
        sta COLPF1
        ; barvy playeru: lum 0 = pozadi pruhu zustane cerne, text dostane odstin
        lda #$B0                    ; napoveda vlevo: tyrkysova
        sta COLPM0
        lda #$20                    ; panel vpravo: oranzova
        sta COLPM0+1
        lda #COL_T                  ; P2: aktivni kostka (T)
        sta COLPM0+2
        lda #COL_S                  ; P3: kostka v NEXT (S)
        sta COLPM0+3
        lda #48+4*1                 ; P0: sloupce 1..8 (text 2..7 -> okraj 1 znak)
        sta HPOSP0
        lda #48+4*29                ; P1: sloupce 29..36
        sta HPOSP1
        lda #48+4*(WELL_COL+3)      ; P2: aktivni kostka od bunky 3
        sta HPOSP2
        lda #48+4*NEXT_IN           ; P3: vnitrek NEXT
        sta HPOSP3
        lda #3
        sta SIZEP0
        sta SIZEP0+1
        lda #1                      ; dvojnasobna sirka = 4 bunky
        sta SIZEP0+2
        sta SIZEP0+3
        jmp XITVBV

; PMG: P0 radky 2..22 (napoveda), P1 radky 8..23 (panel),
; P2 = aktivni kostka (T na radcich 0..1), P3 = NEXT (S na radcich 3..4)
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
        ; radek r zacina na scanline 16+8*r
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
        ; bitova maska radku kostky: bunka c = bity (7-2c),(6-2c)
        ldx #16+8*0
        ldy #8
IP_2a   lda #$30                    ; T radek 0: bunka 1
        sta PMAREA+$600,x
        inx
        dey
        bne IP_2a
        ldy #8
IP_2b   lda #$FC                    ; T radek 1: bunky 0..2
        sta PMAREA+$600,x
        inx
        dey
        bne IP_2b
        ldx #16+8*3
        ldy #8
IP_3a   lda #$3C                    ; S radek 3: bunky 1..2
        sta PMAREA+$700,x
        inx
        dey
        bne IP_3a
        ldy #8
IP_3b   lda #$F0                    ; S radek 4: bunky 0..1
        sta PMAREA+$700,x
        inx
        dey
        bne IP_3b
        rts

ClearScreen
        ldy #0
        tya
CS_l    sta SCREEN,y
        sta SCREEN+$100,y
        sta SCREEN+$200,y
        sta SCREEN+$300,y
        sta SCREEN+$400,y
        iny
        bne CS_l
        rts

; ---------------------------------------------------------------------
DrawMockup
        ; steny (radky 0..23): svisle cary jako u ramecku NEXT
        ldx #0
DM_w    stx tmp
        lda RowLo,x
        sta ptr
        lda RowHi,x
        sta ptr+1
        lda #G_VLINE
        ldy #WELL_COL-1
        sta (ptr),y
        ldy #WELL_COL+10
        sta (ptr),y
        ldx tmp
        inx
        cpx #WELL_H
        bne DM_w
        ; dno (radek 21): vodorovna cara s rohy
        ldx #WELL_COL
        lda #G_HLINE
DM_f    sta SCREEN+WELL_H*40,x
        inx
        cpx #WELL_COL+10
        bne DM_f
        lda #G_BL
        sta SCREEN+WELL_H*40+WELL_COL-1
        lda #G_BR
        sta SCREEN+WELL_H*40+WELL_COL+10
        ; ukazkovy obsah studny
        CELL 4,0,CH_T
        CELL 3,1,CH_T
        CELL 4,1,CH_T
        CELL 5,1,CH_T
        CELL 0,23,CH_I
        CELL 1,23,CH_I
        CELL 2,23,CH_I
        CELL 3,23,CH_I
        CELL 4,23,CH_L
        CELL 5,23,CH_J
        CELL 6,23,CH_J
        CELL 7,23,CH_Z
        CELL 8,23,CH_Z
        CELL 9,23,CH_L
        CELL 0,22,CH_Z
        CELL 1,22,CH_Z
        CELL 4,22,CH_L
        CELL 5,22,CH_J
        CELL 6,22,CH_O
        CELL 7,22,CH_O
        CELL 8,22,CH_S
        CELL 9,22,CH_S
        CELL 1,21,CH_Z
        CELL 2,21,CH_Z
        CELL 4,21,CH_L
        CELL 6,21,CH_O
        CELL 7,21,CH_O
        CELL 9,21,CH_S
        CELL 9,20,CH_S
        ; pravy panel
        TEXT 32,0,TxNext
        jsr NextBox
        lda #CH_S                   ; S ve spawn rotaci, uprostred vnitrku 4x4
        sta SCREEN+3*40+33
        sta SCREEN+3*40+34
        sta SCREEN+4*40+32
        sta SCREEN+4*40+33
        TEXT 30,9,TxLevel
        TEXT 30,10,TxLevelV
        TEXT 30,12,TxScore
        TEXT 30,13,TxScoreV
        TEXT 30,15,TxLines
        TEXT 30,16,TxLinesV
        TEXT 30,18,TxRows
        TEXT 30,19,TxRowsV
        TEXT 30,21,TxTime
        TEXT 30,22,TxTimeV
        ; napoveda vlevo
        TEXT 2,2,TxH1a
        TEXT 3,3,TxH1b
        TEXT 2,5,TxH2a
        TEXT 3,6,TxH2b
        TEXT 2,8,TxH3a
        TEXT 3,9,TxH3b
        TEXT 2,11,TxH4a
        TEXT 3,12,TxH4b
        TEXT 2,14,TxH5a
        TEXT 3,15,TxH5b
        TEXT 2,17,TxH6a
        TEXT 3,18,TxH6b
        TEXT 2,22,TxSkill
        rts

; ramecek NEXT: 6x6 znaku (radky 1..6, sloupce 31..36), vnitrek 4x4 = nejvetsi dilek
NEXT_COL = 31
NextBox
        lda #G_TL
        sta SCREEN+1*40+NEXT_COL
        lda #G_TR
        sta SCREEN+1*40+NEXT_COL+5
        lda #G_BL
        sta SCREEN+6*40+NEXT_COL
        lda #G_BR
        sta SCREEN+6*40+NEXT_COL+5
        ldx #NEXT_COL+1
NB_h    lda #G_HLINE
        sta SCREEN+1*40,x
        sta SCREEN+6*40,x
        inx
        cpx #NEXT_COL+5
        bne NB_h
        ldx #2
NB_v    stx tmp
        lda RowLo,x
        sta ptr
        lda RowHi,x
        sta ptr+1
        lda #G_VLINE
        ldy #NEXT_COL
        sta (ptr),y
        ldy #NEXT_COL+5
        sta (ptr),y
        ldx tmp
        inx
        cpx #6
        bne NB_v
        rts

RowLo   .byte <(SCREEN+0*40),<(SCREEN+1*40),<(SCREEN+2*40),<(SCREEN+3*40),<(SCREEN+4*40),<(SCREEN+5*40),<(SCREEN+6*40),<(SCREEN+7*40),<(SCREEN+8*40),<(SCREEN+9*40),<(SCREEN+10*40),<(SCREEN+11*40),<(SCREEN+12*40),<(SCREEN+13*40),<(SCREEN+14*40),<(SCREEN+15*40),<(SCREEN+16*40),<(SCREEN+17*40),<(SCREEN+18*40),<(SCREEN+19*40),<(SCREEN+20*40),<(SCREEN+21*40),<(SCREEN+22*40),<(SCREEN+23*40),<(SCREEN+24*40),<(SCREEN+25*40)
RowHi   .byte >(SCREEN+0*40),>(SCREEN+1*40),>(SCREEN+2*40),>(SCREEN+3*40),>(SCREEN+4*40),>(SCREEN+5*40),>(SCREEN+6*40),>(SCREEN+7*40),>(SCREEN+8*40),>(SCREEN+9*40),>(SCREEN+10*40),>(SCREEN+11*40),>(SCREEN+12*40),>(SCREEN+13*40),>(SCREEN+14*40),>(SCREEN+15*40),>(SCREEN+16*40),>(SCREEN+17*40),>(SCREEN+18*40),>(SCREEN+19*40),>(SCREEN+20*40),>(SCREEN+21*40),>(SCREEN+22*40),>(SCREEN+23*40),>(SCREEN+24*40),>(SCREEN+25*40)

; retezec (screen kody, $FF konec)
PutStr
        ldy #0
PS_l    lda (sptr),y
        cmp #$FF
        beq PS_e
        sta (ptr),y
        iny
        bne PS_l
PS_e    rts

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

        org $7400
DL
        .byte $70                   ; jen 8 prazdnych linek nahore -> misto pro 26 radku
        .byte $42
        dta a(SCREEN)
        :25 .byte $02
        .byte $41
        dta a(DL)

        run start
