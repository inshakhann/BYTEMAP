#!/usr/bin/env bash
# ============================================================
# build.sh  --  Assemble and package ByteMap
# ============================================================
# Requirements: nasm (apt install nasm)
# Output: bytemap.img  (1.44 MB floppy image, boot + program)
# ============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "========================================"
echo "  ByteMap Build System"
echo "========================================"

# ---- clean previous output ---------------------------------
rm -f boot.bin main.bin bytemap.img
echo "[1/4] Cleaned previous build artifacts."

# ---- assemble boot sector ----------------------------------
echo "[2/4] Assembling boot.asm ..."
nasm -f bin boot.asm -o boot.bin

BOOT_SIZE=$(wc -c < boot.bin)
if [ "$BOOT_SIZE" -ne 512 ]; then
    echo "ERROR: boot.bin is $BOOT_SIZE bytes (expected exactly 512)."
    exit 1
fi
echo "      boot.bin  OK  ($BOOT_SIZE bytes)"

# ---- assemble main program ---------------------------------
echo "[3/4] Assembling main.asm (includes all modules) ..."
nasm -f bin main.asm -o main.bin

MAIN_SIZE=$(wc -c < main.bin)
MAIN_SECTORS=$(( (MAIN_SIZE + 511) / 512 ))
echo "      main.bin  OK  ($MAIN_SIZE bytes = $MAIN_SECTORS sectors)"

if [ "$MAIN_SECTORS" -gt 20 ]; then
    echo "WARNING: main.bin is $MAIN_SECTORS sectors; bootloader only loads 20."
    echo "         Increase the sector count in boot.asm if needed."
fi

# ---- build floppy image ------------------------------------
echo "[4/4] Building bytemap.img ..."
cat boot.bin main.bin > bytemap.img
# Pad to exact 1.44 MB floppy size (2880 sectors x 512 bytes)
truncate -s 1474560 bytemap.img
IMG_SIZE=$(wc -c < bytemap.img)
echo "      bytemap.img  OK  ($IMG_SIZE bytes)"

echo "========================================"
echo "  Build successful!  bytemap.img ready."
echo ""
echo "  Run with:  ./run.sh"
echo "  Or:        qemu-system-i386 -fda bytemap.img -boot a -vga std"
echo "========================================"
