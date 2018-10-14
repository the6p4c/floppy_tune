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
	; dl contains drive number - save it to be used later
	mov byte [drive_number], dl

	; Set up segmentation to read from the boot record
	mov ax, 0x7C0
	mov ds, ax

	; Find the first root directory sector
	; = table_count * fat_size + reserved_sector_count
	xor ax, ax
	mov al, byte [ds:16] ; table_count
	mul word [ds:22] ; fat_size
	add ax, word [ds:14] ; reserved_sector_count

	; Convert LSN to CHS
	call lsn_to_chs

	; Read root directory sector
	; Read to 0x100:0 = 0x1000
	mov bx, 0x100
	mov es, bx
	xor bx, bx

	xor ch, ch ; cylinder 0
	mov dh, al ; head number
	mov cl, ah ; sector number
	mov al, 1 ; read 1 sector
	mov dl, byte [drive_number] ; read from boot drive

	mov ah, 0x02
	int 0x13

.halt:
	hlt
	jmp .halt

; Converts a LSN to a CHS address.
;
; Inputs:
; 	ax: LSN
; Outputs:
; 	al: Head number
; 	ah: Sector number
lsn_to_chs:
	push cx
	mov cl, 18 ; number of sectors per track
	div cl ; al = head number, ah = sector - 1
	inc ah ; ah = sector
	pop cx
	ret

; Ensure we're bootable - mkfs.vfat already includes a boot signature, but we'll
; copy our own to be safe.
TIMES 510 - ($ - $$) db 0x00
db 0x55
db 0xAA

drive_number:
	resb 1
