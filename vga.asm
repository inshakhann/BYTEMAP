; ============================================================
; vga.asm  --  VGA Mode 13h (320x200, 256-colour) Routines
; ============================================================

; ---- init_vga -----------------------------------------------
; Switch to VGA Mode 13h.
; No inputs.  Trashes nothing (AX is internal only).
init_vga:
    mov  ax, 0x0013
    int  0x10
    ret

; ---- init_font ----------------------------------------------
; Copy the BIOS 8x8 ROM font (256 chars × 8 bytes = 2048 bytes)
; into font_buf so we can access it in DS segment.
; Uses INT 10h AX=1130h BH=06h -> ES:BP = font pointer.
; Saves all registers.
init_font:
    push ax
    push cx
    push si
    push di
    push ds
    push es

    ; Ask BIOS for pointer to 8x8 font
    mov  ax, 0x1130
    mov  bh, 0x06
    int  0x10
    ; ES:BP  = pointer to font data in ROM

    ; We want: DS:SI = ES:BP (source), ES:DI = 0x0000:font_buf (dest)
    ; Save our segment (0x0000) in AX
    mov  ax, ds             ; AX = our DS (0x0000)

    ; Point DS at the font ROM segment (currently ES)
    push es
    pop  ds                 ; DS = font ROM segment
    mov  si, bp             ; SI = font ROM offset

    ; Point ES at our segment for writing
    mov  es, ax             ; ES = 0x0000
    mov  di, font_buf       ; DI = font_buf offset

    mov  cx, 2048
    rep  movsb              ; copy 2048 bytes DS:SI -> ES:DI

    pop  es
    pop  ds
    pop  di
    pop  si
    pop  cx
    pop  ax
    ret

; ---- clear_screen -------------------------------------------
; Fill the entire 320×200 framebuffer with one colour.
; Input:  BL = fill colour
; Saves all registers.
clear_screen:
    push ax
    push cx
    push di
    push es

    push word 0xA000
    pop  es
    xor  di, di
    mov  al, bl
    mov  ah, al
    mov  cx, 32000          ; 320*200/2 words
    rep  stosw

    pop  es
    pop  di
    pop  cx
    pop  ax
    ret

; ---- fill_row -----------------------------------------------
; Fill one character row (8 pixel rows × 320 pixels) with a colour.
; Input:  CH = character row (0-24),  BL = fill colour
; Saves all registers.
fill_row:
    push ax
    push bx
    push cx
    push dx                 ; *** must save DX: MUL below clobbers DX ***
    push di
    push es

    push word 0xA000
    pop  es

    ; Starting video offset = CH * 8 * 320  = CH * 2560
    xor  ah, ah
    mov  al, ch             ; AX = row
    shl  ax, 3              ; AX = row * 8  (pixel row)
    push bx
    mov  bx, 320
    mul  bx                 ; AX = pixel_row * 320  (DX = 0 for valid rows)
    pop  bx
    mov  di, ax             ; DI = starting offset in video memory

    mov  al, bl
    mov  ah, al
    mov  cx, 8*320/2        ; 1280 words  (8 pixel rows * 320 px / 2)
    rep  stosw

    pop  es
    pop  di
    pop  dx                 ; *** restore DX (MUL had set it to 0) ***
    pop  cx
    pop  bx
    pop  ax
    ret

; ---- draw_char ----------------------------------------------
; Draw one 8×8 character at a character-grid position.
; Input:  AL = ASCII code
;         BL = foreground colour
;         BH = background colour  (use 0xFF to paint FG only)
;         CL = character column   (0-39)
;         CH = character row      (0-24)
; Saves ALL registers (pure function – no side effects).
draw_char:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    ; ---- save parameters to non-volatile temps ---------------
    mov  [_dc_char], al
    mov  [_dc_fg],   bl
    mov  [_dc_bg],   bh

    ; ---- calculate starting video-memory offset --------------
    ; pixel_y = CH * 8,  pixel_x = CL * 8
    ; offset  = pixel_y * 320 + pixel_x
    xor  ah, ah
    mov  al, ch             ; AX = row
    shl  ax, 3              ; AX = row * 8
    push bx
    mov  bx, 320
    mul  bx                 ; AX = pixel_y * 320  (< 65536 for row <= 24)
    pop  bx
    xor  dh, dh
    mov  dl, cl
    shl  dx, 3              ; DX = col * 8
    add  ax, dx
    mov  di, ax             ; DI = starting video offset

    ; ---- point ES at video memory ----------------------------
    push word 0xA000
    pop  es

    ; ---- point SI at font glyph ------------------------------
    xor  ah, ah
    mov  al, [_dc_char]
    shl  ax, 3              ; AX = char * 8
    add  ax, font_buf       ; AX = address of glyph in DS
    mov  si, ax

    ; ---- render 8 rows × 8 columns ---------------------------
    mov  dh, 8              ; outer: row counter
.dc_row:
    mov  al, [si]           ; font byte for this pixel row
    inc  si
    mov  ah, 0x80           ; bit mask: MSB = leftmost pixel
    mov  dl, 8              ; inner: column counter
.dc_col:
    test al, ah
    jnz  .dc_fg
.dc_bg:
    mov  bl, [_dc_bg]
    cmp  bl, 0xFF
    je   .dc_skip
    mov  [es:di], bl
    jmp  .dc_skip
.dc_fg:
    mov  bl, [_dc_fg]
    mov  [es:di], bl
.dc_skip:
    inc  di
    shr  ah, 1
    dec  dl
    jnz  .dc_col
    add  di, 320-8          ; skip to next pixel row
    dec  dh
    jnz  .dc_row

    pop  es
    pop  di
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; ---- draw_string --------------------------------------------
; Draw a NUL-terminated string from DS:SI.
; Input:  SI = string pointer
;         BL = foreground colour,  BH = background colour
;         CL = starting column (MODIFIED – advances past string)
;         CH = character row
; Saves: AX, BX, SI, DI, ES  (CL is advanced, not restored).
draw_string:
    push ax
    push bx
    push si
    push di
    push es

.ds_loop:
    lodsb                   ; AL = char,  SI++
    or   al, al
    jz   .ds_done
    call draw_char          ; draw at (CL, CH) – doesn't touch CL
    inc  cl
    cmp  cl, SCREEN_COLS
    jb   .ds_loop           ; stop if we run past column 39
.ds_done:
    pop  es
    pop  di
    pop  si
    pop  bx
    pop  ax
    ret
