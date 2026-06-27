; ============================================================
; ui.asm  --  All User-Interface Drawing Routines
; ============================================================

; ============================================================
; set_status: Copy a string into status_msg (max 40 chars).
; Input: SI = pointer to NUL-terminated source in DS.
; Saves all registers.
; ============================================================
set_status:
    push ax
    push cx
    push si
    push di

    mov  di, status_msg
    mov  cx, 40
.ss_loop:
    lodsb
    mov  [di], al
    inc  di
    or   al, al
    jz   .ss_done
    loop .ss_loop
    mov  byte [di], 0       ; force NUL if string was too long
.ss_done:
    pop  di
    pop  si
    pop  cx
    pop  ax
    ret

; ============================================================
; draw_header: Title bar (row 0) + button bar (row 1).
; Highlights the active mode button.
; Saves all registers.
; ============================================================
draw_header:
    push ax
    push bx
    push cx
    push si

    ; ---- row 0: title ------------------------------------------
    mov  ch, ROW_TITLE
    mov  bl, COLOR_HEADER_BG
    call fill_row

    mov  cl, 0
    mov  bl, COLOR_HEADER_FG
    mov  bh, COLOR_HEADER_BG
    mov  si, str_title
    call draw_string

    ; ---- row 1: button bar -------------------------------------
    mov  ch, ROW_BUTTONS
    mov  bl, COLOR_HEADER_BG
    call fill_row

    mov  cl, 0
    mov  bl, COLOR_HEADER_FG
    mov  bh, COLOR_HEADER_BG
    mov  si, str_buttons
    call draw_string

    ; Highlight active-mode button in bright green
    cmp  byte [current_mode], 0
    je   .hl_ram

.hl_disk:
    ; "[F2]DISK" starts at col 8 in str_buttons
    mov  cl, 8
    mov  ch, ROW_BUTTONS
    mov  bl, COLOR_ACTIVE_FG
    mov  bh, COLOR_ACTIVE_BG
    mov  si, str_btn_disk
    call draw_string
    jmp  .hdr_done

.hl_ram:
    mov  cl, 0
    mov  ch, ROW_BUTTONS
    mov  bl, COLOR_ACTIVE_FG
    mov  bh, COLOR_ACTIVE_BG
    mov  si, str_btn_ram
    call draw_string

.hdr_done:
    pop  si
    pop  cx
    pop  bx
    pop  ax
    ret

; ============================================================
; draw_col_header: Column-label row (row 3).
; Saves all registers.
; ============================================================
draw_col_header:
    push ax
    push bx
    push cx
    push si

    mov  ch, ROW_COL_HDR
    mov  bl, COLOR_BG
    call fill_row

    mov  cl, 0
    mov  bl, COLOR_COL_HDR
    mov  bh, COLOR_BG
    mov  si, str_col_hdr
    call draw_string

    pop  si
    pop  cx
    pop  bx
    pop  ax
    ret

; ============================================================
; draw_mode_info: Mode-specific address / sector line (row 2).
; Saves all registers.
; ============================================================
draw_mode_info:
    push ax
    push bx
    push cx
    push si

    mov  ch, ROW_MODE_INFO
    mov  bl, COLOR_BG
    call fill_row

    mov  cl, 0
    mov  ch, ROW_MODE_INFO
    mov  bh, COLOR_BG

    cmp  byte [current_mode], 0
    je   .ram_info

; ---- disk info ---------------------------------------------
.disk_info:
    mov  bl, COLOR_INFO_FG
    mov  si, str_disk_prefix   ; "DISK DRV:"
    call draw_string

    mov  al, [disk_drv]
    mov  bl, COLOR_INFO_VAL
    call draw_hex_byte         ; CL += 2

    mov  bl, COLOR_INFO_FG
    mov  si, str_disk_cyl      ; " CYL:"
    call draw_string

    mov  al, [disk_cyl]
    mov  bl, COLOR_INFO_VAL
    call draw_hex_byte

    mov  bl, COLOR_INFO_FG
    mov  si, str_disk_hd       ; " HD:"
    call draw_string

    mov  al, [disk_hd]
    mov  bl, COLOR_INFO_VAL
    call draw_hex_byte

    mov  bl, COLOR_INFO_FG
    mov  si, str_disk_sec      ; " SEC:"
    call draw_string

    mov  al, [disk_sec]
    mov  bl, COLOR_INFO_VAL
    call draw_hex_byte

    ; dirty / clean indicator
    cmp  byte [disk_dirty], 0
    je   .show_clean

    mov  bl, COLOR_DIRTY_IND
    mov  si, str_dirty_ind
    call draw_string
    jmp  .mode_done

.show_clean:
    mov  bl, COLOR_CLEAN_IND
    mov  si, str_clean_ind
    call draw_string
    jmp  .mode_done

; ---- RAM info ----------------------------------------------
.ram_info:
    mov  bl, COLOR_INFO_FG
    mov  si, str_ram_prefix    ; "RAM  SEG:"
    call draw_string

    mov  ax, [ram_seg]
    mov  bl, COLOR_INFO_VAL
    call draw_word_hex         ; CL += 4

    mov  bl, COLOR_INFO_FG
    mov  si, str_ram_mid       ; "  OFF:"
    call draw_string

    mov  ax, [ram_off]
    mov  bl, COLOR_INFO_VAL
    call draw_word_hex

.mode_done:
    pop  si
    pop  cx
    pop  bx
    pop  ax
    ret

; ============================================================
; draw_hex_grid: Render the 16×8 hex grid (rows 4-19).
;
; Each row: XXXX  XX XX XX XX XX XX XX XX  ........
;           addr  -------- hex bytes ----  ASCII
; Column layout:
;   0-3   address (4 hex chars)
;   4-5   two spaces
;   6-28  8 hex bytes with spaces between them (8*2 + 7 = 23)
;   29    separator space
;   30-37 8 ASCII chars
;
; Cursor position: highlighted in yellow (or white in edit mode).
; Saves all registers.
; ============================================================
draw_hex_grid:
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    mov  dh, 0              ; DH = row iterator (0-15)

.row_loop:
    ; ---- set screen row ------------------------------------
    mov  ch, ROW_HEX_START
    add  ch, dh             ; CH = character row on screen

    ; ---- fill row background first -------------------------
    mov  bl, COLOR_BG
    call fill_row

    ; ---- draw 4-char address label -------------------------
    mov  cl, 0
    mov  bh, COLOR_BG
    mov  bl, COLOR_ADDR

    call get_row_address    ; DH -> AX
    call draw_word_hex      ; AX displayed at (CL,CH),  CL -> 4

    ; ---- two-space separator -------------------------------
    mov  al, ' '
    call draw_char
    inc  cl                 ; CL = 5
    call draw_char
    inc  cl                 ; CL = 6

    ; ---- draw 8 hex bytes ----------------------------------
    mov  dl, 0              ; DL = column within row (0-7)

.col_loop:
    ; Get byte at [dh, dl]
    push cx
    push dx
    call get_display_byte   ; DH=row, DL=col -> AL
    mov  [_curr_byte], al
    pop  dx
    pop  cx

    ; Determine colour
    mov  al, [_curr_byte]
    call classify_byte      ; AL -> BL
    mov  bh, COLOR_BG

    ; Override with cursor colours if needed
    cmp  dh, [cursor_row]
    jne  .no_cursor_hex
    cmp  dl, [cursor_col]
    jne  .no_cursor_hex

    ; Cursor is here
    cmp  byte [edit_active], 1
    je   .edit_cursor
    mov  bl, COLOR_CURSOR_FG
    mov  bh, COLOR_CURSOR_BG
    jmp  .draw_hex_cell
.edit_cursor:
    mov  bl, COLOR_EDIT_FG
    mov  bh, COLOR_EDIT_BG

.no_cursor_hex:
.draw_hex_cell:
    mov  al, [_curr_byte]
    call draw_hex_byte      ; draw "XX",  CL += 2

    ; space between bytes (not after last one)
    cmp  dl, 7
    je   .no_sep
    mov  al, ' '
    push bx
    mov  bl, COLOR_BG
    mov  bh, COLOR_BG
    call draw_char
    pop  bx
    inc  cl
.no_sep:

    inc  dl
    cmp  dl, BYTES_PER_ROW
    jb   .col_loop
    ; CL = 6 + 7*3 + 2 = 6 + 21 + 2 = 29

    ; ---- separator space -----------------------------------
    mov  al, ' '
    push bx
    mov  bl, COLOR_BG
    mov  bh, COLOR_BG
    call draw_char
    pop  bx
    inc  cl                 ; CL = 30

    ; ---- draw 8 ASCII chars --------------------------------
    mov  dl, 0

.ascii_loop:
    push cx
    push dx
    call get_display_byte   ; DH=row, DL=col -> AL
    pop  dx
    pop  cx

    ; clamp to printable
    cmp  al, 0x20
    jb   .asc_dot
    cmp  al, 0x7E
    jbe  .asc_ok
.asc_dot:
    mov  al, '.'
.asc_ok:
    ; colour
    mov  bl, COLOR_ASCII_CLR
    mov  bh, COLOR_BG

    ; highlight ASCII position of cursor
    cmp  dh, [cursor_row]
    jne  .asc_draw
    cmp  dl, [cursor_col]
    jne  .asc_draw
    mov  bl, COLOR_CURSOR_FG
    mov  bh, COLOR_CURSOR_BG

.asc_draw:
    call draw_char
    inc  cl

    inc  dl
    cmp  dl, BYTES_PER_ROW
    jb   .ascii_loop

    ; ---- advance to next grid row --------------------------
    inc  dh
    cmp  dh, NUM_HEX_ROWS
    jb   .row_loop

    pop  es
    pop  di
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; ============================================================
; draw_byte_info: Current-byte detail line (row 21).
; Saves all registers.
; ============================================================
draw_byte_info:
    push ax
    push bx
    push cx
    push si

    mov  ch, ROW_BYTE_INFO
    mov  bl, COLOR_BG
    call fill_row

    mov  cl, 0
    mov  ch, ROW_BYTE_INFO
    mov  bh, COLOR_BG

    ; Get byte at cursor
    push dx
    mov  dh, [cursor_row]
    mov  dl, [cursor_col]
    call get_display_byte   ; -> AL
    pop  dx
    mov  [_curr_byte], al

    ; Cursor absolute address
    mov  bl, COLOR_INFO_FG
    mov  si, str_bi_addr
    call draw_string

    cmp  byte [current_mode], 0
    je   .bi_ram

.bi_disk:
    ; show sector-relative offset
    xor  ax, ax
    mov  al, [cursor_row]
    shl  al, 3
    xor  ah, ah
    add  al, [cursor_col]
    add  ax, [disk_disp_off]
    mov  bl, COLOR_INFO_VAL
    call draw_word_hex
    jmp  .bi_val

.bi_ram:
    mov  ax, [ram_off]
    xor  bh, bh
    mov  bl, [cursor_row]
    shl  bl, 3
    add  bl, [cursor_col]
    add  ax, bx
    mov  bl, COLOR_INFO_VAL
    call draw_word_hex

.bi_val:
    mov  bl, COLOR_INFO_FG
    mov  si, str_bi_val     ; "  Val:0x"
    call draw_string

    mov  al, [_curr_byte]
    mov  bl, COLOR_INFO_VAL
    call draw_hex_byte

    mov  bl, COLOR_INFO_FG
    mov  si, str_bi_dec     ; "  Dec:"
    call draw_string

    mov  al, [_curr_byte]
    mov  bl, COLOR_INFO_VAL
    call draw_dec_byte

    ; show printable ASCII character if applicable
    mov  al, [_curr_byte]
    cmp  al, 0x20
    jb   .bi_done
    cmp  al, 0x7E
    ja   .bi_done

    mov  bl, COLOR_INFO_FG
    mov  si, str_bi_chr
    call draw_string

    mov  al, [_curr_byte]
    mov  bl, COLOR_ASCII_CLR
    call draw_char
    inc  cl

.bi_done:
    pop  si
    pop  cx
    pop  bx
    pop  ax
    ret

; ============================================================
; draw_help: Two help-text rows (22 and 23).
; Saves all registers.
; ============================================================
draw_help:
    push ax
    push bx
    push cx
    push si

    ; ---- row 22 --------------------------------------------
    mov  ch, ROW_HELP1
    mov  bl, COLOR_BG
    call fill_row

    mov  cl, 0
    mov  bl, COLOR_HELP_FG
    mov  bh, COLOR_BG

    cmp  byte [current_mode], 0
    je   .h1_ram

    mov  si, str_help1_disk
    jmp  .draw_h1
.h1_ram:
    mov  si, str_help1_ram
.draw_h1:
    call draw_string

    ; ---- row 23 --------------------------------------------
    mov  ch, ROW_HELP2
    mov  bl, COLOR_BG
    call fill_row

    mov  cl, 0
    mov  si, str_help2
    call draw_string

    pop  si
    pop  cx
    pop  bx
    pop  ax
    ret

; ============================================================
; draw_status_bar: Status message row (row 24).
; Saves all registers.
; ============================================================
draw_status_bar:
    push ax
    push bx
    push cx
    push si

    mov  ch, ROW_STATUS
    mov  bl, COLOR_STATUS_BG
    call fill_row

    mov  cl, 0
    mov  bl, COLOR_STATUS_FG
    mov  bh, COLOR_STATUS_BG
    mov  si, status_msg
    call draw_string

    pop  si
    pop  cx
    pop  bx
    pop  ax
    ret

; ============================================================
; draw_separator: Thin separator line (row 20).
; ============================================================
draw_separator:
    push ax
    push bx
    push cx
    push si

    mov  ch, ROW_SEPARATOR
    mov  bl, COLOR_SEP
    call fill_row

    mov  cl, 0
    mov  bl, COLOR_SEP
    mov  bh, COLOR_SEP
    mov  si, str_sep
    call draw_string

    pop  si
    pop  cx
    pop  bx
    pop  ax
    ret

; ============================================================
; full_redraw: Redraw every UI element.
; ============================================================
full_redraw:
    call draw_header
    call draw_col_header
    call draw_mode_info
    call draw_separator
    call draw_hex_grid
    call draw_byte_info
    call draw_help
    call draw_status_bar
    ret
