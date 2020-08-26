#!/bin/sh

set -e

debug_mode="false"
nfsvol_path=""
supported_linux_distro="ubuntu"

while [ "x${1}x" != "xx" ] ; do
	case "$1" in
		-h | --help)
			echo "Usage: $0 [-D] -s <path>"
			echo "Docker bootstrap helper script for ${supported_linux_distro}"
			echo ""
			echo "All arguments are optional:"
			echo "  -h | --help    shows this documentation"
			echo "  -D | --debug   run in -ex mode"
			echo "  -s | --share   share this directory as nfs"
			echo ""
			echo "Example:"
			echo "  sudo ./install-nfs-server.sh -s /storage/nfsvol"
			exit 0
			;;
		-D | --debug)
			debug_mode="true"
			;;
		-s | --share)
			shift
			nfsvol_path="$1"
			;;
		*)
			echo "fatal! bad_param $1"
			echo "Usage: $0 [--debug] --share /data/nfsvol"
			exit 1
			;;
	esac
	shift
done

if [ "$debug_mode" = "true" ]; then
	set -ex
fi

if [ "x${nfsvol_path}x" = "xx" ]; then
	echo "fatal! required_param -s/--share"
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

if [ ! -d "$nfsvol_path" ]; then
	echo "fatal! dir_missing ${nfsvol_path}"
	exit 1
fi

apt-get update
apt-get install -f -y nfs-kernel-server
chmod 755 "$nfsvol_path"
chown nobody:nogroup "$nfsvol_path"
echo "${nfsvol_path}  *(rw,async,no_root_squash,no_subtree_check)" >> /etc/exports
service nfs-kernel-server restart
showmount -e 127.0.0.1

echo "info: all_done"
exit 0
