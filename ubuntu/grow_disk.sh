#!/bin/sh
set -e

if [ "$1" = "info" ]; then
	partition_path="$2"
	runmode="info"
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
	runmode="help"
elif [ "x${1}x" != "xx" ]; then
	partition_path="$1"
	mount_point="$2"
	runmode="grow"
else
	runmode="help"
	param_error=true
fi

param_error=false
if [ "$runmode" != "help" ]; then
	if [ "x${partition_path}x" = "xx" ]; then
		echo "FATAL! partition not specified"
		param_error=true
	fi
	if [ ! -e "$partition_path" ]; then
		echo "FATAL! partition not found: ${partition_path}"
		param_error=true
	fi
	if [ "$runmode" = "grow" ] && [ "x${mount_point}x" = "xx" ]; then
		echo "FATAL! mountpoint not specified"
		param_error=true
	fi
fi

if [ "$runmode" = "help" ] || [ "$param_error" = "true" ]; then
        echo "Usage: $0 info <partition_path>"
        echo "       $0 <partition_path> <mount_dir>"

	if [ "$param_error" = "true" ]; then
	        exit 1
	else
	        exit 0
	fi
fi

partition_name=$(lsblk -lno NAME,TYPE,PKNAME "$partition_path" | cut -d' ' -f1)
partition_type=$(lsblk -lno NAME,TYPE,PKNAME "$partition_path" | cut -d' ' -f2)
parent_devname=$(lsblk -lno NAME,TYPE,PKNAME "$partition_path" | cut -d' ' -f3)
parent_devpath="/dev/${parent_devname}"
partition_number=$(echo "$partition_name" | sed "s/${parent_devname}*//")

if [ "$partition_type" != "part" ]; then
	echo "FATAL! unsupported partition type: ${partition_type}"
	exit 1
fi

df_info=$(df -hT "$partition_path" | tail -n 1)

fs_type=$(echo "$df_info" | awk '{print $2}')
if [ "$fs_type" != "xfs" ] && [ "$fs_type" != "ext4" ]; then
	echo "FATAL! unsupported_filesystem ${fs_type}"
	exit 1
fi

partition_total=$(echo "$df_info" | awk '{print $3}')
partition_used=$(echo "$df_info" | awk '{print $4}')
partition_avail=$(echo "$df_info" | awk '{print $5}')
partition_used_pct=$(echo "$df_info" | awk '{print $6}')

disk_size=$(lsblk -nr "$parent_devpath" | head -n 1 | cut -d' ' -f4)
partition_size=$(lsblk -nr "$partition_path" | cut -d' ' -f4)

if [ "$runmode" = "grow" ]; then
	if [ ! -d "$mount_point" ]; then
		echo "FATAL! directory not found: ${mount_point}"
		exit 1
	fi

	current_mountpoint=$(df "$partition_path" | sed '1d;s/.* \([^ ]*\)$/\1/')
	if [ "$current_mountpoint" != "/dev" ]; then
		echo "FATAL! need to unmount first: ${partition_path}"
		exit 1
	fi

	echo "info: grow_partition ${parent_devpath} number=${partition_number}"
	growpart "$parent_devpath" "$partition_number"

	echo "info: remount ${partition_path} to ${mount_point}"
	mount "$partition_path" "$mount_point"

	if [ "$fs_type" = "xfs" ]; then
		echo "info: grow_fs format=xfs ${partition_path}"
		xfs_growfs "$mount_point"
	elif [ "$fs_type" = "ext4" ]; then
		echo "info: grow_fs format=ext4 ${partition_path}"
		resize2fs "$partition_path"
	fi

	echo "done!"
	exit 0
fi

# defaults to info
echo "disk       ${parent_devpath}"
echo "diskname   ${parent_devname}"
echo "disksize   ${disk_size}"
echo "partition  ${partition_path}"
echo "name       ${partition_name}"
echo "type       ${partition_type}"
echo "number     ${partition_number}"
echo "filesystem ${fs_type}"
echo "available  ${partition_avail}"
echo "blocksize  ${partition_size}"
echo "used       ${partition_used}/${partition_total} (${partition_used_pct})"
echo ""
