FLOPPY_MNT_DIR:=$(shell mktemp -d)

all: floppy.img Makefile

clean:
	rm -f floppy.img boot.bin

run:
	qemu-system-i386 -drive format=raw,file=floppy.img -soundhw sb16

floppy.img: boot.bin music/
	# build floppy image
	dd if=/dev/zero of=floppy.img bs=1024 count=1440
	mkfs.vfat -F 12 floppy.img
	dd conv=notrunc if=boot.bin of=floppy.img bs=1 count=3 # jmp
	dd conv=notrunc if=boot.bin skip=30 of=floppy.img seek=30 bs=1 count=482 # bootstrap

	# mount and copy over the audio files
	sudo mount -o loop,umask=000 floppy.img $(FLOPPY_MNT_DIR)
	cp -r music/. $(FLOPPY_MNT_DIR)
	sudo umount $(FLOPPY_MNT_DIR)
	rmdir $(FLOPPY_MNT_DIR)

boot.bin: boot.asm
	nasm boot.asm -o boot.bin

.PHONY: all clean
