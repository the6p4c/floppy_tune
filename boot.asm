%define DSP_BASE 0x220
%define DSP_MXR_ADDR (DSP_BASE + 0x4)
%define DSP_MXR_DATA (DSP_BASE + 0x5)
%define DSP_RESET (DSP_BASE + 0x6)
%define DSP_READ (DSP_BASE + 0xA)
%define DSP_WRITE (DSP_BASE + 0xC)
%define DSP_READ_BUF_STATUS (DSP_BASE + 0xE)

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

; jump over FAT header
jmp _start
nop

; fill the boot binary with 0s until the bootstrap region of the FAT header
; this won't be copied into the floppy image, but it just here so the code below
; starts at the right org and address in the file
TIMES 30 - ($ - $$) db 0x00

_start:
	; DSP reset
	mov dx, DSP_RESET
	mov al, 1
	out dx, al ; write the 1

	mov al, 0xFF
.delay:
	dec al
	jnz .delay

	xor al, al
	out dx, al ; write the 0

	; 1. build waveform
	push 0x7D0
	pop es
.loop:
	mov ax, si
	shr ax, 5
	and ax, 1
	shl ax, 7
	mov [es:si], ax
	inc si

	cmp si, 22050
	jne .loop

	; 4. turn on speaker
	mov dx, DSP_WRITE
	mov al, 0xD1
	out dx, al

	; 5. program DMA controller
	; disable dma channel
	mov dx, DMAC1_MASK
	mov al, 0x4 | 1 ; ch 1
	out dx, al

	; clear byte pointer flip-flop
	mov dx, DMAC1_BPFF
	out dx, al

	; write DMA mode
	mov dx, DMAC1_MODE
	mov al, 0x58 | 1 ; auto-initialized playback on ch 1
	out dx, al

	; write buffer offset
	mov dx, DMAC1_CH1_ADDR
	xor al, al
	out dx, al
	mov al, 0x7D
	out dx, al

	; write transfer length - 1
	mov dx, DMAC1_CH1_COUNT
	mov al, (22050 - 1) & 0xFF
	out dx, al
	mov al, ((22050 - 1) >> 8) & 0xFF
	out dx, al

	; write buffer page
	mov dx, DMAC1_CH1_PAGE
	xor al, al
	out dx, al

	; enable dma channel
	mov dx, DMAC1_MASK
	mov al, 1 ; ch 1
	out dx, al

	; 6. set DSP sample rate
	mov dx, DSP_WRITE
	mov al, 0x41
	out dx, al
	mov al, 0x56
	out dx, al
	mov al, 0x22
	out dx, al

	; 7. set dsp block size
	mov al, 0x48
	out dx, al
	mov al, (22050/2 - 1) & 0xFF
	out dx, al
	mov al, ((22050/2 - 1) >> 8) & 0xFF
	out dx, al

	; ?? set dma 1 as chan
	mov dx, DSP_MXR_ADDR
	mov al, 0x81
	out dx, al
	mov dx, DSP_MXR_DATA
	mov al, 2
	out dx, al

	mov dx, DSP_WRITE
	mov al, 0xC6
	out dx, al
	xor al, al
	out dx, al
	mov al, (22050 - 1) & 0xFF
	out dx, al
	mov al, ((22050 - 1) >> 8) & 0xFF
	out dx, al

	; 8. start xfr
	mov al, 0x1C
	out dx, al

; stop the machine
halt:
	hlt
	jmp halt

; ensure we're bootable - mkfs.vfat already puts this here, but we copy this
; part of boot.bin anyway so it's probably a good idea to do it ourselves
TIMES 510 - ($ - $$) db 0x00
db 0x55
db 0xAA
