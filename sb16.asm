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

dsp_reset:
	mov dx, DSP_RESET
	mov al, 1
	out dx, al ; write the 1

	mov al, 0xFF
.delay:
	dec al
	jnz .delay

	xor al, al
	out dx, al ; write the 0

	ret

; Configures a DMA transfer to send an audio buffer to the SB16.
; Audio samples must be on a page aligned address (i.e. 0xn0000).
;
; Inputs:
; 	al - Page of audio samples
;	cx - Number of samples
dma_configure:
	push ax
	push cx

	push ax ; save the page - popped when writing buffer addr

	; Disable dma channel
	mov al, 0x4 | 1 ; ch 1
	out DMAC1_MASK, al

	; Write the buffer address (page and address)
	pop ax
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
	mov ax, cx
	dec ax
	out DMAC1_CH1_COUNT, al ; low byte
	mov al, ah
	out DMAC1_CH1_COUNT, al ; high byte

	; Enable dma channel
	mov al, 1 ; ch 1
	out DMAC1_MASK, al

	pop cx
	pop ax
	ret

; Tells the SB16 to start playback.
;
; Inputs:
;	ax - Sample rate
; 	cx - Number of samples
dsp_play:
	push ax
	push cx
	push dx

	; Set sample rate
	mov dx, DSP_WRITE
	mov al, DSP_CMD_OUT_SAMPLE_RATE
	out dx, al
	xchg al, ah
	out dx, al
	mov al, ah
	out dx, al

	; Set program
	mov dx, DSP_WRITE
	mov al, 0xC6 ; 8-bit DMA A/D AI
	out dx, al
	xor al, al ; mono, unsigned
	out dx, al
	mov ax, cx
	out dx, al
	mov al, ah
	out dx, al

	; Start playback
	mov al, 0x1C
	out dx, al

	pop dx
	pop cx
	pop ax
	ret
