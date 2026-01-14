<div align="center">
	<img width="256" src="media/logo.svg">
</div>

# better-dockerpi

> A Virtualised Raspberry Pi inside a Docker image

Gives you access to a virtualised ARM based Raspberry Pi machine running the Raspian operating system.

This is not just a Raspian Docker image, it's a full ARM based Raspberry Pi virtual machine environment.

## Usage

```
docker run -it ghcr.io/lspm-pkg/dockerpi
```

By default all filesystem changes will be lost on shutdown. You can persist filesystem changes between reboots by mounting the `/sdcard` volume on your host:

```
docker run -it -v $HOME/.dockerpi:/sdcard ghcr.io/lspm-pkg/dockerpi
```

If you have a specific image you want to mount you can mount it at `/sdcard/filesystem.img`:

```
docker run -it -v /2019-09-26-raspbian-buster-lite.img:/sdcard/filesystem.img ghcr.io/lspm-pkg/dockerpi
```

If you only want to mount your own image, you can build a much slimmer VM only Docker container that doesn't contain the Raspbian filesystem image by git cloning this repo and then editing the Dockerfile and removing the `COPY`.

If you want to use VNC, currnetly it is experimental and doesn't work as of the time of making this repoisitory.

You can make a `issue` or a `pull` request if you want, these greatly help us and you.

## Which machines are supported?

By default a Raspberry Pi 3B is virtualised,

There are no other machines. `raspi4b` is too experimental.


## Wait, what?

A full ARM environment is created by using Docker to bootstrap a QEMU virtual machine. The Docker QEMU process virtualises a machine with a 4 core BCM2835 CPU and 1GB RAM, just like the Raspberry Pi 3B. The official Raspbian image is mounted and booted along with a modified QEMU compatible kernel.

You'll see the entire boot process logged to your TTY until you're prompted to log in with the username/password pi/raspberry.

```
pi@raspberrypi:~$ uname -a
Linux raspberrypi 5.15.61-v8+ #1579 SMP PREEMPT Fri Aug 26 11:16:44 BST 2022 aarch64 GNU/Linux
pi@raspberrypi:~$ cat /etc/os-release | head -n 1
PRETTY_NAME="Debian GNU/Linux 11 (bullseye)"
pi@raspberrypi:~$ cat /proc/cpuinfo
processor       : 0
BogoMIPS        : 125.00
Features        : fp asimd evtstrm aes pmull sha1 sha2 crc32 cpuid
CPU implementer : 0x41
CPU architecture: 8
CPU variant     : 0x0
CPU part        : 0xd03
CPU revision    : 4

processor       : 1
BogoMIPS        : 125.00
Features        : fp asimd evtstrm aes pmull sha1 sha2 crc32 cpuid
CPU implementer : 0x41
CPU architecture: 8
CPU variant     : 0x0
CPU part        : 0xd03
CPU revision    : 4

processor       : 2
BogoMIPS        : 125.00
Features        : fp asimd evtstrm aes pmull sha1 sha2 crc32 cpuid
CPU implementer : 0x41
CPU architecture: 8
CPU variant     : 0x0
CPU part        : 0xd03
CPU revision    : 4

processor       : 3
BogoMIPS        : 125.00
Features        : fp asimd evtstrm aes pmull sha1 sha2 crc32 cpuid
CPU implementer : 0x41
CPU architecture: 8
CPU variant     : 0x0
CPU part        : 0xd03
CPU revision    : 4

Hardware        : BCM2835
Model           : Raspberry Pi 3 Model B+
pi@raspberrypi:~$ free -h
               total        used        free      shared  buff/cache   available
Mem:           921Mi        63Mi       456Mi       0.0Ki       401Mi       800Mi
Swap:           99Mi          0B        99Mi
pi@raspberrypi:~$ curl neofetch.sh | bash
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  378k  100  378k    0     0  33443      0  0:00:11  0:00:11 --:--:-- 37519
       _,met$$$$$gg.          pi@raspberrypi 
    ,g$$$$$$$$$$$$$$$P.       -------------- 
  ,g$$P"        """Y$$.".     OS: Debian GNU/Linux 11 (bullseye) aarch64 
 ,$$P'              `$$$.     Host: Raspberry Pi 3 Model B+ 
',$$P       ,ggs.     `$$b:   Kernel: 5.15.61-v8+ 
`d$$'     ,$P"'   .    $$$    Uptime: 11 mins 
 $$P      d$'     ,    $$P    Packages: 563 (dpkg) 
 $$:      $$.   -    ,d$$'    Shell: bash 5.1.4 
 $$;      Y$b._   _,d$P'      Terminal: not a tty 
 Y$$.    `.`"Y$$$$P"'         CPU: BCM2835 (4) @ 700MHz 
 `$$b      "-.__              Memory: 127MiB / 921MiB 
  `Y$$
   `Y$$.                                              
     `$$b.                                            
       `Y$$b.
          `"Y$b._
              `"""

pi@raspberrypi:~$ 
```

## Build

Build this image yourself by checking out this repo, `cd` ing into it and running:

```
docker build -t dpi .
```

## Credit

Thanks to luke childs's dockerpi repo for the inspiration. (https://github.com/lukechilds/dockerpi)
