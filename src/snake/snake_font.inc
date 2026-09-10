; Generovano gen_font.py - NEEDITOVAT rucne. Glyfy hada, interni kody od $60.
SnakeGlyphs
        .byte $00,$FF,$FF,$FF,$FF,$FF,$FF,$00   ; $60 BODY_H
        .byte $7E,$7E,$7E,$7E,$7E,$7E,$7E,$7E   ; $61 BODY_V
        .byte $7E,$FE,$FE,$FE,$FE,$FE,$7E,$00   ; $62 CORNER_LU
        .byte $00,$7E,$FE,$FE,$FE,$FE,$FE,$7E   ; $63 CORNER_LD
        .byte $7E,$7F,$7F,$7F,$7F,$7F,$7E,$00   ; $64 CORNER_RU
        .byte $00,$7E,$7F,$7F,$7F,$7F,$7F,$7E   ; $65 CORNER_RD
        .byte $18,$3C,$7E,$7E,$5A,$7E,$7E,$7E   ; $66 HEAD_U
        .byte $00,$FC,$EE,$FF,$FF,$EE,$FC,$00   ; $67 HEAD_R
        .byte $7E,$7E,$7E,$5A,$7E,$7E,$3C,$18   ; $68 HEAD_D
        .byte $00,$3F,$77,$FF,$FF,$77,$3F,$00   ; $69 HEAD_L
        .byte $7E,$7E,$7E,$3C,$3C,$18,$18,$00   ; $6A TAIL_U
        .byte $00,$07,$1F,$7F,$7F,$1F,$07,$00   ; $6B TAIL_R
        .byte $00,$18,$18,$3C,$3C,$7E,$7E,$7E   ; $6C TAIL_D
        .byte $00,$E0,$F8,$FE,$FE,$F8,$E0,$00   ; $6D TAIL_L
        .byte $10,$30,$7E,$FF,$FF,$FF,$7E,$3C   ; $6E APPLE
SNAKE_GLYPHS = 15
