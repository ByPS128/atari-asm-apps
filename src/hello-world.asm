; Hello World! program pro Atari 800/XL/XE
; Překládej v MADS assembler kompilátoru

; Systémové adresy
SCREEN  = $BC40       ; Adresa obrazovky

    org $2000         ; Počáteční adresa programu

start   
	jsr print_text    ; Tisk textu
    jmp main_loop     ; Skoč na hlavní smyčku
    
print_text
    ldx #0            ; Vynulování počítadla
print_loop
    lda message,x     ; Načtení znaku z textu
    cmp #$9B          ; Kontrola na konec řádku
    beq print_done    ; Pokud konec textu, konec
    sta SCREEN,x      ; Ulož znak do videopaměti
    inx               ; Další znak
    bne print_loop    ; Opakuj dokud X nepřeteče
print_done
    rts               ; Návrat z podprogramu

main_loop
    jmp main_loop     ; Nekonečná smyčka

message
    .byte "Hello World!"    ; Text k zobrazení
    .byte $9B               ; Znak konce řádku pro Atari

    run start               ; Nastavení adresy pro spuštění
