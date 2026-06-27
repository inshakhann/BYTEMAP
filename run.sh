#!/usr/bin/env bash
# ============================================================
# run.sh -- Launch ByteMap inside QEMU
# ============================================================
# Requirements: qemu-system-i386 (apt install qemu-system-x86)
#               bytemap.img must already be built (./build.sh)
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f bytemap.img ]; then
    echo "bytemap.img not found.  Run ./build.sh first."
    exit 1
fi

echo "  Controls inside ByteMap:"
echo "    1           Switch to RAM Inspector mode"
echo "    2           Switch to Disk Inspector mode"
echo "    Arrow keys  Move cursor"
echo "    Page Up/Dn  Scroll view (RAM) / page within sector (Disk)"
echo "    Enter       Edit byte under cursor (type 2 hex digits)"
echo "    + / -       Next / previous disk sector  [Disk mode]"
echo "    W           Write modified sector to disk [Disk mode]"
echo "    ESC (x2)    Quit"
echo ""
echo "  QEMU tips:"
echo "    Ctrl+Alt+F  Toggle fullscreen"
echo "    Ctrl+Alt+G  Release mouse/keyboard grab"
echo ""
echo "  NOTE: Click inside the QEMU window once to grab keyboard input."
echo ""

# -vga std        : plain linear framebuffer - required for Mode 13h.
#                   DO NOT use -vga cirrus: it bank-switches the
#                   framebuffer and clips the bottom of the screen.
#
# -display sdl,gl=off : SDL backend passes all keystrokes (including
#                   digits, arrows, etc.) straight to the guest.
#                   gtk backend can intercept some keys at the OS level.
#
# Keys '1' and '2' are used for mode switching instead of F1/F2 because
# QEMU (and some desktop environments) intercept function keys before
# they reach the guest via INT 16h.

qemu-system-i386 \
    -drive file=bytemap.img,format=raw,if=floppy,index=0 \
    -boot a \
    -no-reboot \
    -name "ByteMap v1.0" \
    -vga std \
    -display sdl,gl=off
