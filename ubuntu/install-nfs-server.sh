#!/bin/sh

set -e

debug_mode="false"
data_disk=""
disk_mountpt=""
supported_linux_distro="ubuntu"

while [ "x${1}x" != "xx" ] ; do
	case "$1" in
		-h | --help)
			echo "Usage: $0 [-D] -d <device> -m <path>"
			echo "Docker bootstrap helper script for ${supported_linux_distro}"
			echo ""
			echo "All arguments are optional:"
			echo "  -h | --help         shows this documentation"
			echo "  -D | --debug        run in -ex mode"
			echo "  -d | --disk         external data disk like /dev/sdb"
			echo "  -m | --mountpoint   mount disk to path; export path is <this>/nfsvol"
			echo ""
			echo "Example:"
			echo "  sudo ./install-nfs-server.sh -d /dev/sdc -m /storage/hdd"
			exit 0
			;;
		-D | --debug)
			debug_mode="true"
			;;
		-d | --disk)
			shift
			data_disk="$1"
			;;
		-m | --mountpoint)
			shift
			disk_mountpt="$1"
			;;
		*)
			echo "fatal! bad_param $1"
			echo "Usage: $0 [--debug] --disk <device>"
			exit 1
			;;
	esac
	shift
done

if [ "$debug_mode" = "true" ]; then
	set -ex
fi

if [ "x${data_disk}x" = "xx" ]; then
	echo "fatal! required_param -d/--disk"
fi
if [ "x${disk_mountpt}x" = "xx" ]; then
	echo "fatal! required_param -m/--mountpoint"
fi

if [ $(id -u) != 0 ]; then
	echo "fatal! require_root_priv"
	exit 1
fi

linux_distro=$(lsb_release -i | cut -d':' -f2 | sed 's/\t//g' | tr '[:upper:]' '[:lower:]')

if [ "$linux_distro" != "ubuntu" ]; then
	echo "fatal! unsupported_linux_distro ${linux_distro}"
	exit 1
fi

data_partition="${data_disk}1"
if [ -z "${data_disk##*[0-9]*}" ]; then
	# fix /dev/nvmes0 ...
	echo "info: nvme_data_disk ${data_disk}"
	data_partition="${data_disk}p1"
fi

data_diskname=$(echo "$data_disk" | cut -d'/' -f3)
while "true" ; do
	data_disk_attached=$(lsblk -lnf -o NAME | grep "$data_diskname" || true)
	if [ "x${data_disk_attached}x" != "xx" ]; then
		echo "info: data_disk_attached ${data_disk}"
		break
	else
		echo "info: await_data_disk_attach ${data_disk}"
		sleep 10s
	fi
done

echo "info: format_data_disk ${data_disk} fs=xfs"
(echo n; echo p; echo 1; echo; echo; echo w) | fdisk "$data_disk"
mkfs.xfs "$data_partition"
xfs_admin -L DATAVOL "$data_partition"

echo "info: mount_data_disk ${data_disk} mountpoint=${disk_mountpt} permanent=yes"
mkdir -p "$disk_mountpt"
mount "$data_partition" "$disk_mountpt"
echo "LABEL=DATAVOL  ${disk_mountpt}  xfs  rw,pquota  0 2" | sed 's/  /\t/g' >> /etc/fstab

apt-get update
apt-get install -f -y nfs-kernel-server
mkdir -p "${disk_mountpt}/nfsvol"
chmod 755 "${disk_mountpt}/nfsvol"
chown nobody:nogroup "${disk_mountpt}/nfsvol"
echo "${disk_mountpt}/nfsvol  *(rw,async,no_root_squash,no_subtree_check)" >> /etc/exports
service nfs-kernel-server restart
showmount -e 127.0.0.1

echo "info: all_done"
exit 0
