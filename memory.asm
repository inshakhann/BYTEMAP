; ============================================================
; memory.asm  --  Display-Buffer Memory Accessors
; ============================================================

; ---- get_display_byte ---------------------------------------
; Return the byte at display position (row, col).
; In RAM mode  : reads from [ram_seg:ram_off + row*8 + col].
; In Disk mode : reads from disk_buf[disk_disp_off + row*8 + col].
;
; Input:  DH = row (0-15),  DL = col (0-7)
; Output: AL = byte value
; Saves:  BX, ES (and all others except AL).
get_display_byte:
    push bx
    push es

    ; index = row*8 + col  (0-127)
    xor  bh, bh
    mov  bl, dh
    shl  bl, 3              ; BX = row * 8
    xor  ah, ah
    mov  al, dl
    add  bx, ax             ; BX = row*8 + col

    cmp  byte [current_mode], 0
    je   .ram

.disk:
    add  bx, [disk_disp_off]
    mov  al, [disk_buf + bx]
    jmp  .done

.ram:
    ; ES = ram_seg,  effective address = ram_off + BX
    mov  ax, [ram_seg]
    mov  es, ax
    add  bx, [ram_off]
    mov  al, [es:bx]

.done:
    pop  es
    pop  bx
    ret

; ---- get_row_address ----------------------------------------
; Return the display address (absolute offset) for a given row.
; In RAM mode  : returns ram_off + row*8
; In Disk mode : returns disk_disp_off + row*8
;
; Input:  DH = row (0-15)
; Output: AX = address
; Saves:  BX.
get_row_address:
    push bx

    xor  ah, ah
    mov  al, dh
    shl  ax, 3              ; AX = row * 8

    cmp  byte [current_mode], 0
    je   .ram

.disk:
    add  ax, [disk_disp_off]
    jmp  .done

.ram:
    add  ax, [ram_off]

.done:
    pop  bx
    ret

; ---- write_display_byte -------------------------------------
; Write a byte to the location currently under the cursor.
; In RAM mode  : performs a direct MOV to real memory.
; In Disk mode : modifies disk_buf and sets dirty flag.
;
; Input:  AL = byte to write
; Saves:  all registers.
write_display_byte:
    push ax
    push bx
    push cx
    push es

    mov  cl, al             ; CL = byte to write (free AL for math)

    ; index = cursor_row*8 + cursor_col
    xor  bh, bh
    mov  bl, [cursor_row]
    shl  bl, 3
    xor  ah, ah
    mov  al, [cursor_col]
    add  bx, ax             ; BX = index (0-127)

    cmp  byte [current_mode], 0
    je   .ram

.disk:
    add  bx, [disk_disp_off]
    mov  [disk_buf + bx], cl
    mov  byte [disk_dirty], 1
    push si
    mov  si, str_disk_modif
    call set_status
    pop  si
    jmp  .wdb_done

.ram:
    ; Write directly to live RAM via ES:BX
    mov  ax, [ram_seg]
    mov  es, ax
    add  bx, [ram_off]
    mov  [es:bx], cl
    push si
    mov  si, str_ram_write
    call set_status
    pop  si

.wdb_done:
    pop  es
    pop  cx
    pop  bx
    pop  ax
    ret
