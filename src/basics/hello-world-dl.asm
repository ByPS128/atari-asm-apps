; Systémové adresy pro práci s obrazovkou a grafikou
SDLSTL  = $230        ; Ukazatel na display list - nízký byte
SDLSTH  = $231        ; Ukazatel na display list - vysoký byte
COLOR2  = $2C6        ; Registr pro barvu pozadí
COLOR1  = $2C5        ; Registr pro barvu textu
SAVMSC  = $58         ; Systémová adresa ukazující na začátek obrazovky

    org $2000         ; Počáteční adresa našeho programu v paměti
		
start   
    ; Nastavení barev pro obrazovku
    lda #$88          ; Načtení hodnoty pro světle modrou barvu
    sta COLOR2        ; Nastavení barvy pozadí
    lda #$0F          ; Načtení hodnoty pro bílou barvu
    sta COLOR1        ; Nastavení barvy textu
    
    ; Inicializace display listu - říká systému, kde najde instrukce pro vykreslování
    lda #<dlist       ; Načtení spodního bytu adresy display listu
    sta SDLSTL        ; Uložení do systémové proměnné
    lda #>dlist       ; Načtení horního bytu adresy display listu
    sta SDLSTH        ; Uložení do systémové proměnné
    
    ; Kopírování textu na obrazovku
    ldx #0            ; Vynulování počítadla
copy_text
    lda message,x     ; Načtení znaku ze zprávy
    beq main_loop     ; Pokud je znak 0, skoč na hlavní smyčku
    sta text_buf,x    ; Ulož znak do video paměti
    inx               ; Zvýšení počítadla
    bne copy_text     ; Opakuj pro další znak

main_loop
    jmp main_loop     ; Nekonečná smyčka - program zde čeká

; Seznam instrukcí pro vykreslování obrazovky
dlist
    .byte $70         ; 8 prázdných řádků na začátku obrazovky
    .byte $42         ; Zapnutí textového módu 2 s načtením adresy paměti
    .word text_buf    ; Adresa, kde začíná náš text
    .byte $02         ; Pokračování v módu 2
    .byte $02         ; Pokračování v módu 2
    .byte $02         ; Pokračování v módu 2
    .byte $41         ; Čekání na vertikální přerušení (synchronizace obrazu)
    .word dlist       ; Skok zpět na začátek display listu

; Text, který chceme zobrazit
message
    .byte "HELLO WORLD!"   ; Náš text s vykřičníkem
    .byte $9B             ; Ukončovací znak řádku pro Atari

; Rezervace paměti pro obrazovku
    org $3000             ; Nastavení nové počáteční adresy
text_buf
    .ds 960              ; Rezervace 960 bajtů pro obrazovku (40x24 znaků)

    run start            ; Nastavení adresy, odkud se program spustí