; ============================================================
; input.asm  --  Keyboard Handling (INT 16h)
; ============================================================
; INT 16h AH=0 reads one keystroke.
; Returns AH = BIOS scan code,  AL = ASCII character.
;
; Scan codes for special keys (AL will be 0 or 0xE0):
;   0x48  Up        0x50  Down
;   0x4B  Left      0x4D  Right
;   0x49  Page Up   0x51  Page Down
;
; NOTE: F1/F2 are NOT used because QEMU intercepts function keys
; before they reach the guest OS via INT 16h.  We use plain ASCII
; keys instead:
;   '1'  (0x31)  -> RAM mode      (was F1 scan 0x3B)
;   '2'  (0x32)  -> DISK mode     (was F2 scan 0x3C)
; ============================================================

; ---- read_key -----------------------------------------------
; Block until a key is pressed.
; Output: AH = scan code,  AL = ASCII char.
; Saves nothing (AX is the return value).
read_key:
    xor  ax, ax
    int  0x16
    ret

; ============================================================
; handle_key
; Input:  AX = key from read_key (AH=scan, AL=ASCII)
; Output: AX = 0 (continue)  or  1 (quit)
; Saves:  nothing (AX is return value).
; ============================================================
handle_key:
    push bx
    push cx
    push dx
    push si

    ; ---- if in edit mode, dispatch there -------------------
    cmp  byte [edit_active], 1
    je   .dispatch_edit

    ; ---- ESC -----------------------------------------------
    cmp  al, 0x1B
    je   .key_esc

    ; ---- Enter: start editing current byte -----------------
    cmp  al, 0x0D
    je   .key_enter

    ; ---- '1': switch to RAM mode ---------------------------
    cmp  al, '1'
    je   .key_f1

    ; ---- '2': switch to DISK mode --------------------------
    cmp  al, '2'
    je   .key_f2

    ; ---- Arrow keys ----------------------------------------
    cmp  ah, 0x48
    je   .key_up
    cmp  ah, 0x50
    je   .key_down
    cmp  ah, 0x4B
    je   .key_left
    cmp  ah, 0x4D
    je   .key_right

    ; ---- Page Up -------------------------------------------
    cmp  ah, 0x49
    je   .key_pgup

    ; ---- Page Down -----------------------------------------
    cmp  ah, 0x51
    je   .key_pgdn

    ; ---- mode-specific keys --------------------------------
    cmp  byte [current_mode], 1
    jne  .done_continue

    ; Disk mode only:
    ; W / w  -> write sector
    cmp  al, 'W'
    je   .key_write
    cmp  al, 'w'
    je   .key_write

    ; +/=  -> next sector
    cmp  al, '+'
    je   .key_next_sec
    cmp  al, '='
    je   .key_next_sec

    ; -   -> previous sector
    cmp  al, '-'
    je   .key_prev_sec

    jmp  .done_continue

; ============================================================
; ESC handler  (two-press quit)
; ============================================================
.key_esc:
    cmp  byte [_quit_confirm], 1
    je   .do_quit

    mov  byte [_quit_confirm], 1
    push si
    mov  si, str_quit_conf
    call set_status
    pop  si
    jmp  .done_continue

.do_quit:
    mov  ax, 1              ; signal quit
    jmp  .done

; ============================================================
; Enter: begin byte edit
; ============================================================
.key_enter:
    mov  byte [_quit_confirm], 0
    mov  byte [edit_active], 1
    mov  byte [edit_nibble], 0
    mov  byte [edit_val], 0
    push si
    mov  si, str_edit_hi
    call set_status
    pop  si
    jmp  .done_continue

; ============================================================
; '1': switch to RAM mode
; ============================================================
.key_f1:
    mov  byte [_quit_confirm], 0
    mov  byte [current_mode], 0
    mov  byte [cursor_row], 0
    mov  byte [cursor_col], 0
    jmp  .done_continue

; ============================================================
; '2': switch to DISK mode (load sector on first switch)
; ============================================================
.key_f2:
    mov  byte [_quit_confirm], 0
    cmp  byte [current_mode], 1
    je   .done_continue     ; already in disk mode
    mov  byte [current_mode], 1
    mov  byte [cursor_row], 0
    mov  byte [cursor_col], 0
    call load_disk_sector
    jmp  .done_continue

; ============================================================
; Cursor movement
; ============================================================
.key_up:
    mov  byte [_quit_confirm], 0
    cmp  byte [cursor_row], 0
    je   .done_continue
    dec  byte [cursor_row]
    jmp  .done_continue

.key_down:
    mov  byte [_quit_confirm], 0
    cmp  byte [cursor_row], NUM_HEX_ROWS-1
    je   .done_continue
    inc  byte [cursor_row]
    jmp  .done_continue

.key_left:
    mov  byte [_quit_confirm], 0
    cmp  byte [cursor_col], 0
    je   .wrap_left
    dec  byte [cursor_col]
    jmp  .done_continue
.wrap_left:
    ; wrap to end of previous row
    cmp  byte [cursor_row], 0
    je   .done_continue
    dec  byte [cursor_row]
    mov  byte [cursor_col], BYTES_PER_ROW-1
    jmp  .done_continue

.key_right:
    mov  byte [_quit_confirm], 0
    cmp  byte [cursor_col], BYTES_PER_ROW-1
    je   .wrap_right
    inc  byte [cursor_col]
    jmp  .done_continue
.wrap_right:
    cmp  byte [cursor_row], NUM_HEX_ROWS-1
    je   .done_continue
    mov  byte [cursor_col], 0
    inc  byte [cursor_row]
    jmp  .done_continue

; ============================================================
; Page Up / Page Down
; ============================================================
.key_pgup:
    mov  byte [_quit_confirm], 0
    cmp  byte [current_mode], 0
    je   .pgup_ram

.pgup_disk:
    ; shift display window back 128 bytes within the sector
    cmp  word [disk_disp_off], 0
    je   .done_continue
    sub  word [disk_disp_off], 128
    jmp  .done_continue

.pgup_ram:
    ; scroll RAM view back 128 bytes
    cmp  word [ram_off], 128
    jb   .pgup_ram_clamp
    sub  word [ram_off], 128
    jmp  .done_continue
.pgup_ram_clamp:
    mov  word [ram_off], 0
    push si
    mov  si, str_no_scroll
    call set_status
    pop  si
    jmp  .done_continue

.key_pgdn:
    mov  byte [_quit_confirm], 0
    cmp  byte [current_mode], 0
    je   .pgdn_ram

.pgdn_disk:
    cmp  word [disk_disp_off], 384
    jae  .done_continue
    add  word [disk_disp_off], 128
    jmp  .done_continue

.pgdn_ram:
    add  word [ram_off], 128
    ; allow wrapping (0xFFFF - 127 = max sensible value)
    jmp  .done_continue

; ============================================================
; Disk-mode only keys
; ============================================================
.key_write:
    mov  byte [_quit_confirm], 0
    call write_disk_sector
    jmp  .done_continue

.key_next_sec:
    mov  byte [_quit_confirm], 0
    call next_sector
    jmp  .done_continue

.key_prev_sec:
    mov  byte [_quit_confirm], 0
    call prev_sector
    jmp  .done_continue

; ============================================================
; Edit mode dispatcher
; ============================================================
.dispatch_edit:
    call handle_edit_key
    jmp  .done_continue

; ============================================================
; Normal exit
; ============================================================
.done_continue:
    xor  ax, ax             ; 0 = keep running
.done:
    pop  si
    pop  dx
    pop  cx
    pop  bx
    ret

; ============================================================
; handle_edit_key
; Called when edit_active = 1.
; Accepts 0-9 and A-F as hex digits; ESC cancels.
; After two valid digits, calls write_display_byte.
; Saves: BX, CX, DX, SI.
; ============================================================
handle_edit_key:
    push bx
    push cx
    push dx
    push si

    ; ESC: cancel edit
    cmp  al, 0x1B
    je   .edit_cancel

    ; Convert ASCII key to nibble value
    ; Try 0-9
    cmp  al, '0'
    jb   .edit_invalid
    cmp  al, '9'
    jbe  .is_digit

    ; Try A-F (uppercase)
    cmp  al, 'A'
    jb   .try_lower
    cmp  al, 'F'
    jbe  .is_upper

.try_lower:
    ; Try a-f (lowercase)
    cmp  al, 'a'
    jb   .edit_invalid
    cmp  al, 'f'
    ja   .edit_invalid
    sub  al, 'a' - 'A'     ; convert to uppercase

.is_upper:
    sub  al, 'A' - 10       ; A->10, B->11, ... F->15
    jmp  .got_nibble

.is_digit:
    sub  al, '0'            ; '0'->0 ... '9'->9

.got_nibble:
    ; AL = nibble value (0-15)
    cmp  byte [edit_nibble], 0
    je   .high_nibble

.low_nibble:
    ; Combine with high nibble already in edit_val
    mov  ah, [edit_val]
    shl  ah, 4
    or   ah, al
    ; Call write_display_byte with the assembled byte in AL
    push ax
    mov  al, ah
    call write_display_byte
    pop  ax

    ; Exit edit mode
    mov  byte [edit_active], 0
    mov  byte [edit_nibble], 0
    push si
    mov  si, str_edit_done
    call set_status
    pop  si
    jmp  .edit_done

.high_nibble:
    mov  [edit_val], al         ; store high nibble
    mov  byte [edit_nibble], 1
    ; Update status to show we're waiting for low nibble
    push si
    mov  si, str_edit_lo
    call set_status
    pop  si
    jmp  .edit_done

.edit_invalid:
    jmp  .edit_done             ; ignore invalid keystrokes silently

.edit_cancel:
    mov  byte [edit_active], 0
    mov  byte [edit_nibble], 0
    push si
    mov  si, str_edit_cancel
    call set_status
    pop  si

.edit_done:
    pop  si
    pop  dx
    pop  cx
    pop  bx
    ret
