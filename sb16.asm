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

dma_configure:
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
	mov al, 0
	out dx, al

	; write transfer length - 1
	mov dx, DMAC1_CH1_COUNT
	mov al, (22050 - 1) & 0xFF
	out dx, al
	mov al, ((22050 - 1) >> 8) & 0xFF
	out dx, al

	; write buffer page
	mov dx, DMAC1_CH1_PAGE
	mov al, 1
	out dx, al

	; enable dma channel
	mov dx, DMAC1_MASK
	mov al, 1 ; ch 1
	out dx, al

	ret

dsp_play:
	mov dx, DSP_WRITE
	mov al, 0x41
	out dx, al
	mov al, 0x56
	out dx, al
	mov al, 0x22
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

	mov al, 0x1C
	out dx, al

	ret
