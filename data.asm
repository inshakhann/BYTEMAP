; ============================================================
; data.asm  --  Global Variables, Constants, Strings
; ============================================================
; Included at the top of main.asm (right after the far-jump).
; All addresses are relative to [ORG 0x7E00].
; ============================================================

; ---- Application state -------------------------------------
current_mode    db 0        ; 0 = RAM mode,  1 = DISK mode
cursor_row      db 0        ; 0-15
cursor_col      db 0        ; 0-7
edit_active     db 0        ; 1 = editing a byte
edit_nibble     db 0        ; 0 = expecting high nibble, 1 = low
edit_val        db 0        ; nibble-assembled byte during edit

; ---- RAM mode ----------------------------------------------
ram_seg         dw 0x0000   ; segment being viewed
ram_off         dw 0x7C00   ; offset being viewed (defaults to boot sector)

; ---- Disk mode ---------------------------------------------
disk_drv        db 0x00     ; 0x00 = floppy A:,  0x80 = HDD
disk_cyl        db 0        ; cylinder  (0-79 for 1.44 MB floppy)
disk_hd         db 0        ; head      (0-1)
disk_sec        db 1        ; sector    (1-18, 1-based for INT 13h)
disk_dirty      db 0        ; 1 = buffer modified but not written
disk_disp_off   dw 0        ; which 128-byte window of the sector: 0/128/256/384

; ---- Buffers -----------------------------------------------
disk_buf        times 512 db 0   ; one full 512-byte disk sector
; font_buf lives in font_data.inc (embedded font, no BIOS needed)

; ---- Status bar message ------------------------------------
status_msg      times 41  db 0   ; up to 40 printable chars + NUL

; ---- Single-call temporaries (non-reentrant, no threading) -
_dc_char        db 0        ; draw_char:    character to draw
_dc_fg          db 0        ; draw_char:    foreground colour
_dc_bg          db 0        ; draw_char:    background colour
_hex_hi         db 0        ; draw_hex_byte: high nibble ASCII
_hex_lo         db 0        ; draw_hex_byte: low  nibble ASCII
_curr_byte      db 0        ; draw_hex_grid: byte at current cell
_quit_confirm   db 0        ; 1 = user pressed ESC once already

; ---- Colour constants (Mode 13h default VGA palette) -------
COLOR_BG        equ 0       ; black          – general background
COLOR_HEADER_BG equ 1       ; dark blue      – title / button bar bg
COLOR_HEADER_FG equ 15      ; white          – title text
COLOR_ACTIVE_BG equ 10      ; bright green   – active-mode button bg
COLOR_ACTIVE_FG equ 0       ; black          – active-mode button text
COLOR_ADDR      equ 7       ; light grey     – address labels
COLOR_COL_HDR   equ 6       ; brown          – column-header labels
COLOR_NULL      equ 8       ; dark grey      – null bytes (0x00)
COLOR_ASCII_CLR equ 10      ; bright green   – printable ASCII bytes
COLOR_OPCODE    equ 12      ; bright red     – common opcode bytes
COLOR_DATA      equ 11      ; bright cyan    – everything else
COLOR_CURSOR_BG equ 14      ; yellow         – normal cursor background
COLOR_CURSOR_FG equ 0       ; black          – normal cursor text
COLOR_EDIT_BG   equ 15      ; white          – edit-mode cursor bg
COLOR_EDIT_FG   equ 4       ; dark red       – edit-mode cursor text
COLOR_STATUS_BG equ 1       ; dark blue      – status bar bg
COLOR_STATUS_FG equ 15      ; white          – status bar text
COLOR_DIRTY_IND equ 12      ; bright red     – [DIRTY] indicator
COLOR_CLEAN_IND equ 10      ; bright green   – [CLEAN] indicator
COLOR_INFO_FG   equ 7       ; light grey     – info-row labels
COLOR_INFO_VAL  equ 11      ; bright cyan    – info-row values
COLOR_HELP_FG   equ 8       ; dark grey      – help text
COLOR_HELP_KEY  equ 11      ; bright cyan    – key names in help
COLOR_SEP       equ 8       ; dark grey      – separator line

; ---- Layout constants --------------------------------------
STACK_TOP       equ 0x9FFE  ; SP starts here (grows downward)
SCREEN_COLS     equ 40      ; 320px / 8px = 40 character columns
SCREEN_ROWS     equ 25      ; 200px / 8px = 25 character rows
BYTES_PER_ROW   equ 8       ; bytes per hex-grid row
NUM_HEX_ROWS    equ 16      ; hex-grid row count

; character-row positions on screen
ROW_TITLE       equ 0
ROW_BUTTONS     equ 1
ROW_MODE_INFO   equ 2
ROW_COL_HDR     equ 3
ROW_HEX_START   equ 4       ; rows 4-19 = hex grid (16 rows)
ROW_SEPARATOR   equ 20
ROW_BYTE_INFO   equ 21
ROW_HELP1       equ 22
ROW_HELP2       equ 23
ROW_STATUS      equ 24

; ---- String constants (all <= 40 visible chars + NUL) ------

; title row  (40 chars)
str_title       db '  ByteMap v1.0  Visual Memory&Disk Insp', 0

; button row (40 chars) -- uses '1'/'2' instead of F1/F2
str_buttons     db '[1]RAM  [2]DISK [+/-]Sec [W]Wrt [ESC]Q', 0

; active-button labels (highlighted in-place)
str_btn_ram     db '[1]RAM', 0
str_btn_disk    db '[2]DISK', 0

; column header (40 chars)
str_col_hdr     db 'ADDR  00 01 02 03 04 05 06 07 ASCII    ', 0

; separator (40 chars)
str_sep         db '----------------------------------------', 0

; mode-info prefixes
str_ram_prefix  db 'RAM  SEG:', 0
str_ram_mid     db '  OFF:', 0
str_disk_prefix db 'DISK DRV:', 0
str_disk_cyl    db ' CYL:', 0
str_disk_hd     db ' HD:', 0
str_disk_sec    db ' SEC:', 0
str_disk_view   db ' VIEW:', 0
str_dirty_ind   db '[DIRTY]', 0
str_clean_ind   db '[CLEAN]', 0

; byte-info row prefixes
str_bi_addr     db 'Addr:', 0
str_bi_val      db '  Val:0x', 0
str_bi_dec      db '  Dec:', 0
str_bi_chr      db '  Chr:', 0

; help rows -- updated to show '1'/'2' instead of F1/F2
str_help1_ram   db '[Arrows]Move [PgU/D]Scroll [Enter]Edit  ', 0
str_help1_disk  db '[Arrows]Move [PgU/D]View  [+/-]Sector   ', 0
str_help2       db '[1]RAM [2]DISK [W]WriteSector [ESC]Quit  ', 0

; status messages (padded to 40 chars so they overwrite leftovers)
str_welcome     db 'ByteMap ready. [Enter]=Edit  [ESC]=Quit ', 0
str_disk_ok     db 'Sector loaded OK.                       ', 0
str_disk_err    db 'DISK ERROR! Read failed.                ', 0
str_write_ok    db 'Sector written to disk successfully!    ', 0
str_write_err   db 'DISK ERROR! Write failed.               ', 0
str_ram_write   db 'RAM byte written.                       ', 0
str_disk_modif  db 'Buffer byte modified. [W] to write.     ', 0
str_edit_hi     db 'EDIT: Type high nibble (0-9 / A-F)      ', 0
str_edit_lo     db 'EDIT: Type low nibble  (0-9 / A-F)      ', 0
str_edit_done   db 'Edit applied.                           ', 0
str_edit_cancel db 'Edit cancelled.                         ', 0
str_quit_conf   db 'Press ESC again to quit, other key = stay', 0
str_goodbye     db 'ByteMap closed. Close QEMU to exit.', 0x0D, 0x0A, 0
str_no_scroll   db 'Cannot scroll below address 0000.       ', 0
str_sec_wrap    db 'Sector clamped to valid range (1-18).   ', 0
