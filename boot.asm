[bits 16]
[org 0x7C00]

; jump over FAT header
jmp $ + 30
nop

; fill the boot binary with 0s until the bootstrap region of the FAT header
; this won't be copied into the floppy image, but it just here so the code below
; starts at the right org and address in the file
TIMES 30 - ($ - $$) db 0x00

; print 'abc' in the top left of the screen
push 0xB800
pop es
xor si, si

mov ax, (0x0F << 8) | 'a'
mov [es:si], ax
add si, 2
mov ax, (0xF0 << 8) | 'b'
mov [es:si], ax
add si, 2
mov ax, (0x2D << 8) | 'c'
mov [es:si], ax

; stop the machine
halt:
	cli
	hlt
	jmp halt
