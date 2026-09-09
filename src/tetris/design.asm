; =====================================================================
;  TETRIS - vizualni demo noveho designu herni obrazovky (staticky mockup)
;  Slouzi k doladeni designu, nez se prepracuje tetris.asm.
;  Cela obrazovka = ANTIC F + GTIA mode 10 (80 px x 176 scanlines), bez textovych
;  radku. Texty jsou "chunky" pismo 3x5 (bod = 1 GTIA px x 2 scanlines).
;  Build:  mads design.asm -o:design.xex
; =====================================================================
DMACTL   = $D400
DLISTL   = $D402
DLISTH   = $D403
NMIEN    = $D40E
VVBLKI   = $0222
XITVBV   = $E462
COLPM0   = $D012
PRIOR    = $D01B
GRACTL   = $D01D
CONSOL   = $D01F
SKCTL    = $D20F

BITMAP    = $5010
BMLINES   = 176
BITMAP102 = BITMAP+102*40

; barvy (hodnota pixelu): 0 = pozadi/okraj (COLPM0), 1-7 tetromina, 8 = ram/text (COLBK)
C_BG   = 0
C_I    = 1
C_O    = 2
C_T    = 3
C_S    = 4
C_Z    = 5
C_J    = 6
C_L    = 7
C_GREY = 8
C_GOLD = C_O               ; hodnoty cisel sdili zlatou s dilkem O

WELL_X   = 28              ; GTIA px leveho okraje studny (sloupec znaku 14)
WELL_Y   = 8               ; scanline horniho okraje studny
PANEL_X  = 54              ; px zacatku praveho panelu (sloupec 27)
HINT_X   = 1               ; px zacatku napovedy vlevo

        org $80
ptr      .byte 0,0
tmp      .byte 0
tmp2     .byte 0
tmp3     .byte 0           ; barva
tmp4     .byte 0
px       .byte 0
py       .byte 0
pw       .byte 0
ph       .byte 0
sptr     .byte 0,0
gx       .byte 0
grow     .byte 0
gbits    .byte 0
sy       .byte 0

.macro RECT               ; RECT x, y, w, h, barva
        lda #:1
        sta px
        lda #:2
        sta py
        lda #:3
        sta pw
        lda #:4
        sta ph
        lda #:5
        sta tmp3
        jsr FillRect
.endm

.macro TEXT               ; TEXT x, y, retezec, barva
        lda #:1
        sta px
        lda #:2
        sta py
        lda #<:3
        sta sptr
        lda #>:3
        sta sptr+1
        lda #:4
        sta tmp3
        jsr DrawStr
.endm

.macro CELL               ; CELL sloupec, radek, barva  (bunka studny 2 px x 7 lin)
        lda #WELL_X+2+2*:1
        sta px
        lda #WELL_Y+8*:2
        sta py
        lda #2
        sta pw
        lda #7
        sta ph
        lda #:3
        sta tmp3
        jsr FillRect
.endm

        org $2000
Colors  .byte $00,$9C,$1C,$5A,$C8,$34,$84,$28,$0A
;             bg   I   O   T   S   Z   J   L  sedy ram

        icl 'font35.inc'

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
        jsr ClearBitmap
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
        lda #$22
        sta DMACTL
        lda #$80
        sta PRIOR
        ldx #8
Vc      lda Colors,x
        sta COLPM0,x
        dex
        bpl Vc
        jmp XITVBV

; ---------------------------------------------------------------------
DrawMockup
        ; --- studna: steny s cihlovym vzorem, dno ---
        RECT WELL_X, WELL_Y, 2, 160, C_GREY
        RECT WELL_X+22, WELL_Y, 2, 160, C_GREY
        RECT WELL_X, WELL_Y+160, 24, 2, C_GREY
        jsr WallSeams
        ; --- obsah studny (ukazka) ---
        CELL 3,2,C_T
        CELL 4,2,C_T
        CELL 5,2,C_T
        CELL 4,1,C_T
        CELL 0,19,C_I
        CELL 1,19,C_I
        CELL 2,19,C_I
        CELL 3,19,C_I
        CELL 4,19,C_L
        CELL 5,19,C_J
        CELL 6,19,C_J
        CELL 7,19,C_Z
        CELL 8,19,C_Z
        CELL 4,18,C_L
        CELL 4,17,C_L
        CELL 5,18,C_J
        CELL 6,18,C_O
        CELL 7,18,C_O
        CELL 6,17,C_O
        CELL 7,17,C_O
        CELL 8,18,C_S
        CELL 9,18,C_S
        CELL 9,17,C_S
        CELL 0,18,C_Z
        CELL 1,18,C_Z
        CELL 1,17,C_Z
        CELL 2,17,C_Z
        CELL 9,19,C_L
        ; --- pravy panel ---
        TEXT PANEL_X, WELL_Y, TxNext, C_GREY
        RECT PANEL_X, WELL_Y+9, 16, 1, C_GREY        ; ramecek NEXT 8x4 bunek
        RECT PANEL_X, WELL_Y+9+33, 16, 1, C_GREY
        RECT PANEL_X, WELL_Y+9, 1, 34, C_GREY
        RECT PANEL_X+15, WELL_Y+9, 1, 34, C_GREY
        ; kus S (1:1 s bunkou studny), vycentrovany v ramecku
        RECT PANEL_X+7, WELL_Y+18, 2, 7, C_S
        RECT PANEL_X+9, WELL_Y+18, 2, 7, C_S
        RECT PANEL_X+5, WELL_Y+26, 2, 7, C_S
        RECT PANEL_X+7, WELL_Y+26, 2, 7, C_S
        TEXT PANEL_X, WELL_Y+52, TxLevel, C_GREY
        TEXT PANEL_X, WELL_Y+62, TxLevelV, C_GOLD
        TEXT PANEL_X, WELL_Y+78, TxScore, C_GREY
        TEXT PANEL_X, WELL_Y+88, TxScoreV, C_GOLD
        TEXT PANEL_X, WELL_Y+104, TxLines, C_GREY
        TEXT PANEL_X, WELL_Y+114, TxLinesV, C_GOLD
        TEXT PANEL_X, WELL_Y+130, TxClear, C_GREY
        TEXT PANEL_X, WELL_Y+140, TxClearV, C_GOLD
        TEXT PANEL_X, WELL_Y+156, TxTime, C_GREY
        TEXT PANEL_X, WELL_Y+166, TxTimeV, C_GOLD
        ; --- napoveda vlevo ---
        TEXT HINT_X, WELL_Y+2, TxH1a, C_GREY
        TEXT HINT_X+4, WELL_Y+12, TxH1b, C_GOLD
        TEXT HINT_X, WELL_Y+28, TxH2a, C_GREY
        TEXT HINT_X+4, WELL_Y+38, TxH2b, C_GOLD
        TEXT HINT_X, WELL_Y+54, TxH3a, C_GREY
        TEXT HINT_X+4, WELL_Y+64, TxH3b, C_GOLD
        TEXT HINT_X, WELL_Y+80, TxH4a, C_GREY
        TEXT HINT_X+4, WELL_Y+90, TxH4b, C_GOLD
        TEXT HINT_X, WELL_Y+106, TxH5a, C_GREY
        TEXT HINT_X+4, WELL_Y+116, TxH5b, C_GOLD
        TEXT HINT_X, WELL_Y+132, TxH6a, C_GREY
        TEXT HINT_X+4, WELL_Y+142, TxH6b, C_GOLD
        TEXT HINT_X, WELL_Y+158, TxSkill, C_GREY
        rts

; cihlove spary: kazdy 4. scanline steny cerny, v sudych "radach" posunuty o 1 px
WallSeams
        lda #WELL_Y+3
        sta py
WS_l    lda #1
        sta ph
        lda #1
        sta pw
        lda #C_BG
        sta tmp3
        lda py
        sec
        sbc #WELL_Y
        and #4                      ; kazda druha rada cihel posunuta
        beq WS_a
        lda #WELL_X+1
        sta px
        jsr FillRect
        lda #WELL_X+22
        sta px
        jsr FillRect
        jmp WS_n
WS_a    lda #WELL_X
        sta px
        jsr FillRect
        lda #WELL_X+23
        sta px
        jsr FillRect
WS_n    lda py
        clc
        adc #4
        sta py
        cmp #WELL_Y+160
        bcc WS_l
        rts

; ---------------------------------------------------------------------
;  Kresleni
; ---------------------------------------------------------------------
ClearBitmap
        lda #<BITMAP
        sta ptr
        lda #>BITMAP
        sta ptr+1
        ldx #28
        lda #0
        tay
CB_l    sta (ptr),y
        iny
        bne CB_l
        inc ptr+1
        dex
        bne CB_l
        rts

; ptr = BITMAP + A*40
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
        rol ptr+1
        sta ptr
        lda ptr+1
        sta tmp2
        lda ptr
        asl
        rol tmp2
        asl
        rol tmp2
        clc
        adc ptr
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

; obdelnik px,py,pw,ph barvou tmp3 (po pixelech, staticke kresleni)
FillRect
        lda ph
        sta tmp4
FR_row  lda py
        clc
        adc tmp4
        sec
        sbc #1
        jsr LinePtr
        ldx pw
        lda px
        sta tmp2
FR_px   lda tmp2
        lsr
        tay
        lda (ptr),y
        bcs FR_odd
        and #$0F
        sta tmp
        lda tmp3
        asl
        asl
        asl
        asl
        ora tmp
        jmp FR_put
FR_odd  and #$F0
        ora tmp3
FR_put  sta (ptr),y
        inc tmp2
        dex
        bne FR_px
        dec tmp4
        bne FR_row
        rts

; retezec (screen kody, $FF konec) na px,py barvou tmp3; glyph 3x5, rozestup 4 px
DrawStr
        ldy #0
DS_l    lda (sptr),y
        cmp #$FF
        beq DS_e
        sty sy
        jsr DrawGlyph
        ldy sy
        iny
        lda px
        clc
        adc #4
        sta px
        bne DS_l
DS_e    rts

; A = screen kod -> glyph na px,py
DrawGlyph
        cmp #0
        beq DG_r                    ; mezera
        cmp #$1A
        bne DG_1
        lda #36
        bne DG_go
DG_1    cmp #$0F
        bne DG_2
        lda #37
        bne DG_go
DG_2    cmp #$0D
        bne DG_3
        lda #38
        bne DG_go
DG_3    cmp #33
        bcc DG_dig
        sec
        sbc #33-10
        bne DG_go
DG_dig  sec
        sbc #16
DG_go   ; index*5
        sta tmp
        asl
        asl
        clc
        adc tmp
        tax                         ; x = offset do fontu
        lda py
        pha
        lda px
        pha
        lda #5
        sta grow
DG_row  lda Font35,x
        sta gbits
        stx gx
        ; 3 body zleva: bit2, bit1, bit0
        lda #1
        sta pw
        lda #2
        sta ph
        lda gbits
        and #4
        beq DG_b1
        jsr FillRect
DG_b1   inc px
        lda gbits
        and #2
        beq DG_b2
        jsr FillRect
DG_b2   inc px
        lda gbits
        and #1
        beq DG_b3
        jsr FillRect
DG_b3   dec px
        dec px
        lda py
        clc
        adc #2
        sta py
        ldx gx
        inx
        dec grow
        bne DG_row
        pla
        sta px
        pla
        sta py
DG_r    rts

; ---------------------------------------------------------------------
TxNext   dta d'NEXT',$FF
TxLevel  dta d'LEVEL',$FF
TxLevelV dta d'03',$FF
TxScore  dta d'SCORE',$FF
TxScoreV dta d'001985',$FF
TxLines  dta d'LINES',$FF
TxLinesV dta d'0013',$FF
TxClear  dta d'ROWS',$FF
TxClearV dta d'03',$FF
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

; ---------------------------------------------------------------------
        org $7000
DL
        .byte $70
        .byte $4F
        dta a(BITMAP)
        :101 .byte $0F
        .byte $4F
        dta a(BITMAP102)
        :73 .byte $0F               ; radky 103..175
        .byte $41
        dta a(DL)

        run start
