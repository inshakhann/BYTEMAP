[BITS 16]
[ORG 0x7C00]
boot_start:
    cli
    xor  ax, ax
    mov  ds, ax
    mov  es, ax
    mov  ss, ax
    mov  sp, 0x7C00
    sti
    mov  [bm_drive], dl
    xor  ax, ax
    mov  dl, [bm_drive]
    int  0x13
    mov  ah, 0x02
    mov  al, 20
    mov  ch, 0
    mov  cl, 2
    mov  dh, 0
    mov  dl, [bm_drive]
    mov  bx, 0x7E00
    int  0x13
    jnc  boot_ok
    mov  si, bm_err_msg
boot_print:
    lodsb
    or   al, al
    jz   boot_hang
    mov  ah, 0x0E
    xor  bh, bh
    int  0x10
    jmp  boot_print
boot_hang:
    cli
    hlt
boot_ok:
    mov  dl, [bm_drive]
    jmp  0x0000:0x7E00
bm_drive   db 0x00
bm_err_msg db 'ByteMap: load error. Reset.', 0x0D, 0x0A, 0
times 510-($-$$) db 0
dw 0xAA55
