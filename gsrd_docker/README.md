# GSRD docker build

The [instructions](https://rocketboards.org/foswiki/Documentation/DockerYoctoBuild) on the old rockerboards site are useful, but the tag doesn't work for the latest boards and later tags.  These instructions allow you to build GSRD for Agilex 5.

## Prerequisite

 - Install docker (already installed on ubuntu 24)
 ```
 sudo apt install docker-ce
 sudo usermod -aG docker $USER
 su $USER
 ```
 
## Build image
`source build_docker_image.sh`
NB you only need to build a docker image once, it is then stored on your computer until you remove it with `docker rmi`

## Run container

`source run_docker_container.sh`
 - Run a container using the image built above
  - pass the build directory so that the artifacts can be accessed outside the container.
  - Run as user, _not_ root because files may have incorrect ownership/permission
  
## Build
This takes ~3 hours on my 64GB 16core x86 computer
`build_in_docker.sh`

## Artifacts
If the build finishes correctly, you should see:
 - `${BOARD}-gsrd-images` contains the SD card imagedescribed in the [GSRD user guide](https://altera-fpga.github.io/rel-25.3.1/embedded-designs/agilex-5/e-series/013B/gsrd/ug-gsrd-agx5e-013b/#build-sd-card-boot-binaries), but not the .jic file to program QSPI flash.  Run this line to generate a `jic` file to program QSPI with FPGA configuration and FSBL:
 ```
 quartus_pfg \
-c agilex5_soc_devkit_ghrd/install/binaries/legacy_baseline.sof ghrd_a5ed013bm16ae4scs.jic \
-o device=QSPI512 \
-o flash_loader=A5ED013BM16AE4SCS \
-o hps_path=gsrd-socfpga/agilex5_dk_a5e013bm16aea-gsrd-images/u-boot-agilex5-socdk-gsrd-atf/u-boot-spl-dtb.hex \
-o mode=ASX4 \
-o hps=1
```

