FLOPPY_MNT_DIR:=$(shell mktemp -d)

all: floppy.img Makefile

clean:
	rm -f floppy.img boot.bin

run_qemu:
	qemu-system-i386 -drive file=floppy.img,if=floppy,index=0,format=raw -soundhw sb16

run_qemu_debug:
	qemu-system-i386 -drive file=floppy.img,if=floppy,index=0,format=raw -soundhw sb16 -s -S

run_bochs:
	bochs

run_gdb:
	gdb

floppy.img: boot.bin music/*
	# build floppy image
	dd if=/dev/zero of=floppy.img bs=1024 count=1440
	mkfs.vfat -F 12 floppy.img
	dd conv=notrunc if=boot.bin of=floppy.img bs=1 count=3 # jmp
	dd conv=notrunc if=boot.bin skip=62 of=floppy.img seek=62 bs=1 count=448 # bootstrap

	# mount and copy over the audio files
	sudo mount -o loop,umask=000 floppy.img $(FLOPPY_MNT_DIR)
	cp -r music/. $(FLOPPY_MNT_DIR)
	sudo umount $(FLOPPY_MNT_DIR)
	rmdir $(FLOPPY_MNT_DIR)

boot.bin: *.asm
	nasm boot.asm -o boot.bin

.PHONY: all clean
