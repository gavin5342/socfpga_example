
#retrieve Ubuntu image.

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive


#Installing packages

RUN apt-get  update -y && apt-get  upgrade -y

RUN apt-get install -y \
apt-utils openssh-server mc libgmp3-dev libmpc-dev gawk wget git diffstat unzip texinfo gcc \
build-essential chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils iputils-ping \
python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev xterm python3-subunit mesa-common-dev zstd \
liblz4-tool git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex libelf-dev bison xinetd \
tftpd tftp nfs-kernel-server libncurses5 libc6-i386 libstdc++6-i386-cross libgcc1-i386-cross lib32z1 \
device-tree-compiler curl mtd-utils u-boot-tools net-tools swig rust-all  tmux

RUN apt-get install -y locales
RUN echo "en_US.UTF-8 UTF-8" | tee -a /etc/locale.gen
ENV LANG="en_US.UTF-8"
RUN locale-gen
RUN dpkg-reconfigure --frontend noninteractive locales
RUN ln -sf /bin/bash /bin/sh

# Proxies



#User setting.
ARG username=build


#setting up main directory
USER root
RUN useradd -ms /bin/bash ${username}
USER ${username}

env HOME=/home/${username}

#creating downloads folder
run mkdir -p $HOME/tasks/yocto/downloads
#creating state folder
run mkdir -p $HOME/tasks/yocto/sstate

WORKDIR $HOME





CMD ["/bin/bash"]






