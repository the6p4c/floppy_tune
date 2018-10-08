%define DSP_BASE 0x220
%define DSP_RESET (DSP_BASE + 0x6)
%define DSP_READ (DSP_BASE + 0xA)

[bits 16]
[org 0x7C00]

; jump over FAT header
jmp _start
nop

; fill the boot binary with 0s until the bootstrap region of the FAT header
; this won't be copied into the floppy image, but it just here so the code below
; starts at the right org and address in the file
TIMES 30 - ($ - $$) db 0x00

_start:
	; reset the DSP
	; send a 1 then a 0 on the reset port
	mov dx, DSP_RESET
	mov ax, 1
	out dx, ax
	xor ax, ax
	out dx, ax

	; build a random square wave to test the DSP
	push 0x7D0
	pop es
	mov si, 0

build_sound:
	mov ax, si
	shr ax, 5
	and ax, 1
	shl ax, 7
	mov [es:si], al
	inc si

	cmp si, 22050
	jne build_sound

; stop the machine
halt:
	cli
	hlt
	jmp halt

; ensure we're bootable - mkfs.vfat already puts this here, but we copy this
; part of boot.bin anyway so it's probably a good idea to do it ourselves
TIMES 510 - ($ - $$) db 0x00
db 0x55
db 0xAA
