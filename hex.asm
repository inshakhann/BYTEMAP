; ============================================================
; hex.asm  --  Nibble/Byte/Word Conversion and Drawing
; ============================================================

; ---- nibble_to_char -----------------------------------------
nibble_to_char:
    and  al, 0x0F
    cmp  al, 10
    jb   .digit
    add  al, 'A' - 10
    ret
.digit:
    add  al, '0'
    ret

; ---- classify_byte ------------------------------------------
; Input: AL = byte  -> Output: BL = colour  (saves all except BL)
classify_byte:
    cmp  al, 0x00
    je   .null
    cmp  al, 0x20
    jb   .not_ascii
    cmp  al, 0x7E
    ja   .not_ascii
    mov  bl, COLOR_ASCII_CLR
    ret
.not_ascii:
    cmp  al, 0x10
    jb   .opcode
    cmp  al, 0x40
    jb   .mid
    cmp  al, 0x5F
    jbe  .opcode
.mid:
    cmp  al, 0x70
    jb   .hi
    cmp  al, 0x7F
    jbe  .opcode
.hi:
    cmp  al, 0xB0
    jb   .cr
    cmp  al, 0xBF
    jbe  .opcode
.cr:
    cmp  al, 0xC0
    jb   .er
    cmp  al, 0xCF
    jbe  .opcode
.er:
    cmp  al, 0xE0
    jb   .ffchk
    cmp  al, 0xEF
    jbe  .opcode
.ffchk:
    cmp  al, 0xFF
    je   .opcode
    mov  bl, COLOR_DATA
    ret
.null:   mov bl, COLOR_NULL   ; ret
    ret
.opcode: mov bl, COLOR_OPCODE
    ret

; ---- draw_hex_byte ------------------------------------------
; Draw byte as "XX".  CL advanced by 2.  Saves AX BX DX SI DI ES.
draw_hex_byte:
    push ax
    push bx
    push dx
    push si
    push di
    push es

    mov  [_curr_byte], al
    shr  al, 4
    call nibble_to_char
    mov  [_hex_hi], al
    mov  al, [_curr_byte]
    and  al, 0x0F
    call nibble_to_char
    mov  [_hex_lo], al

    mov  al, [_hex_hi]
    call draw_char
    inc  cl
    mov  al, [_hex_lo]
    call draw_char
    inc  cl

    pop  es
    pop  di
    pop  si
    pop  dx
    pop  bx
    pop  ax
    ret

; ---- draw_word_hex ------------------------------------------
; Draw word as "XXXX".  CL advanced by 4.  Saves AX BX DX SI DI ES.
draw_word_hex:
    push ax
    push bx
    push dx
    push si
    push di
    push es

    push ax
    mov  al, ah
    call draw_hex_byte
    pop  ax
    call draw_hex_byte

    pop  es
    pop  di
    pop  si
    pop  dx
    pop  bx
    pop  ax
    ret

; ---- draw_dec_byte ------------------------------------------
; Draw byte as "000"-"255".  CL advanced by 3.  Saves AX BX DX SI DI ES.
draw_dec_byte:
    push ax
    push bx
    push dx
    push si
    push di
    push es

    xor  ah, ah
    mov  dl, 100
    div  dl
    add  al, '0'
    mov  [_hex_hi], al      ; hundreds
    mov  al, ah
    xor  ah, ah
    mov  dl, 10
    div  dl
    add  al, '0'
    mov  [_hex_lo], al      ; tens
    add  ah, '0'
    mov  [_curr_byte], ah   ; units

    mov  al, [_hex_hi]
    call draw_char
    inc  cl
    mov  al, [_hex_lo]
    call draw_char
    inc  cl
    mov  al, [_curr_byte]
    call draw_char
    inc  cl

    pop  es
    pop  di
    pop  si
    pop  dx
    pop  bx
    pop  ax
    ret
