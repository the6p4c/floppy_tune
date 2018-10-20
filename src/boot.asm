%define DSP_BASE 0x220
%define DSP_MXR_ADDR (DSP_BASE + 0x4)
%define DSP_MXR_DATA (DSP_BASE + 0x5)
%define DSP_RESET (DSP_BASE + 0x6)
%define DSP_READ (DSP_BASE + 0xA)
%define DSP_WRITE (DSP_BASE + 0xC)
%define DSP_READ_BUF_STATUS (DSP_BASE + 0xE)

%define DSP_MXR_REG_IRQ 0x80
%define DSP_MXR_REG_DMA 0x81
%define DSP_CMD_OUT_SAMPLE_RATE 0x41

%define DMAC1_CH1_ADDR 0x02
%define DMAC1_CH1_COUNT 0x03
%define DMAC1_CH1_PAGE 0x83
%define DMAC1_MASK 0x0A
%define DMAC1_MODE 0x0B
%define DMAC1_BPFF 0x0C

[bits 16]
[org 0x7C00]

; Jump over FAT header
jmp _start
nop

resb 10
bpb_sectors_per_cluster: resb 1
bpb_reserved_sector_count: resb 2
bpb_table_count: resb 1
resb 5
bpb_table_size: resb 2

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

	; Set up data segment
	mov ax, 0
	mov ds, ax

	; Calculate a required constant
	; TODO: Actually calculate this based on the BPB
	mov word [fat_ssa], (0x0001 + 0x02 * 0x0009 + 32 * 0x00E0 / 0x0200)

	; Read all FATs
	; Number of sectors is table_size * table_count
	mov ax, word [bpb_table_size]
	mul byte [bpb_table_count]
	mov dl, al

	; FATs start at a LSN of reserved_sector_count
	mov ax, word [bpb_reserved_sector_count]

	; Load FATs to 0x100:0 = 0x1000
	mov bx, 0x100
	mov es, bx
	xor bx, bx
	call read_sector_lsn

	; Find the first root directory sector
	; = table_count * fat_size + reserved_sector_count
	xor ax, ax
	mov al, byte [bpb_table_count]
	mul word [bpb_table_size]
	add ax, word [bpb_reserved_sector_count]

	; Read root directory sector
	; Read to 0x200:0 = 0x2000
	mov bx, 0x200
	mov es, bx
	xor bx, bx
	mov dl, 1 ; read 1 sector
	call read_sector_lsn

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
	; Read into RAM starting from address 0x10000 (0x1000:...)
	; Since each sector is 0x200 long, we can just add ccc * 0x20 to the seg
	xor ax, ax
	mov al, byte [current_cluster_count]
	shl ax, 5 ; equivalent to * 0x20
	mov bx, 0x1000
	add ax, bx
	mov es, ax
	xor bx, bx

	; Read the cluster
	mov ax, word [current_cluster]
	mov dl, 1 ; read 1 sector
	call read_sector_cn

	inc byte [current_cluster_count]

	call get_next_cluster

	; If the cluster number is >= 0xFF8, we've reached the end of the file
	cmp word [current_cluster], 0xFF8
	jl .read_cluster
.whole_file_read:
	; Reset the DSP
	mov dx, DSP_RESET
	mov al, 1
	out dx, al ; write the 1

	xor al, al
	out dx, al ; write the 0

	; Configure DMA
	; Disable dma channel
	mov al, 0x4 | 1 ; ch 1
	out DMAC1_MASK, al

	; Write the buffer address (page and address)
	mov al, 1
	out DMAC1_CH1_PAGE, al

	xor al, al
	out DMAC1_CH1_ADDR, al
	out DMAC1_CH1_ADDR, al

	; Clear byte pointer flip-flop
	out DMAC1_BPFF, al

	; Write DMA mode
	mov al, 0x58 | 1 ; auto-initialized playback on ch 1
	out DMAC1_MODE, al

	; Write transfer length
	mov al, (22050 * 2 - 1) & 0xFF
	out DMAC1_CH1_COUNT, al ; low byte
	mov al, ((22050 * 2 - 1) >> 8) & 0xFF
	out DMAC1_CH1_COUNT, al ; high byte

	; Enable IRQ2 on DMA block transfer finish
	mov dx, DSP_MXR_ADDR
	mov al, DSP_MXR_REG_IRQ
	out dx, al
	mov dx, DSP_MXR_DATA
	mov al, 2 ; IRQ2
	out dx, al

	; Enable IRQ2 on PIC
	in al, 0x21
	and al, (~(1 << 5) & 0xFF)
	out 0x21, al

	; Enable interrupts
	sti

	; Enable dma channel
	mov al, 1 ; ch 1
	out DMAC1_MASK, al

	; Set DMA interrupt address
	mov word [0x34], dma_finished ; offset
	mov word [0x36], 0 ; segment

	; Play the samples
	; Set sample rate
	mov dx, DSP_WRITE
	mov al, DSP_CMD_OUT_SAMPLE_RATE
	out dx, al
	mov al, (8000 >> 8) & 0xFF
	out dx, al
	mov al, 8000 & 0xFF
	out dx, al

	; Set program
	mov dx, DSP_WRITE
	mov al, 0xC6 ; 8-bit DMA A/D AI
	out dx, al
	xor al, al ; mono, unsigned
	out dx, al

	mov ax, cx
	dec ax
	out dx, al
	mov al, ah
	out dx, al

	; Set block size to half the buffer size
	mov al, 0x48
	out dx, al
	mov al, (22050 - 1) & 0xFF
	out dx, al
	mov al, ((22050 - 1) >> 8) & 0xFF
	out dx, al

	; Start playback
	mov al, 0x1C
	out dx, al
.halt:
	hlt
	jmp .halt

dma_finished:
	iret

; Uses the value of current_cluster to find the next cluster of the file.
get_next_cluster:
	push ax
	push bx
	push es

	; Entry offset is 1.5 * current_cluster
	; (i.e. current_cluster + current_cluster / 2)
	mov ax, word [current_cluster]
	mov bx, ax
	shr bx, 1
	add ax, bx ; ax is now entry offset

	; Read word containing next cluster number from FAT
	mov bx, ax
	mov ax, 0x100
	mov es, ax
	mov ax, word [es:bx]

	; Get 12-bit cluster number from word read from FAT
	test word [current_cluster], 1
	jnz .high_nibbles

	and ax, 0x0FFF
	jmp .done

.high_nibbles:
	shr ax, 4

.done:
	mov word [current_cluster], ax

	pop es
	pop bx
	pop ax
	ret

; Reads a sector from the boot drive based on a CN (cluster number).
;
; Inputs:
; 	ax: CN
;	dl: Number of sectors to read
;	es:bx: Address to read to
read_sector_cn:
	sub ax, 2
	mul byte [bpb_sectors_per_cluster]
	add ax, word [fat_ssa]
	; Fall through to lsn_to_chs - ax contains the LSN we converted the CN
	; to.

; Reads a sector from the boot drive based on a LSN (logical sector number).
;
; Inputs:
; 	ax: LSN
;	dl: Number of sectors to read
;	es:bx: Address to read to
read_sector_lsn:
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
	; Fall through to read_sector - al, ah and ch contain the head number,
	; sector number and cylinder number respectively.

; Reads a sector from the boot drive based on a CHS (cylinder head sector).
;
; Inputs:
; 	ch: Cylinder number
;	al: Head number
;	ah: Sector number
;	dl: Number of sectors to read
;	es:bx: Address to read to
read_sector:
	; cylinder (ch) already set
	mov dh, al ; head number
	mov al, dl ; sector count
	mov cl, ah ; sector number
	mov dl, byte [drive_number] ; read from boot drive

	mov ah, 0x02
	int 0x13

	ret

; Ensure we're bootable - mkfs.vfat already includes a boot signature, but we'll
; copy our own to be safe.
TIMES 510 - ($ - $$) db 0x00
db 0x55
db 0xAA

drive_number:
	resb 1
fat_ssa:
	resw 1

current_cluster:
	resw 1
current_cluster_count:
	resb 1
