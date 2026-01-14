#!/bin/sh

GIB_IN_BYTES="1073741824"

vnc=0
if [ "${1:-}" = "--vnc" ]; then
  vnc=1
  shift
fi

target="${1:-pi3}"
storage_gib="${2:-0}"
image_path="/sdcard/filesystem.img"
zip_path="/filesystem.zip"

if [ ! -e "$image_path" ]; then
  echo "No filesystem detected at ${image_path}!"
  if [ -e /filesystem.img ]; then
    echo "Copying /filesystem.img -> ${image_path}"
    if mv /filesystem.img "$image_path"; then
      echo "Copy succeeded."
    else
      echo "Copy failed: /filesystem.img -> ${image_path}"
      ls -l /filesystem.img || true
      exit 1
    fi
  elif [ -e "$zip_path" ]; then
    echo "No /filesystem.img found; extracting $zip_path as fallback..."
    mkdir -p /sdcard/unziptmp
    if unzip -o "$zip_path" -d /sdcard/unziptmp/ >/dev/null 2>&1; then
      first_img=$(find /sdcard/unziptmp -type f -iname "*.img" | head -n1)
      if [ -z "$first_img" ]; then
        echo "ZIP has no .img inside"
        rm -rf /sdcard/unziptmp
        exit 1
      fi
      if mv "$first_img" "$image_path"; then
        echo "Extracted and moved $first_img -> $image_path"
        rm -rf /sdcard/unziptmp
      else
        echo "Failed to move extracted image into place"
        rm -rf /sdcard/unziptmp
        exit 1
      fi
    else
      echo "unzip failed for $zip_path"
      rm -rf /sdcard/unziptmp
      exit 1
    fi
  else
    echo "Neither /filesystem.img nor $zip_path exist; cannot create ${image_path}"
    exit 1
  fi
fi
if [ "$storage_gib" -gt 0 ]; then
  echo "Resizing to ${storage_gib}GiB"
  qemu-img resize "$image_path" "${storage_gib}G"
fi

qemu-img info "$image_path"

image_size_in_bytes=$(qemu-img info --output json "$image_path" | awk -F: '/virtual-size/ {gsub(/[^0-9]/,"",$2); print $2}')

round_needed=$(awk -v v="$image_size_in_bytes" -v G="$GIB_IN_BYTES" 'BEGIN{ if (v=="" || v==0) { print 0; exit } print (v % (G*2)) ? 1 : 0 }')

if [ "$round_needed" -ne 0 ]; then
  new_size_in_gib=$(awk -v v="$image_size_in_bytes" -v G="$GIB_IN_BYTES" 'BEGIN{ printf "%d", int((v/(G*2))+1)*2 }')
  echo "Rounding image size up to ${new_size_in_gib}GiB so it's a multiple of 2GiB..."
  qemu-img resize "$image_path" "${new_size_in_gib}G"
  image_size_in_bytes=$(qemu-img info --output json "$image_path" | awk -F: '/virtual-size/ {gsub(/[^0-9]/,"",$2); print $2}')
fi

total_sectors=$(awk -v v="$image_size_in_bytes" 'BEGIN{ printf "%d", v/512 }')

if [ "$target" = "pi2" ]; then
  emulator=qemu-system-arm
  machine=raspi2b
  cpu=cortex-a7
  memory=1024M
  kernel_pattern="kernel7.img"
  dtb_pattern="bcm2709-rpi-2-b.dtb"
  append="dwc_otg.fiq_fsm_enable=0 init=/bin/bash"
  root=/dev/mmcblk0p2
  nic="-netdev user,id=net0,hostfwd=tcp::5022-:22 -device usb-net,netdev=net0"
elif [ "$target" = "pi3" ]; then
  emulator=qemu-system-aarch64
  machine=raspi3b
  cpu=cortex-a53
  memory=1024M
  kernel_pattern="kernel8.img"
  dtb_pattern="bcm2710-rpi-3-b-plus.dtb"
  append="dwc_otg.fiq_fsm_enable=0 init=/bin/bash"
  root=/dev/sda2
  nic="-netdev user,id=net0,hostfwd=tcp::5022-:22 -device usb-net,netdev=net0"
elif [ "$target" = "pi3vz" ]; then
  emulator=qemu-system-aarch64
  machine=raspi3b
  cpu=cortex-a53
  memory=1024M
  kernel_pattern="VMLINUZ"
  dtb_pattern="bcm2710-rpi-3-b-plus.dtb"
  append="dwc_otg.fiq_fsm_enable=0 init=/bin/bash"
  root=/dev/sda2
  nic="-netdev user,id=net0,hostfwd=tcp::5022-:22 -device usb-net,netdev=net0"
else
  echo "Target ${target} not supported"
  echo "Supported targets: pi2 pi3"
  exit 2
fi

if [ "$kernel_pattern" ] && [ "$dtb_pattern" ]; then
  fat_path="/fat.img"

  candidates=$(fdisk -l "$image_path" 2>/dev/null | grep -iE 'fat|win95|efi' | awk '{print $1}' | uniq)
  candidate_count=$(printf "%s\n" "$candidates" | grep -cve '^$' || true)

  if [ "$candidate_count" -eq 1 ]; then
    part_device=$(printf "%s\n" "$candidates" | head -n1)
  else
    echo "Showing FAT/EFI-like entries in $image_path:"
    fdisk -l "$image_path" 2>/dev/null | grep -iE 'fat|win95|efi' || true
    echo
    echo "Full partition list:"
    fdisk -l "$image_path"
    while : ; do
      read -p "Enter the FAT partition (device path or number, e.g. ${image_path}1 or 1; empty to abort): " user_part
      if [ -z "$user_part" ]; then
        echo "Aborted by user."
        break
      fi
      if echo "$user_part" | grep -qE '^[0-9]+$'; then
        part_device="${image_path}${user_part}"
      else
        part_device="$user_part"
      fi
      partition_line=$(fdisk -l "$image_path" 2>/dev/null | awk -v dev="$part_device" '$1==dev{print; exit}')
      if [ -z "$partition_line" ]; then
        partition_line=$(fdisk -l "$image_path" 2>/dev/null | grep -F "$part_device" | head -n1)
      fi
      if [ -z "$partition_line" ]; then
        echo "Partition '$part_device' not found. Listing partitions:"
        fdisk -l "$image_path"
        continue
      fi
      read start_sector sector_count <<EOF
$(echo "$partition_line" | awk '{
  n=0
  for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/) nums[++n]=$i
  if(n>=3) print nums[n-2], nums[n]
}')
EOF
      if ! printf "%s" "$start_sector" | grep -qE '^[0-9]+$' || ! printf "%s" "$sector_count" | grep -qE '^[0-9]+$'; then
        echo "Failed to parse start/sector from: $partition_line"
        fdisk -l "$image_path"
        continue
      fi
      if dd --version >/dev/null 2>&1; then
        STATUS_OPT="status=progress"
      else
        STATUS_OPT=""
      fi
      echo "Extracting $part_device to $fat_path"
      if [ -n "$STATUS_OPT" ]; then
        if dd if="$image_path" of="$fat_path" bs=512 skip="$start_sector" count="$sector_count" "$STATUS_OPT"; then
          break
        fi
      else
        if dd if="$image_path" of="$fat_path" bs=512 skip="$start_sector" count="$sector_count"; then
          break
        fi
      fi
      echo "dd failed. Listing partitions:"
      fdisk -l "$image_path"
      echo "Try another partition or press Enter to abort."
    done
  fi

  if [ -z "$part_device" ]; then
    echo "No partition chosen, skipping FAT extraction."
  else
    if [ -z "$start_sector" ] || [ -z "$sector_count" ]; then
      partition_line=$(fdisk -l "$image_path" 2>/dev/null | awk -v dev="$part_device" '$1==dev{print; exit}')
      read start_sector sector_count <<EOF
$(echo "$partition_line" | awk '{
  n=0
  for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/) nums[++n]=$i
  if(n>=3) print nums[n-2], nums[n]
}')
EOF
    fi
    if printf "%s" "$start_sector" | grep -qE '^[0-9]+$' && printf "%s" "$sector_count" | grep -qE '^[0-9]+$'; then
      if dd --version >/dev/null 2>&1; then
        STATUS_OPT="status=progress"
      else
        STATUS_OPT=""
      fi
      echo "Extracting $part_device to $fat_path"
      if [ -n "$STATUS_OPT" ]; then
        dd if="$image_path" of="$fat_path" bs=512 skip="$start_sector" count="$sector_count" "$STATUS_OPT" || true
      else
        dd if="$image_path" of="$fat_path" bs=512 skip="$start_sector" count="$sector_count" || true
      fi
    fi
  fi

  if [ -f "$fat_path" ] && [ -s "$fat_path" ]; then
    echo "Extracting boot filesystem"
    fat_folder="/fat"
    mkdir -p "$fat_folder"
    fatcat -x "$fat_folder" "$fat_path"
    kernel=$(find "$fat_folder" -name "$kernel_pattern" | head -n1)
    dtb=$(find "$fat_folder" -name "$dtb_pattern" | head -n1)
    if [ -z "$kernel" ] || [ -z "$dtb" ]; then
      echo "Couldn't find kernel or dtb in the FAT filesystem"
      echo "kernel=${kernel:-<missing>}, dtb=${dtb:-<missing>}"
      exit 3
    fi
  else
    echo "No FAT image extracted."
    exit 4
  fi
fi

echo "Booting QEMU machine ${machine} with kernel=${kernel} dtb=${dtb}"
vnc_opts=""
if [ "$vnc" -eq 1 ]; then
  vnc_opts="-vnc :0"
else
  vnc_opts="--display none"
fi

exec $emulator \
  --machine "$machine" \
  -cpu "$cpu" \
  -m "$memory" \
  -drive if=none,file=${image_path},id=usbdrive,format=raw \
  -device usb-storage,bus=usb-bus.0,drive=usbdrive \
  $nic \
  --dtb "$dtb" \
  --kernel "$kernel" \
  --append "rw earlyprintk loglevel=8 console=ttyAMA0,115200 dwc_otg.lpm_enable=0 root=${root} rootwait panic=1 ${append}" \
  --no-reboot \
  $vnc_opts \
  --serial mon:stdio
