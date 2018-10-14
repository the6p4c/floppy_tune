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

	; Read/calculate some necessary constants
	mov al, byte [ds:13]
	mov byte [fat_spc], al

	; TODO: Actually calculate this based on the BPB
	mov word [fat_ssa], (0x0001 + 0x02 * 0x0009 + 32 * 0x00E0 / 0x0200)

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

	; cylinder already set
	mov dh, al ; head number
	mov cl, ah ; sector number
	mov al, 1 ; read 1 sector
	mov dl, byte [drive_number] ; read from boot drive

	mov ah, 0x02
	int 0x13

	; Find the first file on the drive
.parse_entry:
	mov al, byte [es:bx]
	cmp al, 0
	je .parse_finished ; no more entries in this directory

	cmp al, 0xE5
	jne .parse_finished ; entry is a valid file 

	add bx, 32 ; move to next entry
	jmp .parse_entry

.parse_finished:
	; Being here means we either found a file, or there were no files
	; Let's assume we found a file for now

	; Get the file's first cluster number
	add bx, 26 ; no issue mangling the entry pointer
	mov ax, word [es:bx]

	; Convert CN to CHS
	call cn_to_lsn
	call lsn_to_chs

	; Read the first cluster into RAM
	; Read to 0x120:0 = 0x1200
	mov bx, 0x120
	mov es, bx
	xor bx, bx

	; cylinder already set
	mov dh, al ; head number
	mov cl, ah ; sector number
	mov al, byte [fat_spc] ; read the whole cluster
	mov dl, byte [drive_number] ; read from boot drive

	mov ah, 0x02
	int 0x13

	; Print the cluster contents
	mov al, 1 ; write mode - update cursor, no attributes
	mov bh, 0 ; page number 0
	mov bl, 0x0F ; attribute
	mov cx, (80 * 24) ; number of chars (fill screen)
	xor dx, dx ; print at 0,0
	mov bp, 0 ; string address (es already set)

	mov ah, 0x13
	int 0x10
.halt:
	hlt
	jmp .halt

; Converts a LSN (logical sector number) to a CHS (cylinder head sector)
; address.
;
; Inputs:
; 	ax: LSN
; Outputs:
; 	al: Head number
; 	ah: Sector number
;	ch: Cylinder number
; Clobbers:
;	cl
lsn_to_chs:
	mov cl, 18 ; number of sectors per track
	div cl ; al = head number + cyl number * heads/cyl, ah = sector - 1
	inc ah ; ah = sector

	mov ch, ah
	xor ah, ah
	mov cl, 2 ; number of heads per cylinder
	div cl ; al = cyl number, ah = head number

	mov cl, ch
	mov ch, al
	mov al, ah
	mov ah, cl

	ret

; Converts a CN (cluster number) to a LSN (logical sector number).
; Requires fat_ssa and fat_spc to be pre-calculated.
;
; LSN = (CN - 2) * fat_spc + fat_ssa
;
; Inputs:
; 	ax: CN
; Outputs:
; 	ax: LSN
cn_to_lsn:
	sub ax, 2
	mul word [fat_spc]
	add ax, word [fat_ssa]
	ret

; Ensure we're bootable - mkfs.vfat already includes a boot signature, but we'll
; copy our own to be safe.
TIMES 510 - ($ - $$) db 0x00
db 0x55
db 0xAA

; TODO: Fix the segmentation issues here - I have no clue where these variables
; are actually being stored
drive_number:
	resb 1
fat_ssa:
	resw 1
fat_spc:
	resb 1
