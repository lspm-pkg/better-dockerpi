FROM debian:trixie
LABEL maintainer="Wheatly Snowflake <idkalone2019@gmail.com>"
ARG RPI_KERNEL_URL="https://github.com/dhruvvyas90/qemu-rpi-kernel/archive/afe411f2c9b04730bcc6b2168cdc9adca224227c.zip"

RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-arm \
    qemu-system-aarch64 \
    qemu-utils \
    wget \
    curl \
    unzip \
    fdisk \
    gzip \
    bzip2 \
    xz-utils \
    coreutils \
    util-linux \
    fatcat \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

VOLUME /sdcard
EXPOSE 5022
EXPOSE 5900

RUN wget https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-09-07/2022-09-06-raspios-bullseye-arm64-lite.img.xz -O /filesystem.img.xz && unxz /filesystem.img.xz

# As for the /filesystem.img, this was only for development purposes.
#COPY ./FILESYSTEM.img /filesystem.img

ADD ./entrypoint.sh /entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]
