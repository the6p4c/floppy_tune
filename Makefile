FLOPPY_MNT_DIR:=$(shell mktemp -d)

all: floppy.img Makefile

clean:
	rm -f floppy.img src/boot.bin

run_qemu: floppy.img
	qemu-system-i386 -drive file=floppy.img,if=floppy,index=0,format=raw -soundhw sb16

run_qemu_debug: floppy.img
	qemu-system-i386 -drive file=floppy.img,if=floppy,index=0,format=raw -soundhw sb16 -s -S

run_bochs: floppy.img
	bochs

run_gdb:
	gdb

floppy.img: src/boot.bin music/*
	# build floppy image
	dd if=/dev/zero of=floppy.img bs=1024 count=1440
	mkfs.vfat -F 12 floppy.img
	dd conv=notrunc if=src/boot.bin of=floppy.img bs=1 count=3 # jmp
	dd conv=notrunc if=src/boot.bin skip=62 of=floppy.img seek=62 bs=1 count=448 # bootstrap

	# mount and copy over the audio files
	sudo mount -o loop,umask=000 floppy.img $(FLOPPY_MNT_DIR)
	cp -r music/. $(FLOPPY_MNT_DIR)
	sudo umount $(FLOPPY_MNT_DIR)
	rmdir $(FLOPPY_MNT_DIR)

src/boot.bin: src/*.asm
	nasm -i src/ src/boot.asm -o src/boot.bin

.PHONY: all clean
