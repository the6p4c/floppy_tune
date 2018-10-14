[bits 16]
[org 0x7C00]

; Jump over FAT header
jmp _start
nop

; Fill the boot binary with 0s until the bootstrap region of the FAT header.
; This won't be copied into the floppy image, but it just here so the code below
; starts at the right org and address in the file.
TIMES 62 - ($ - $$) db 0x00

_start:
	; Set cs to 0
	jmp 0:.start
.start:
	; Our code goes here

.halt:
	hlt
	jmp .halt

; Ensure we're bootable - mkfs.vfat already includes a boot signature, but we'll
; copy our own to be safe.
TIMES 510 - ($ - $$) db 0x00
db 0x55
db 0xAA
