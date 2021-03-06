#!/bin/sh

set -ex

gpt_mode=false
if [ "$1" = "--gpt" ]; then
	gpt_mode=true
	disk_dev=$2
	mount_dir=$3
else
	disk_dev=$1
	mount_dir=$2
fi

if [ ! -e "$disk_dev" ]; then
	echo "FATAL! disk_device_not_found ${disk_dev}"
	echo ""
	echo "Usage: $0 [--gpt] <devpath> <mount_dir>"
	exit 1
fi

if [ ! -d "$mount_dir" ]; then
	echo "FATAL! mount_dir_not_found ${mount_dir}"
	echo ""
	echo "Usage: $0 [--gpt] <devpath> <mount_dir>"
	exit 1
fi

if [ "$gpt_mode" = "true" ]; then
	(echo g; echo n; echo 1; echo; echo; echo w) | fdisk "$disk_dev"
else
	(echo n; echo p; echo 1; echo; echo; echo w) | fdisk "$disk_dev"
fi
sleep 5s

is_nvme=$(echo "$disk_dev" | awk '$1 ~ /[0-9]+$/ { print $1 }')
if [ "x${is_nvme}x" = "xx" ]; then
	partition_name="${disk_dev}1"
else
	partition_name="${disk_dev}p1"
fi

vol_label=$(echo "$mount_dir" | awk -F/ '{print toupper($NF) "_VOL"}')

mkfs.xfs "$partition_name"
xfs_admin -L "$vol_label" "$partition_name"
mkdir -p "$mount_dir"
mount "$partition_name" "$mount_dir"
fstab_line="LABEL=${vol_label}  ${mount_dir}  xfs  rw,pquota  0 2"
fstab_line=$(echo "$fstab_line" | sed 's/  /\t/g')
echo "$fstab_line" >> /etc/fstab
df -h "$mount_dir"
