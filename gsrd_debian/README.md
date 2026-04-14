## GSRD Debian

The yocto/poky based GSRD is great for deployment, but development on target is difficult.  While it's possible to enable the yocto package manager and install Linux headers in the GSRD, I will use debian with the kernel and bootloaders from GSRD to open access to the Debian ecosystem of useful packages.

I will use the [Agilex 5 013 dk](https://www.altera.com/products/devkit/po-3196/agilex-5-fpga-e-series-013b-development-kit), but I hope the information here can be useful for other kits

## Boot flow overview

Exisiting info:
 - The GSRD already covers the [structure of the SD card](https://altera-fpga.github.io/rel-25.3.1/embedded-designs/agilex-5/e-series/013B/gsrd/ug-gsrd-agx5e-013b/#build-sd-card-boot-binaries).  
 - There is conceptual information in the [HPS booting guide](https://docs.altera.com/r/docs/813762/25.3/hard-processor-system-booting-user-guide-agilextm-3-and-agilextm-5-socs/introduction).
 - The documentation on [TrustedFirmware-A](https://trustedfirmware-a.readthedocs.io/en/latest/design/firmware-design.html)
 
The ARM cores don't have a bootrom.  The OCRAM, located at 0, is configured by SDM during device configuration and then processor reset released.  For the GSRD, the software written to the OCRAM is u-boot.  u-boot-spl performs the role of bl1 and bl2 in the TrustedFirmware-A docs:

1. OCRAM from .jic/.rbf file = [u-boot](https://github.com/altera-fpga/u-boot-socfpga).  Made by [poky recipe](https://git.yoctoproject.org/poky/tree/meta/recipes-bsp/u-boot?h=walnascar-5.2.4).  NB this example is walnascar, the reference for Agilex 5 GSRD. The [meta-intel-fpga](https://git.yoctoproject.org/meta-intel-fpga/tree/conf/machine/agilex5_dk_a5e013bm16aea.conf?h=QPDS25.3.1_REL_AGILEX5_013B_GSRD_PR) layer has the defconfig definition that was used in building u-boot.


## Building artifacts
Note ATF runs first as the bin file for ATF is packaged with u-boot.

Most of these recipes use [oe_runmake](https://git.yoctoproject.org/poky/tree/meta/classes-global/base.bbclass?h=walnascar-5.2.4#n41) which calls `make`.

### ARM GNU toolchain

Yocto builds a toolchain.  For standalone builds, it's probably easier to download a prebuilt toolchain from arm eg:
```
mkdir arm-gnu-toolchain
pushd arm-gnu-toolchain
wget https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-x86_64-aarch64-none-elf.tar.xz
tar xf arm-gnu-toolchain-13.2.rel1-x86_64-aarch64-none-elf.tar.xz
rm -f arm-gnu-toolchain-13.2.rel1-x86_64-aarch64-none-elf.tar.xz
export PATH=${PWD}/arm-gnu-toolchain-13.2.Rel1-x86_64-aarch64-none-elf/bin/:$PATH
export CROSS_COMPILE=aarch64-none-elf-
```

### DTC
Device tree compiler is required.  It can be installed using apt on debian based systems:
```
sudo apt install device-tree-compiler
```


### Arm TrustedFirmware
The recipe for arm-trusted firmware is in the [meta-intel-fpga](https://git.yoctoproject.org/meta-intel-fpga/tree/recipes-bsp/arm-trusted-firmware?h=QPDS25.3.1_REL_AGILEX5_013B_GSRD_PR) repo.  To replicate this

```
cd arm-trusted-firmware
make PLAT="agilex5" CFLAGS="-Wno-error=array-bounds"
```
At the end of the build, you should see:
`Built */arm-trusted-firmware/build/agilex5/release/bl31.bin successfully`

The binary will be at: `arm-trusted-firmware/build/agilex5/release/bl31.bin`

### u-boot

### Linux kernel

GSRD modifies the usual Linux recipe in poky using the [meta-intel-fpga](https://git.yoctoproject.org/git/meta-intel-fpga) layer.  The `recipes-kernel/linux directory` contains the .bb files for each kernel release supported by Altera.

flex and bison are required so:  
`apt install flex bison`


### debian rootfs

To build a debian rootfs for aarch64 on amd64, qemu abd binfmt-support are required for emulating aarch64.  debbootstrap is the tool for installing a debian rootfs into a subdir of an existing system:

```
# get tools
sudo apt install binfmt-support qemu-user-static debootstrap
# build rootfs 1st stage
sudo debootstrap \
  --arch=arm64 \
  --foreign \
  bookworm \
  rootfs \
  https://deb.debian.org/debian
# copy qemu to new deb rootfs
sudo cp /usr/bin/qemu-aarch64-static ./rootfs/usr/bin/
# finish install
sudo chroot rootfs 
#these commands are inside the chroot
/debootstrap/debootstrap --second-stage
# update apt
cat <<EOT > /etc/apt/sources.list
deb http://deb.debian.org/debian bookworm main contrib non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free-firmware
EOT

apt update
# install useful packages
apt install vim openssh-server ntpdate sudo ifupdown net-tools udev iputils-ping wget dosfstools unzip binutils libatomic1 systemd-resolved ethtool avahi-daemon libnss-mdns systemd-timesyncd

# set generic hostname
echo debian-socfpga > /etc/hostname

# set networking 
car <<EOT > /etc/systemd/network/20-en.network
[Match]
Name=en*

[Network]
DHCP=yes
IPv6AcceptRA=no
EOT

# Enable network services
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable avahi-daemon
timedatectl set-ntp true

# set passwd for root
passwd

# create user
useradd -m -s /bin/bash socfpga
echo socfpga:socfpga | chpasswd
usermod -aG sudo socfpga

# exit
exit
```
An explanation of the debootstrap line:

 - `--arch=arm64 --foreign` use qemu to make an arm64=aarch64 rootfs on a host system that isn't aarch64
 - `bookworm` debian 12 codename
 - `rootfs` output directory
 - `https://deb.debian.org/debian` - optional mirror spec.
 
Networking uses `systemd-networkd` and relatives.  The config file catches all en interfaces - both the built in 1Gb/s and a USB.

The instructions create a default hostname and user.

### SD card write

The GSRD uses an SD card format with 2 partitions.

 - vfat/FAT32 partition for boot 
	 + Linux kernel Image
	 + device tree (dtb)
	 + fpga .rbf config file
	 + (full) u-boot ssbl
 - ext4 partition with rootfs
 
Having created the rootfs, now need to copy it to the SD card (I have a partitioned SD card that appears at /dev/sdb already):

```
sudo mkfs.ext4 /dev/sdb2
sudo mount /dev/sdb2 ./sd_mnt/
sudo rsync -aAX --numeric-ids rootfs/ ./sd_mnt/
sudo sync
```
 
** Use rsync, not cp. rsync retains permissions and owners as created.**
 
## Example boot
Connect UART (ie the `/dev/ttyUSB*` device associated with USB Blaster III on dev kit), then press S1=RST on the dev kit to see the cold boot flow:
### u-boot-sbl (FSBL)
```
U-Boot SPL 2025.10 (Dec 11 2025 - 10:49:42 +0000)
Reset state: Cold
MPU          1250000 kHz
L4 Main       400000 kHz
L4 sys free   100000 kHz
L4 MP         200000 kHz
L4 SP         100000 kHz
SDMMC         200000 kHz
init_mem_cal: Initial DDR calibration IO96B_0 succeed
DDR: Calibration success
is_mailbox_spec_compatible: IOSSM mailbox version: 1
LPDDR4: 1792 MiB
ecc_interrupt_status: ECC error number detected on IO96B_0: 0
SDRAM-ECC: Initialized success
DDR: size check success
DDR: firewall init success
DDR: init success
QSPI: Reference clock at 400000 kHz
Bloblist at 72000 not found (err=-2)
WDT:   Started watchdog@10d00200 with servicing every 1000ms (30s timeout)
Trying to boot from MMC1
## Checking hash(es) for config board-0 ... OK
## Checking hash(es) for Image atf ... crc32+ OK
## Checking hash(es) for Image uboot ... crc32+ OK
## Checking hash(es) for Image fdt-0 ... crc32+ OK
```
### ATF BL31
```
NOTICE:  SOCFPGA: Boot Core = 0
NOTICE:  SOCFPGA: CPU ID = 0
NOTICE:  SOCFPGA: Setting CLUSTERECTRL_EL1
NOTICE:  BL31: v2.13.1(release):376b6cd83
NOTICE:  BL31: Built : 10:40:22, Nov 25 2025
```
### u-boot (SSBL)
```
U-Boot 2025.10 (Dec 11 2025 - 10:49:42 +0000)socfpga_agilex5

CPU: Altera FPGA SoCFPGA Platform (ARMv8 64bit Cortex-A55/A76)
Model: SoCFPGA Agilex5 SoCDK
DRAM:  1.8 GiB
Core:  53 devices, 24 uclasses, devicetree: separate
WDT:   Started watchdog@10d00200 with servicing every 1000ms (30s timeout)
WDT:   Not starting watchdog@10d00300
WDT:   Not starting watchdog@10d00400
WDT:   Not starting watchdog@10d00500
WDT:   Not starting watchdog@10d00600
MMC:   mmc0@10808000: 0
Loading Environment from FAT... Unable to read "uboot.env" from mmc0:1...

Loading Environment from UBI... SF: Detected mt25qu512a with page size 256 Bytes, erase size 64 KiB, total 64 MiB
mtd: partition "u-boot" extends beyond the end of device "nor0" -- size truncated to 0x4000000
mtd: partition "root" is out of reach -- disabled
ubi0 error: ubi_early_get_peb: no free eraseblocks
ubi0 error: ubi_attach_mtd_dev: failed to attach mtd2, error -28
UBI error: cannot attach mtd2
UBI error: cannot initialize UBI, error -28
UBI init error 28
Please check, if the correct MTD partition is used (size big enough?)

** Cannot find mtd partition "root"
In:    serial0@10c02000
Out:   serial0@10c02000
Err:   serial0@10c02000
Net:
Warning: ethernet@10810000 (eth0) using random MAC address - ee:82:d3:b2:4d:05
eth0: ethernet@10810000
Warning: ethernet@10830000 (eth2) using random MAC address - 56:f3:d3:4c:16:78
, eth2: ethernet@10830000
Hit any key to stop autoboot: 0
SOCFPGA_AGILEX5 #
```

#### bootcmd
```
switch to partitions #0, OK
mmc0 is current device
Scanning mmc 0:1...
Found U-Boot script /boot.scr.uimg
2411 bytes read in 13 ms (180.7 KiB/s)
## Executing script at 81000000
crc32+ Trying to boot Linux from device mmc0
Found kernel in mmc0
12198587 bytes read in 529 ms (22 MiB/s)
## Loading kernel (any) from FIT Image at 82000000 ...
   Using 'board-4' configuration
   Verifying Hash Integrity ... OK
   Trying 'kernel' kernel subimage
     Description:  Linux Kernel
     Type:         Kernel Image
     Compression:  lzma compressed
     Data Start:   0x820000dc
     Data Size:    10682254 Bytes = 10.2 MiB
     Architecture: AArch64
     OS:           Linux
     Load Address: 0x86000000
     Entry Point:  0x86000000
     Hash algo:    crc32
     Hash value:   688beb53
   Verifying Hash Integrity ... crc32+ OK
## Loading fdt (any) from FIT Image at 82000000 ...
   Using 'board-4' configuration
   Verifying Hash Integrity ... OK
   Trying 'fdt-4' fdt subimage
     Description:  socfpga_socdk_combined
     Type:         Flat Device Tree
     Compression:  uncompressed
     Data Start:   0x82a3a484
     Data Size:    42821 Bytes = 41.8 KiB
     Architecture: AArch64
     Hash algo:    crc32
     Hash value:   b887cf1c
   Verifying Hash Integrity ... crc32+ OK
   Booting using the fdt blob at 0x82a3a484
Working FDT set to 82a3a484
## Loading fpga (any) from FIT Image at 82000000 ...
   Trying 'fpga-4' fpga subimage
     Description:  FPGA bitstream for GHRD
     Type:         FPGA Image
     Compression:  uncompressed
     Data Start:   0x82a44c7c
     Data Size:    1429504 Bytes = 1.4 MiB
     Load Address: 0x8a000000
     Hash algo:    crc32
     Hash value:   59b6fda5
   Verifying Hash Integrity ... crc32+ OK
   Loading fpga from 0x82a44c7c to 0x8a000000
'fpga' image without 'compatible' property
..FPGA reconfiguration OK!
Enable FPGA bridges
   Programming full bitstream... OK
   Uncompressing Kernel Image to 86000000
   Loading Device Tree to 00000000eeaf5000, end 00000000eeb02744 ... OK
Working FDT set to eeaf5000
SF: Detected mt25qu512a with page size 256 Bytes, erase size 64 KiB, total 64 MiB
Enabling QSPI at Linux DTB...
Working FDT set to eeaf5000
QSPI clock frequency updated
RSU: Firmware or flash content not supporting RSU
RSU: Firmware or flash content not supporting RSU
RSU: Firmware or flash content not supporting RSU
RSU: Firmware or flash content not supporting RSU

Starting kernel ...
```