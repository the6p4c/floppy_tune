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

	mov word [current_cluster], ax
	mov byte [current_cluster_count], 0

.read_cluster:
	; Read into RAM starting from address 0x10000
	; Since each sector is 0x200 long, we can just add ccc * 0x20 to the seg
	xor ax, ax
	mov al, byte [current_cluster_count]
	shl ax, 5
	mov bx, 0x1000
	add ax, bx
	mov es, ax
	xor bx, bx

	; Convert CN to CHS
	mov ax, word [current_cluster]
	call cn_to_lsn
	call lsn_to_chs

	; cylinder already set
	mov dh, al ; head number
	mov cl, ah ; sector number
	mov al, byte [fat_spc] ; read the whole cluster
	mov dl, byte [drive_number] ; read from boot drive

	mov ah, 0x02
	int 0x13

	inc byte [current_cluster_count]

	; Get the FAT
	; Determine fat offset = 1.5 * current_cluster
	mov ax, word [current_cluster]
	mov bx, ax
	shr bx, 1
	add ax, bx

	; Determine fat sector and entry offset
	mov bx, ax
	shr ax, 9
	add ax, word [ds:14]
	and bx, 0b111111111
	push bx

	; Read the FAT
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

	pop bx

	; Get the next cluster number
	mov ax, word [es:bx]
	test word [current_cluster], 1
	jnz .sh4
	and ax, 0x0FFF
	jmp .done
.sh4:
	shr ax, 4
.done:

	cmp ax, 0xFF8
	jge .whole_file_read

	mov word [current_cluster], ax
	jmp .read_cluster

.whole_file_read:
	call dsp_reset
	call dma_configure
	call dsp_play

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
	mul byte [fat_spc]
	add ax, word [fat_ssa]
	ret

%include "sb16.asm"

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

current_cluster:
	resw 1
current_cluster_count:
	resb 1
