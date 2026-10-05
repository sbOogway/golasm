TARGET = gol
IMG = $(TARGET).img
OVMF_BIOS = /usr/share/edk2/ovmf/OVMF_CODE.fd
BUILD_DIR = build_uformat
EFI_BOOT_DIR = $(BUILD_DIR)/EFI/BOOT

.PHONY: all prepare run img run-img usb clean

all: $(TARGET).efi

$(TARGET).efi: $(TARGET).asm
	nasm -f elf64 $(TARGET).asm -o $(TARGET).o
	ld -m i386pep --subsystem 10 --dynamicbase -e main $(TARGET).o -o $(TARGET).efi
	rm $(TARGET).o

prepare: $(TARGET).efi
	@mkdir -p $(EFI_BOOT_DIR)
	cp $(TARGET).efi $(EFI_BOOT_DIR)/BOOTX64.EFI

run: prepare
	qemu-system-x86_64 \
		-bios $(OVMF_BIOS) \
		-drive format=raw,file=fat:rw:$(BUILD_DIR) \
		-net none \
		-m 512M

$(IMG): $(TARGET).efi
	rm -f $(IMG) $(IMG).part
	dd if=/dev/zero of=$(IMG) bs=1M count=64 status=none
	sgdisk -o -n 1:2048:131038 -t 1:ef00 -c 1:GOL $(IMG) >/dev/null 2>&1
	dd if=/dev/zero of=$(IMG).part bs=512 count=128991 status=none
	mkfs.fat -F 32 -n GOL $(IMG).part >/dev/null
	mmd -i $(IMG).part ::/EFI ::/EFI/BOOT
	mcopy -i $(IMG).part $(TARGET).efi ::/EFI/BOOT/BOOTX64.EFI
	dd if=$(IMG).part of=$(IMG) bs=512 seek=2048 conv=notrunc status=none
	rm $(IMG).part

img: $(IMG)

run-img: $(IMG)
	qemu-system-x86_64 \
		-bios $(OVMF_BIOS) \
		-drive format=raw,file=$(IMG) \
		-net none \
		-m 512M

usb: $(IMG)
	@test -n "$(DEV)" || (echo "uso: make usb DEV=/dev/sdX" && false)
	@test -b $(DEV) || (echo "$(DEV) non e' un block device" && false)
	@test "$$(lsblk -dno TRAN $(DEV))" = usb || (echo "$(DEV) non e' un dispositivo USB" && false)
	-for p in $$(lsblk -lno PATH,MOUNTPOINT $(DEV) | awk 'NF==2{print $$1}'); do udisksctl unmount -b $$p || sudo umount $$p; done
	sudo wipefs -a $(DEV)
	sudo dd if=$(IMG) of=$(DEV) bs=4M conv=fsync,nocreat status=progress
	sudo sgdisk -e $(DEV)
	sync

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(TARGET).efi $(TARGET).o $(IMG)
