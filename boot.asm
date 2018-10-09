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
	jmp 0:.start
.start:
	; ensure, when we're reading the FAT, [xx] is 0x7Cxx
	push 0x7C0
	pop ds

	; locate the root directory sector
	; root directory sector = table_count * fat_size + reserved_sector_count
	xor ax, ax
	mov al, [16] ; table_count
	mov bx, [22] ; fat_size
	mul bx
	add ax, [14] ; reserved_sector_count

	; convert LBA to CHS
	mov cl, 18 ; sectors/track
	div cl ; al = temp, ah = sector - 1
	inc ah ; ah = sector

	; read sector
	; read to 0x100:0 = 0x100
	mov bx, 0x100
	mov es, bx
	xor bx, bx

	xor ch, ch ; cylinder 0
	mov dh, al ; head number
	mov cl, ah ; sector number
	mov al, 1 ; read 1 sector
	xor dl, dl ; drive 0

	mov ah, 0x02
	int 0x13

	mov bx, 0x100
	mov es, bx
	xor bx, bx

	push 0xB800
	pop gs
	xor di, di

.read_entry:
	mov al, [es:bx]
	cmp al, 0
	je .read_entry_done
	cmp al, 0xE5
	je .next_entry

	push bx
	mov cl, 8+3
	mov ah, 0xF0
.print_loop
	mov al, [es:bx]
	mov [gs:di], ax
	
	inc bx
	add di, 2
	dec cl
	jnz .print_loop
	pop bx
	mov al, ' '
	mov [gs:di], ax
	add di, 2
	
.next_entry:
	add bx, 32
	jmp .read_entry
.read_entry_done:

halt:
	hlt
	jmp halt

; ensure we're bootable - mkfs.vfat already includes a boot signature, but we'll
; copy our own to be safe
TIMES 510 - ($ - $$) db 0x00
db 0x55
db 0xAA
