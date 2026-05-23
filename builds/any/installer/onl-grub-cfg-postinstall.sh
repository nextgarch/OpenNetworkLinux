#!/bin/sh
#
# Postinstall hook (runs OUTSIDE the chroot, after onl-install finishes).
#
# Ensure /mnt/onl/boot/grub/grub.cfg references the stable /kernel-active
# symlink and that the symlink resolves to the newest kernel binary on
# the ONL-BOOT partition. This bulletproofs first-boot after upgrades
# where the install path doesn't reliably regenerate grub.cfg, leaving
# it pointing at a kernel filename the new install no longer ships and
# producing:
#
#   error: file `/kernel-X.Y-lts-x86_64-all' not found.
#   error: you need to load the kernel first.
#
# Idempotent: if installGrubCfg already wrote /kernel-active and
# installLoader already created the symlink, this is a no-op.
#
set -e
chroot_dir="$1"

dev=$(blkid -L ONL-BOOT 2>/dev/null || true)
if [ -z "$dev" ]; then
    echo "postinstall(grub.cfg fix): no ONL-BOOT partition found, skipping"
    exit 0
fi

mnt=$(mktemp -d)
trap 'umount "$mnt" 2>/dev/null || true; rmdir "$mnt" 2>/dev/null || true' EXIT
mount "$dev" "$mnt"

# Pick newest kernel binary on the partition (newest mtime, x86-64 naming)
kern=$(ls -t "$mnt"/kernel-*-x86_64-all 2>/dev/null | head -1 | xargs -r basename || true)
if [ -z "$kern" ]; then
    echo "postinstall(grub.cfg fix): no kernel-*-x86_64-all on ONL-BOOT, skipping"
    exit 0
fi

# (Re)create kernel-active symlink
rm -f "$mnt/kernel-active"
ln -s "$kern" "$mnt/kernel-active"
echo "postinstall(grub.cfg fix): kernel-active -> $kern"

# Patch grub.cfg's linux line if present
if [ -f "$mnt/grub/grub.cfg" ]; then
    sed -i 's|linux /kernel-[^ ]*|linux /kernel-active|' "$mnt/grub/grub.cfg"
    echo "postinstall(grub.cfg fix): patched $mnt/grub/grub.cfg to use /kernel-active"
fi

exit 0
