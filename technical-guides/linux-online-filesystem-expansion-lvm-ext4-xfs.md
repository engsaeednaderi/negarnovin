# Safely Expand a Linux Filesystem Online with LVM, ext4, and XFS

This runbook covers a common production task: a virtual or physical disk has been enlarged, but the Linux filesystem still reports its previous capacity. The key is to expand each layer in order and verify the target at every step.

The examples use generic device names. **Do not copy device paths blindly.** Confirm the disk, partition, physical volume, logical volume, and mount point on the target host before running any write operation.

## 1. Map the storage stack first

Collect the current layout:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
findmnt -no SOURCE,FSTYPE,TARGET /
sudo pvs
sudo vgs
sudo lvs -a -o +devices
df -hT
```

Identify whether the filesystem is mounted directly on a partition, on an LVM logical volume, or on a whole virtual disk. These are different layouts and require different steps.

Before changing storage, confirm that a recent backup exists and that it can be restored. A snapshot is useful for short-term rollback, but it is not a substitute for an independent backup.

## 2. Confirm that Linux sees the larger disk

After increasing the virtual disk in the hypervisor or storage platform, check the guest's view:

```bash
lsblk
sudo fdisk -l
```

If the kernel still reports the old capacity, rescan the relevant SCSI device where applicable, or use the platform-specific rescan procedure. Do not proceed until the operating system reports the expected disk size.

For a SCSI-backed disk, the following can request a rescan:

```bash
echo 1 | sudo tee /sys/class/block/sdX/device/rescan
```

Replace `sdX` with the confirmed device. NVMe and other virtual controllers may require a different rescan path or a guest reboot, depending on the hypervisor and driver.

## 3. Expand the partition only when the PV is on a partition

If LVM uses a partition such as `/dev/sda3`, inspect the partition table and confirm that the free space is immediately after the target partition. For a supported GPT layout, `growpart` can extend the partition:

```bash
sudo growpart /dev/sda 3
sudo partprobe /dev/sda
lsblk
```

Install the `cloud-guest-utils` package on Debian/Ubuntu if `growpart` is missing. On other distributions, package names can differ.

If the PV is the whole disk (for example, `/dev/sdb`), do not create or resize a partition unnecessarily. If the disk uses an unusual partition layout, extended partition, or adjacent partitions that consume the free space, stop and plan the partition change rather than assuming the command is safe.

## 4. Resize the LVM physical volume

Once the underlying block device or partition has the intended size, tell LVM to recognise the additional capacity:

```bash
sudo pvresize /dev/sda3
sudo pvs
sudo vgs
```

Use the actual PV path discovered in step 1. The volume group should now show additional free extents. If it does not, stop and re-check the partition size, PV path, and kernel's device view.

## 5. Extend the logical volume

Identify the correct LV and the amount of free space available:

```bash
sudo lvs -o lv_path,lv_size,vg_name
sudo vgs
```

To allocate all currently free extents in the volume group to one LV:

```bash
sudo lvextend -l +100%FREE /dev/VG_NAME/LV_NAME
```

This consumes all free extents in that VG. If the VG hosts multiple filesystems or future growth is expected elsewhere, specify a deliberate size instead, for example `-L +20G`, after confirming the available capacity.

## 6. Grow the filesystem using the matching tool

First confirm the filesystem type with `findmnt` or `lsblk -f`. The commands are not interchangeable.

### ext4

For an ext4 filesystem on an LV:

```bash
sudo resize2fs /dev/VG_NAME/LV_NAME
```

ext4 supports online growth while mounted. Do not use this command for XFS.

### XFS

For an XFS filesystem, operate on its mount point:

```bash
sudo xfs_growfs /
```

Replace `/` with the actual mount point. XFS supports online growth; it does not support shrinking. Do not run `resize2fs` against XFS.

If the filesystem is not on LVM, the same filesystem-specific growth command may apply after the underlying partition has been expanded, but verify the exact source device and mount point first.

## 7. Verify every layer

Check that the block device, PV, LV, and filesystem reflect the intended capacity:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
sudo pvs
sudo vgs
sudo lvs -a -o +devices
df -hT
findmnt
```

A successful `lvextend` does not prove that the filesystem has grown. The final confirmation is the mounted filesystem's reported size.

## Common failure points

- **The disk is larger in the hypervisor but not in Linux:** rescan the correct device or follow the platform's guest rescan procedure.
- **The partition did not grow:** check whether free space is contiguous and whether another partition occupies it.
- **`pvresize` reports no change:** verify that the PV is on the device or partition that was actually enlarged.
- **The VG has no free extents:** inspect all PVs and confirm that the intended PV belongs to the expected VG.
- **The LV grew but `df` did not:** run the filesystem-specific growth command and verify the correct mount point.
- **The filesystem type is unclear:** stop before issuing a resize command. Determine it with `findmnt -no FSTYPE,SOURCE,TARGET`.

## Operational cautions

Do not attempt to shrink XFS. Do not reduce a partition or LV as part of an expansion procedure. Do not assume a hypervisor snapshot protects against every storage failure. Keep a verified backup, record the original layout, and retain a second administrative session or console access when changing a production system.

For virtual machines, remember that increasing a virtual disk in the control panel, expanding the guest partition, resizing the LVM PV, extending the LV, and growing the filesystem are separate operations. Each layer must be confirmed before moving to the next.
