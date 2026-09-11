; zdroj: 
; Zpravoda Atari klub Praha
; Přerušení při vertikálním zatemnění
;

; Systémové adresy
    VSCROL  = $D405     ; Vertikální jemný scroll
    NMIEN   = $D40E     ; Povolení NMI přerušení
    SAVMSC  = $58       ; Adresa začátku obrazovky
    VVBLKI  = $0224     ; Vektor pro VBI

    ; Pracovní proměnné
    TIMECNT   = $CE       ; Počítadlo času pro zpoždění
    DELAY     = $CF       ; Hodnota zpoždění
    SCROLLCNT = $CB     ; Počítadlo jemného scrollu
    TMPADDR   = $CC       ; Pomocná adresa pro posun obrazovky

    ; Program začíná na adrese $5000
    org $5000

init    
    pla                 ; Odstranění návratové adresy
    lda #0              
    sta NMIEN          ; Zakázání VBI

    ; Nastavení adresy VBI rutiny
    lda #<start        ; Nižší byte adresy
    sta VVBLKI
    lda #>start        ; Vyšší byte adresy
    sta VVBLKI+1
    
    lda #$40           ; %01000000
    sta NMIEN          ; Povolení pouze VBI
    rts                ; Návrat do BASICu

start   
    php                ; Uložení příznaků
    cld                ; Vypnutí decimálního módu
    
    lda TIMECNT        ; Načtení počítadla času
    inc TIMECNT        ; Inkrementace počítadla
    cmp DELAY          ; Porovnání se zpožděním
    bne return         ; Pokud není čas, skoč na návrat
    
    lda #0
    sta TIMECNT        ; Vynulování počítadla
    
    clc
    lda SCROLLCNT      ; Načtení počítadla scrollu
    adc #1             ; Přičtení jedničky
    sta SCROLLCNT      ; Uložení nové hodnoty
    cmp #16            ; Porovnání s velikostí znaku
    bcs up             ; Pokud >=16, je třeba posunout text
    
    sta VSCROL         ; Nastavení jemného scrollu
    bne return         ; Skok na návrat

up  
    lda #0
    sta VSCROL         ; Vynulování registru VSCROL
    sta SCROLLCNT      ; Vynulování počítadla scrollu

    ; Posun obrazovky o jeden řádek nahoru
    clc
    lda SAVMSC         ; Načtení adresy obrazovky
    adc #20            ; Přičtení délky řádku
    sta TMPADDR        ; Uložení do pomocné adresy
    lda SAVMSC+1
    adc #0             ; Připočtení přenosu
    sta TMPADDR+1

    ldy #0             ; Index pro kopírování
loop    
    lda (TMPADDR),y    ; Načtení zdrojového bytu
    sta (SAVMSC),y     ; Uložení do cílové pozice
    iny
    cpy #220           ; 11 řádků * 20 znaků
    bne loop

return  
    plp                ; Obnovení příznaků
    pla
    tay
    pla
    tax
    pla
    rti                ; Návrat z přerušení
