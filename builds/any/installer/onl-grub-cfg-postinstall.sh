#!/bin/sh
#
# Postinstall hook (runs OUTSIDE the chroot, after onl-install finishes).
#
# Goal: guarantee /mnt/onl/boot/grub/grub.cfg references a stable
# kernel-active symlink instead of a version-specific kernel filename
# (e.g. kernel-4.19-lts-x86_64-all). Upgrade installs (onie-nos-install
# from a running ONL) have been observed to leave stale grub.cfg
# references to a kernel filename the new install no longer ships,
# producing at first boot:
#
#   error: file `/kernel-X.Y-lts-x86_64-all' not found.
#   error: you need to load the kernel first.
#
# Strategy: don't trust the install path. Mount ONL-BOOT, locate the
# (newest) kernel binary on it, write a self-contained grub.cfg from
# scratch referencing /kernel-active, and (re)create the symlink.
#
# Drops /mnt/onl/boot/.postinstall.ran with a timestamp so future
# debugging can confirm the hook ran (it's mounted ro normally; only
# visible if you `mount -o remount,rw /mnt/onl/boot`).
#
set -eu
chroot_dir="${1:-}"

log() { echo "postinstall(grub): $*"; }

# --- find ONL-BOOT device, trying several methods ---
dev=""
dev=$(blkid -L ONL-BOOT 2>/dev/null || true)
if [ -z "$dev" ]; then
    dev=$(blkid -t LABEL=ONL-BOOT -o device 2>/dev/null | head -1 || true)
fi
if [ -z "$dev" ]; then
    for p in /dev/sda3 /dev/sda4 /dev/sda5 /dev/nvme0n1p3 /dev/nvme0n1p4; do
        [ -b "$p" ] || continue
        if [ "$(blkid "$p" -s LABEL -o value 2>/dev/null || true)" = "ONL-BOOT" ]; then
            dev=$p; break
        fi
    done
fi
if [ -z "$dev" ]; then
    log "cannot find ONL-BOOT partition, skipping"
    exit 0
fi
log "ONL-BOOT is $dev"

# --- mount it ---
mnt=$(mktemp -d)
cleanup() { umount "$mnt" 2>/dev/null || true; rmdir "$mnt" 2>/dev/null || true; }
trap cleanup EXIT
mount "$dev" "$mnt"

# --- locate newest kernel binary ---
kern=$(ls -t "$mnt"/kernel-*-x86_64-all 2>/dev/null | head -1 | xargs -r basename || true)
if [ -z "$kern" ]; then
    log "no kernel-*-x86_64-all on ONL-BOOT, skipping"
    exit 0
fi
log "newest kernel: $kern"

# --- (re)create kernel-active symlink ---
rm -f "$mnt/kernel-active"
ln -s "$kern" "$mnt/kernel-active"
log "kernel-active -> $kern"

# --- find platform string (for the initrd filename and onl_platform=) ---
platform=""
if [ -n "$chroot_dir" ] && [ -f "$chroot_dir/etc/onl/platform" ]; then
    platform=$(cat "$chroot_dir/etc/onl/platform")
fi
if [ -z "$platform" ]; then
    # fall back: look for a *.cpio.gz on ONL-BOOT and strip the suffix
    platform=$(ls "$mnt"/*.cpio.gz 2>/dev/null | head -1 | xargs -r basename | sed 's/\.cpio\.gz$//' || true)
fi
if [ -z "$platform" ]; then
    log "cannot determine platform, skipping grub.cfg rewrite"
    exit 0
fi
log "platform: $platform"

# --- write grub.cfg from scratch ---
mkdir -p "$mnt/grub"
cat > "$mnt/grub/grub.cfg" <<EOF
serial --port=0x3f8 --speed=115200 --word=8 --parity=no --stop=1
terminal_input serial
terminal_output serial
set timeout=5

load_env
if [ "\${saved_entry}" ] ; then
   set default="\${saved_entry}"
fi

menuentry "Open Network Linux" {
  search --no-floppy --label --set=root ONL-BOOT
  set saved_entry="0"
  save_env saved_entry
  echo 'Loading Open Network Linux ...'
  insmod gzio
  insmod part_msdos
  linux /kernel-active nopat console=ttyS0,115200n8 onl_platform=$platform
  initrd /$platform.cpio.gz
}

menuentry "ONIE" {
  search --no-floppy --label --set=root ONIE-BOOT
  echo 'Loading ONIE ...'
  chainloader +1
}
EOF
log "grub.cfg rewritten to use /kernel-active"

# --- marker so we can confirm the hook ran on the installed system ---
date -u +"%Y-%m-%dT%H:%M:%SZ kernel=$kern platform=$platform" > "$mnt/.postinstall.ran"

exit 0
