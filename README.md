# golasm

Conway's Game of Life written in x86-64 assembly as a bare UEFI application, bootable from a USB stick.

- 1920x1080, one pixel per cell, toroidal grid
- random start seeded from `rdtsc` and `rdrand`
- any key reseeds, `ESC` exits

## Requirements

`nasm`, `binutils`, `gptfdisk` (`sgdisk`), `dosfstools`, `mtools`, `qemu` + `edk2-ovmf`

## Usage

```
make run-img             # build the disk image and boot it in QEMU
make usb DEV=/dev/sdX    # write it to a USB stick (erases the device)
```

Boot the stick in UEFI mode with Secure Boot disabled.
