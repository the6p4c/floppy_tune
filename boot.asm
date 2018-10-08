[bits 16]
[org 0x7C00]

; jump over FAT header
jmp _start
nop

; fill the boot binary with 0s until the bootstrap region of the FAT header
; this won't be copied into the floppy image, but it just here so the code below
; starts at the right org and address in the file
TIMES 62 - ($ - $$) db 0x00

_start:
	call dsp_demo

; stop the machine
halt:
	hlt
	jmp halt

%include "dsp.asm"

; ensure we're bootable - mkfs.vfat already puts this here, but we copy this
; part of boot.bin anyway so it's probably a good idea to do it ourselves
TIMES 510 - ($ - $$) db 0x00
db 0x55
db 0xAA
