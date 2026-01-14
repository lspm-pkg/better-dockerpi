FROM debian:trixie
LABEL maintainer="Wheatly Snowflake <idkalone2019@gmail.com>"
ARG RPI_KERNEL_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/archive/afe411f2c9b04730bcc6b2168cdc9adca224227c.zip"

RUN apt-get update
RUN apt-get install -y \
    unzip \
    qemu-system-arm \
    qemu-system-aarch64 \
    qemu-utils \
    coreutils \
    util-linux \
    parted \
    dosfstools \
    kmod \
    gzip \
    bzip2 \
    xz-utils \
    wget \
    curl \
    fdisk

RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    qemu-system-arm \
    qemu-system-aarch64 \
    qemu-utils \
    binfmt-support \
    fatcat \
    mtools \
    dosfstools \
    e2fsprogs \
    kpartx \
    coreutils \
    util-linux \
    parted \
    kmod \
    gzip \
    bzip2 \
    xz-utils \
    p7zip-full \
    wget \
    curl \
    git \
    fdisk \
    e2fsprogs \
    && rm -rf /var/lib/apt/lists/*

VOLUME /sdcard
EXPOSE 5022
EXPOSE 5900

RUN wget https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-09-07/2022-09-06-raspios-bullseye-arm64-lite.img.xz -O /filesystem.xz
RUN unxz /filesystem.xz

# As for the /filesystem.img, this was only for development purposes.
#COPY ./FILESYSTEM.img /filesystem.img

ADD ./entrypoint.sh /entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]
