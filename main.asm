; ============================================================
; main.asm  --  ByteMap Main Program
; ============================================================
; Assembled with [ORG 0x7E00].
; Loaded by boot.asm at physical address 0x0000:0x7E00.
; DL = boot drive number on entry (passed from bootloader).
;
; Build:
;   nasm -f bin boot.asm -o boot.bin
;   nasm -f bin main.asm -o main.bin
;   cat boot.bin main.bin > bytemap.img
;   truncate -s 1474560 bytemap.img
;
; Run:
;   qemu-system-i386 -fda bytemap.img -boot a
; ============================================================

[BITS 16]
[ORG 0x7E00]

; First bytes at 0x7E00 must be a jump over data/procedures
jmp  program_main           ; 3-byte near jump

; ============================================================
; Include order:  data first (variables near start of binary),
; then all procedure modules, then the entry point.
; NASM two-pass resolves all forward references correctly.
; ============================================================
%include "data.asm"
%include "font_data.inc"
%include "vga.asm"
%include "hex.asm"
%include "ui.asm"
%include "memory.asm"
%include "disk.asm"
%include "input.asm"

; ============================================================
; PROGRAM ENTRY POINT
; ============================================================
program_main:
    ; ---- set up segments / stack ---------------------------
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, STACK_TOP      ; defined in data.asm

    ; ---- save boot drive (DL set by bootloader) ------------
    mov  [disk_drv], dl

    ; ---- font is embedded in font_data.inc - no init needed --

    ; ---- switch to VGA Mode 13h (320×200, 256 colours) -----
    call init_vga

    ; ---- clear screen to solid black -----------------------
    mov  bl, COLOR_BG
    call clear_screen

    ; ---- draw static UI elements ---------------------------
    call draw_header
    call draw_col_header
    call draw_separator

    ; ---- load the first floppy sector into disk_buf --------
    call load_disk_sector

    ; ---- initial status message ----------------------------
    mov  si, str_welcome
    call set_status

    ; ---- welcome screen drawn before first keypress --------
    call full_redraw

; ============================================================
; MAIN LOOP
; Sequence: redraw -> wait for key -> handle key -> repeat
; ============================================================
.main_loop:
    call full_redraw        ; draw everything

    call read_key           ; AX = key (AH=scan, AL=ascii)
    call handle_key         ; AX = 0 (continue) or 1 (quit)

    cmp  ax, 1
    jne  .main_loop

; ============================================================
; QUIT
; Restore text mode, print goodbye, halt.
; ============================================================
.quit:
    mov  ax, 0x0003         ; INT 10h: set 80×25 text mode
    int  0x10

    ; Print goodbye message in text mode (INT 10h teletype)
    mov  si, str_goodbye
.bye_loop:
    lodsb
    or   al, al
    jz   .halt
    mov  ah, 0x0E
    xor  bh, bh
    int  0x10
    jmp  .bye_loop

.halt:
    cli
    hlt                     ; CPU stops; close QEMU window to exit
