;
; Překládej v MADS
;

; Systémové adresy
SCREEN  = $BC40                     ; Adresa obrazovky
RTCLOK  = $12                       ; Real-time clock
CONSOL  = $D01F                     ; Console speaker
KEYBDV  = $E420                     ; Keyboard handler vector
KGETCH  = $F6                       ; Key Get Character
ANTIC    = $D400                    
WSYNC    = ANTIC+10

; Systémové rutiny, viz https://atariwiki.org/wiki/Wiki.jsp?page=Atari%20800%20ROM%20OS%20Source%20Listing
; adresy rutin v OS Atari, prefixuji je OS
OSBELL     = $F556
OSKEYCLICK = $F983

; Lokální proměnné 
FREQ       = $CB                    ; Frequency counter


              org $2000             ; Počáteční adresa programu
              
start   
               lda #<DBGT_STR_ACCU    ; Nastav nízký byte ukazatele
               sta DBUG_PTR_L
               lda #>DBGT_STR_ACCU    ; Nastav vysoký byte ukazatele
               sta DBUG_PTR_H
               jsr DBG_PRINT          ; Zavolej výpis textu 'accu: '
               jsr OSKEYCLICK
               lda #$37              ; Příklad hodnoty A registru
               jsr DBG_PRINT_A        ; Zavolej výpis hodnoty A
               jsr DBG_PRINT_CRLF     ; Nový řádek               

               ; Test výpisu paměti
               lda #<$2000           ; Adresa pro výpis
               sta DBUG_PTR_L
               lda #>$2000
               sta DBUG_PTR_H
               lda #5                ; Počet řádků
               jsr DBG_DUMP_MEM       ; Vypíšu paměť
        
               jmp MAIN_LOOP
 
               
              ;jsr beep1
              ;jsr waitforkey

              ; zvuk stiskné klávesy
              ;jsr OSKEYCLICK
              ;LDX $01                ; počkám 1 sekundu
              ;JSR DELAY_SEC
              ;jsr CLICK              ; přehraju stejný zvuk lokální implementací

              ; zvuk před prací s kazeťákem
              ;lda #$03              ; 3x demo beep (typycky 1x load, 2x save)
              ;jsr beep

              ; zvuk znaku $7D (125) 
              jsr OSBELL            ; volám rutinu v OS pro generování zvuku BELL
              LDY 50                ; počkám 0.5 sekundy
              JSR DBG_WAIT_Y10_MS
              jsr DBG_BELL              ; vlastní implementace generování zvuku BELL
              
MAIN_LOOP:    jmp MAIN_LOOP         ; nekonečná smyčka
    
;-----------------------------------------------------------
; BEEP 1x
;-----------------------------------------------------------
DBG_BEEP_ONE_TIME:
              lda $01               ; pípne 1x
              jmp DBG_BEEP
                            
;-----------------------------------------------------------
; BEEP 2x
;-----------------------------------------------------------
DBG_BEEP_TWO_TIMES:
              lda $02               ; pípne 2x
              jmp DBG_BEEP

;-----------------------------------------------------------
; BEEP - GENERATE TONE ON KEYBOARD SPEAKER
; ON ENTRY A= count of repeations
;-----------------------------------------------------------
DBG_BEEP:
              sta FREQ
@beeploop:    lda RTCLOK+2          ; Current clock
              clc 
          .ifdef PAL
              adc #25
          .else
              adc #30               ; 1 sec tone
          .endif
              tax 
@wfl:         lda #$FF
              sta CONSOL            ; Turn on speaker
              lda #0
              ldy #$F0              ; zpomalení
@loop_inc:    dey             
              bne @loop_inc
              sta CONSOL            ; Turn off speaker
              ldy #$F0              ; zpomalení
@loop_dec:    dey
              bne @loop_dec
              cpx RTCLOK+2          ; See if 1 sec is up yet
              bne @wfl
              dec FREQ              ; Count beeps
              beq @beepend          ; If all done go wait for key
              txa
              clc
          .ifdef PAL
              adc #8
          .else
              adc #10
          .endif
              tax
@wait:        cpx RTCLOK+2
              bne @wait
              beq @beeploop         ; Uncond do beep again
@beepend:     rts

;-----------------------------------------------------------
; CLICK: MAKE CLICK THROUGH KEYBOARD SPEAKER
;-----------------------------------------------------------
DBG_CLICK:
                 LDX  #$7F             ; inicializuje X na hodnotu 127
@loop_DBG_CLICK: STX  CONSOL           ; uloží hodnotu X do CONSOL registru (ovládá speaker)
                 STX  WSYNC            ; synchronizace s HBLANK intervalem
                 DEX                   ; dekrementuje X 
                 BPL  @loop_DBG_CLICK  ; pokračuje dokud X není negativní
                 RTS                   ; návrat
        
;-----------------------------------------------------------
; čaká na klávesu
;-----------------------------------------------------------
DBG_WAIT_FOR_KEY:
                           jsr @wfak1_DBG_WAIT_FOR_KEY ; Use simulated "JMP (KGETCH)"
                           tya
                           rts
@wfak1_DBG_WAIT_FOR_KEY:   lda KEYBDV+5
                           pha
                           lda KEYBDV+4          ; Simulate "JMP (KGETCH)"
                           pha
                           rts
                          
;-----------------------------------------------------------
; Bell sound
;-----------------------------------------------------------
DBG_BELL:         LDY  #$20             ; hodnota časování/délky zvuku
@loop_DBG_BELL:   JSR  DBG_CLICK        ; zavolá rutinu DBG_CLICK pro generování zvuku  
                  DEY                   ; dekrementuje Y
                  BPL  @loop_DBG_BELL   ; opakuje dokud Y není negativní
                  RTS
              
;-----------------------------------------------------------
; Vstup: Y = počet 10ms intervalů
; Zachovává hodnotu X a A z volajícího
; (Y mění dle logiky cyklu)
;-----------------------------------------------------------
DBG_WAIT_Y10_MS:
    CPY #0
    BEQ @done_DBG_WAIT_Y10_MS
@loop_DBG_WAIT_Y10_MS:
    JSR DBG_DELLAY_10_MS
    DEY
    BNE @loop_DBG_WAIT_Y10_MS
@done_DBG_WAIT_Y10_MS:
    RTS


;-----------------------------------------------------------
; Delay10ms
; - zavolá Delay1ms desetkrát
; Zachovává hodnotu X a A z volajícího
;-----------------------------------------------------------
DBG_DELLAY_10_MS:
    TXA         ; uložíme volajícího X do A
    PHA         ; push A na stack (schováme X)
    LDX #10
@loop_DBG_DELLAY_10_MS:
    JSR DBG_DELLAY_1_MS
    DEX
    BNE @loop_DBG_DELLAY_10_MS
    PLA         ; vytáhneme původní X ze stacku
    TAX
    RTS


;-----------------------------------------------------------
; Čeká zhruba 1ms smyčkou pro ~1.79 MHz CPU (NTSC)
;   (na PAL (~1.77 MHz) to bude o něco déle než 1ms)
; Zachovává Y a A z volajícího
;-----------------------------------------------------------
DBG_DELLAY_1_MS:
    TYA         ; uložíme volajícího Y do A
    PHA         ; push A na stack (schováme Y)
    LDY #240    ; lokální smyčka
@loop_DBG_DELLAY_1_MS:
    NOP
    NOP
    DEY
    BNE @loop_DBG_DELLAY_1_MS
    PLA         ; původní hodnota Y ze stacku
    TAY
    RTS
                     
; Debug knihovna pro Atari XL/XE
; Vyžaduje základní textový mód

;opt ?+

; Systémové adresy
OS_OUTCH    = $F1B4       ; OUTPUT CHAR TO SCREEN
OS_CURSEOL  = $F661       ; CURSOR TO END OF LINE
OS_ROWCRS   = $54         ; Aktuální řádek 
OS_COLCRS   = $55         ; Aktuální sloupec
OS_ATACHR   = $02FB       ; ATASCII znak
OS_CRSINH   = $02F0       ; Cursor inhibit flag

; Konstanty
BRK         = $00         ; Konec řetězce
ESCAPE      = $1B         ; ESC
EOL         = $9B         ; End of line
    
DEBUG_START = $6000        ; Začátek debug knihovny
DBUG_PTR_L = $F0          ; ZP - pointer low
DBUG_PTR_H = $F1          ; ZP - pointer high

    org DEBUG_START        

; Rutiny pro hexadecimální výpisy

;-----------------------------------------------------------
; Vytiskne obsah A registru hexa  
;-----------------------------------------------------------
DBG_PRINT_A:  
    pha                        ; Zachráním A
    jsr DBG_PRINT_BYTE
    pla                    
    rts

;-----------------------------------------------------------
; Vytiskne obsah X registru hexa
;-----------------------------------------------------------
DBG_PRINT_X:
    pha                        ; Zachráním A
    txa                        ; X -> A
    jsr DBG_PRINT_BYTE
    pla
    rts

;-----------------------------------------------------------
; Vytiskne obsah Y registru hexa
;-----------------------------------------------------------
DBG_PRINT_Y:
    pha                        ; Zachráním A
    tya                        ; Y -> A
    jsr DBG_PRINT_BYTE
    pla
    rts

;-----------------------------------------------------------
; Vytiskne bajt v A hexa
;-----------------------------------------------------------
DBG_PRINT_BYTE:
    pha                      ; Uschovám originál vstupu
    pha                      ; Uschovám originál
    jsr DBGI_CURSOR_OFF       ; Vypnu kurzor před EOL
@high_byte_DB_PRINT_BYTE:
    lsr
    lsr
    lsr
    lsr                      ; Horní nibble
    tax
    lda DBGT_HEX_DIGITS,x    ; Převedu na ASCII
    jsr DBGI_PUT_CHAR        ; Vytisknu
@low_byte_DBG_PRINT_BYTE:    
    pla                      ; Vytáhnu originál
    and #$0F                 ; Ponechám dolní nibble
    tax
    lda DBGT_HEX_DIGITS,x
    jsr DBGI_PUT_CHAR
    jsr DBGI_CURSOR_ON       ; Vypnu kurzor před EOL
    pla                      ; Vytáhnu originál vstupu
    rts

;-----------------------------------------------------------
; Vytiskne word na který ukazuje DBUG_PTR_L/H
;-----------------------------------------------------------
DBG_PRINT_WORD:    
    ldy #1
    lda (DBUG_PTR_L),y      ; Nejdřív hi bajt
    jsr DBG_PRINT_BYTE
    dey
    lda (DBUG_PTR_L),y      ; Pak lo bajt  
    jsr DBG_PRINT_BYTE
    rts

;-----------------------------------------------------------
; Vytiskne adresu pro memory dump
; Vstup: DBUG_PTR_L/H = adresa k výpisu
;-----------------------------------------------------------
DBG_PRINT_DUMP_ADDRESS:
    lda DBUG_PTR_H          ; Nejdřív vytisknu hi bajt adresy
    jsr DBG_PRINT_BYTE
    lda DBUG_PTR_L          ; Pak vytisknu lo bajt adresy
    jsr DBG_PRINT_BYTE
    rts

;-----------------------------------------------------------
; Interní rutina pro výstup znaku
; Vstup: A = ASCII znak
;-----------------------------------------------------------
DBGI_PUT_CHAR_TMP_A  dta 0   ; Pomocná proměnná pro A
DBGI_PUT_CHAR:
    sta DBGI_PUT_CHAR_TMP_A  ; Nejdřív uložím A do paměti
    txa                     ; Pak můžu X a Y dát na stack
    pha                     ; přes A, které už mám uložené 
    tya
    pha
    lda DBGI_PUT_CHAR_TMP_A  ; Původní A je v paměti
        
    sta OS_ATACHR           ; Nastavím znak
    jsr OS_OUTCH            ; Vytisknu
    
    pla                     ; Obnovím v opačném pořadí:
    tay                     ; Nejdřív Y ze stacku
    pla                     ; Pak X ze stacku  
    tax
    lda DBGI_PUT_CHAR_TMP_A  ; A nakonec A z paměti
    rts                     ; vrátím se
        
;-----------------------------------------------------------
; Vytiskne nový řádek 
;-----------------------------------------------------------
DBG_PRINT_CRLF:
    pha
    jsr DBGI_CURSOR_OFF     ; Vypnu kurzor před EOL
    lda #EOL
    jsr DBGI_PUT_CHAR 
    jsr DBGI_CURSOR_ON      ; Znovu zapnu kurzor
    pla
    rts

;-----------------------------------------------------------
; Vytiskne text na který ukazuje DBUG_PTR_L/H 
; Text musí být ukončen BRK (0)
;-----------------------------------------------------------
DBG_PRINT:
    ldy #0                ; Inicializace indexu
@loop_DBG_PRINT:    
    lda (DBUG_PTR_L),y    ; Načtu znak
    cmp #BRK              ; Je konec řetězce?
    beq @done_DBG_PRINT
    cpy #255              ; Kontrola přetečení délky
    beq @done_DBG_PRINT     
    
    tya                   ; Uschovám Y
    pha

    lda (DBUG_PTR_L),y    ; Načtu znak
    jsr DBGI_PUT_CHAR     ; Vytisknu znak
    pla                   ; Obnovím Y
    tay

    iny                   ; Další znak
    bne @loop_DBG_PRINT    ; Pokud Y nepřeteklo, pokračuji

@done_DBG_PRINT:
    rts

;-----------------------------------------------------------
; Vytiskne mezeru
;-----------------------------------------------------------
DBG_PRINT_SPACE:
    pha
    lda #' '
    jsr DBGI_PUT_CHAR
    pla
    rts

;-----------------------------------------------------------
; Vytiskne dvojtečku
;-----------------------------------------------------------
DBG_PRINT_COLON:
    pha  
    lda #':'
    jsr DBGI_PUT_CHAR
    pla
    rts
    
;-----------------------------------------------------------
; Interní rutiny pro práci s kurzorem
;-----------------------------------------------------------
DBGI_CURSOR_OFF:
    pha
    lda #1
    sta OS_CRSINH         ; Nastavím inhibit kurzoru
    pla
    rts

DBGI_CURSOR_ON:  
    pha
    lda #0
    sta OS_CRSINH         ; Zruším inhibit kurzoru
    pla
    rts
    
; Konstanty pro formátování výpisu
BYTES_PER_LINE = 8           ; Počet bajtů na řádek
ADDR_SIZE = 4                ; Délka adresy v hexa

;-----------------------------------------------------------
; DB_DUMP_MEM Vypíše N řádků paměti (N je v A)
; Rutina pro výpis memory dumpu N řádků (počet v A)
;-----------------------------------------------------------
DBG_DUMP_COUNT   dta 0        ; Počítadlo řádků       
DBG_DUMP_MEM:
      sta DBG_DUMP_COUNT     ; Uložím počet řádků
      jsr DBGI_CURSOR_OFF    ; Vypnu kurzor na začátku výpisu (prevence blikání)
@loop_DBG_DUMP_MEM:
      jsr DBG_DUMP_MEM_CONT  ; Vypíšu jeden řádek bez manipulace kurzoru
      dec DBG_DUMP_COUNT     ; Snížím počítadlo řádků
      bne @loop_DBG_DUMP_MEM ; Pokud nejsme na konci, další řádek
      jsr DBGI_CURSOR_ON     ; Na konci výpisu znovu zapnu kurzor
      rts

;-----------------------------------------------------------
; Vypíše jeden řádek paměti včetně hex a ASCII hodnot
; a posune ukazatel na další řádek
;-----------------------------------------------------------
DBG_DUMP_MEM_CONT
      pha                   ; Uschovám registry
      txa 
      pha
      tya
      pha

      jsr DBG_PRINT_DUMP_ADDRESS    ; Vypíšu adresu
      lda #':'                      ; Oddělovač adresy a dat
      jsr DBGI_PUT_CHAR
       
      ; Výpis hexa hodnot
      ldy #0                ; Index do vypisovaných dat
@hex_loop_DBG_DUMP_MEM_CONT:
      lda (DBUG_PTR_L),y    ; Načtu bajt
      jsr DBG_PRINT_BYTE     ; Vypíšu jako hex
      jsr DBG_PRINT_SPACE    ; Oddělovač
      iny
      cpy #BYTES_PER_LINE   ; Už jsem vypsal celý řádek?
      bne @hex_loop_DBG_DUMP_MEM_CONT         ; Ne - pokračuju

      jsr DBG_PRINT_SPACE    ; Oddělovač hex a ASCII části

      ; Výpis ASCII hodnot 
      ldy #0                ; Znovu od začátku řádku
@ascii_loop_DBG_DUMP_MEM_CONT:
      lda (DBUG_PTR_L),y    ; Načtu bajt     
      and #$7F              ; Odstraním nejvyšší bit
      cmp #$20              ; Je to tisknutelný znak?
      bcc @notprint_DBG_DUMP_MEM_CONT         ; < 32 = netisknutelný
      cmp #$7F            
      bcs @notprint_DBG_DUMP_MEM_CONT         ; >= 127 = netisknutelný
      jmp @print_DBG_DUMP_MEM_CONT            ; Jinak vytisknu znak
@notprint_DBG_DUMP_MEM_CONT:
      lda #'.'             ; Netisknutelný = tečka
@print_DBG_DUMP_MEM_CONT:  
      jsr DBGI_PUT_CHAR      ; Vypíšu znak
      iny
      cpy #BYTES_PER_LINE   ; Konec řádku?
      bne @ascii_loop_DBG_DUMP_MEM_CONT

      ;jsr OS_CURSEOL        ; Přesunu kurzor na začátek dalšího řádku

      ; Posun ukazatele o délku řádku
      clc
      lda DBUG_PTR_L
      adc #BYTES_PER_LINE   ; Přičtu délku řádku
      sta DBUG_PTR_L
      bcc @skip_DBG_DUMP_MEM_CONT             ; Přenos?
      inc DBUG_PTR_H        ; Zvýším horní byte
@skip_DBG_DUMP_MEM_CONT:
      pla                   ; Obnovím registry
      tay
      pla  
      tax
      pla
      rts
                  
;-----------------------------------------------------------
                  
DBGT_HEX_DIGITS
    dta '0123456789ABCDEF'
DBGT_STR_ACCU
    dta 'acu: ', BRK
DBGT_STR_X
    dta 'x: ', BRK
DBGT_STR_Y
    dta 'y: ', BRK
    
;-----------------------------------------------------------
    
              run start             ; Nastavení adresy pro spuštění
