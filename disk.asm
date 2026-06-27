; ============================================================
; disk.asm  --  INT 13h Disk Read/Write via BIOS
; ============================================================

; ---- read_disk_sector ---------------------------------------
; Read the sector described by disk_drv / disk_cyl / disk_hd / disk_sec
; into disk_buf.  Clears dirty flag on success.
; Saves all registers.
read_disk_sector:
    push ax
    push bx
    push cx
    push dx
    push es

    ; Reset disk controller first (improves reliability)
    xor  ax, ax
    mov  dl, [disk_drv]
    int  0x13

    ; Read one sector
    push word 0x0000
    pop  es
    mov  bx, disk_buf           ; ES:BX = 0x0000:disk_buf

    mov  ah, 0x02               ; INT 13h function: Read Sectors
    mov  al, 1                  ; read 1 sector
    mov  ch, [disk_cyl]         ; cylinder
    mov  cl, [disk_sec]         ; sector (1-based)
    mov  dh, [disk_hd]          ; head
    mov  dl, [disk_drv]         ; drive
    int  0x13

    jnc  .rds_ok

    ; Error path
    push si
    mov  si, str_disk_err
    call set_status
    pop  si
    jmp  .rds_done

.rds_ok:
    mov  byte [disk_dirty], 0
    push si
    mov  si, str_disk_ok
    call set_status
    pop  si

.rds_done:
    pop  es
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; ---- write_disk_sector --------------------------------------
; Write disk_buf back to the sector described by disk_drv / disk_cyl /
; disk_hd / disk_sec.  Clears dirty flag on success.
; Saves all registers.
write_disk_sector:
    push ax
    push bx
    push cx
    push dx
    push es

    ; Reset disk controller
    xor  ax, ax
    mov  dl, [disk_drv]
    int  0x13

    push word 0x0000
    pop  es
    mov  bx, disk_buf

    mov  ah, 0x03               ; INT 13h function: Write Sectors
    mov  al, 1
    mov  ch, [disk_cyl]
    mov  cl, [disk_sec]
    mov  dh, [disk_hd]
    mov  dl, [disk_drv]
    int  0x13

    jnc  .wds_ok

    push si
    mov  si, str_write_err
    call set_status
    pop  si
    jmp  .wds_done

.wds_ok:
    mov  byte [disk_dirty], 0
    push si
    mov  si, str_write_ok
    call set_status
    pop  si

.wds_done:
    pop  es
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; ---- load_disk_sector ---------------------------------------
; Convenience wrapper: read sector + reset display offset to 0.
load_disk_sector:
    call read_disk_sector
    mov  word [disk_disp_off], 0
    ret

; ---- next_sector / prev_sector ------------------------------
; Increment or decrement disk_sec, wrapping cylinder/head as needed.
; Both save all registers.

next_sector:
    push ax
    push si

    mov  al, [disk_sec]
    inc  al
    cmp  al, 19             ; sectors 1-18 on a 1.44 MB floppy
    jb   .ns_ok
    ; wrap to sector 1, advance head/cylinder
    mov  al, 1
    mov  byte [disk_sec], al
    mov  al, [disk_hd]
    xor  al, 1              ; toggle head 0<->1
    mov  [disk_hd], al
    jnz  .ns_head_done      ; if head became 1, no cylinder change
    ; head wrapped back to 0 -> increment cylinder
    mov  al, [disk_cyl]
    inc  al
    cmp  al, 80
    jb   .ns_cyl_ok
    mov  al, 0              ; wrap cylinder
.ns_cyl_ok:
    mov  [disk_cyl], al
.ns_head_done:
    call load_disk_sector
    jmp  .ns_done
.ns_ok:
    mov  [disk_sec], al
    call load_disk_sector
.ns_done:
    pop  si
    pop  ax
    ret

prev_sector:
    push ax
    push si

    mov  al, [disk_sec]
    dec  al
    cmp  al, 0              ; below 1? (dec of 1 gives 0)
    jne  .ps_ok             ; nonzero -> valid sector, go use it
    ; wrap back to sector 18, go to previous head/cylinder
    mov  al, 18
    mov  [disk_sec], al
    mov  al, [disk_hd]
    xor  al, 1
    mov  [disk_hd], al
    jnz  .ps_head_done
    ; head wrapped back to 0 -> decrement cylinder
    mov  al, [disk_cyl]
    cmp  al, 0
    je   .ps_done           ; already at cylinder 0 head 0 sec 18, stay
    dec  al
    mov  [disk_cyl], al
.ps_head_done:
    call load_disk_sector
    jmp  .ps_done
.ps_ok:
    mov  [disk_sec], al
    call load_disk_sector
.ps_done:
    pop  si
    pop  ax
    ret
