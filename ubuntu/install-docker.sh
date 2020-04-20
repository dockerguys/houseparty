#!/bin/sh

set -e

debug_mode="false"
docker_admin="administrator"
docker_ver="latest"
containerd_ver="latest"
data_disk=""
docker_baseurl="https://download.docker.com/linux"
supported_linux_distro="ubuntu"

while [ "x${1}x" != "xx" ] ; do
	case "$1" in
		-h | --help)
			echo "Usage: $0 [-D] [-u <user>] [-d <device>] [-m <url>] [-c <ver>] [-k <ver>]"
			echo "Docker bootstrap helper script for ${supported_linux_distro}"
			echo ""
			echo "All arguments are optional:"
			echo "  -h | --help         shows this documentation"
			echo "  -D | --debug        run in -ex mode"
			echo "  -u | --admin        sudoless docker user: ${docker_admin}"
			echo "  -d | --disk         use an external data disk like /dev/sdb"
			echo "  -m | --mirror       repo url: ${docker_baseurl}"
			echo "  -c | --containerd-version  containerd version: ${containerd_ver}"
			echo "  -k | --docker-version      docker version: ${docker_ver}"
			echo ""
			echo "Example:"
			echo "  sudo ./install-docker.sh -d /dev/sdb"
			exit 0
			;;
		-D | --debug)
			debug_mode="true"
			;;
		-u | --admin)
			shift
			docker_admin="$1"
			;;
		-d | --disk)
			shift
			data_disk="$1"
			;;
		-m | --mirror)
			shift
			docker_baseurl="$1"
			;;
		-c | --containerd-version)
			shift
			containerd_ver="$1"
			;;
		-k | --docker-version)
			shift
			docker_ver="$1"
			;;
		*)
			echo "fatal! bad_param $1"
			echo "Usage: $0 [--debug] [--admin <user>] [--disk <device>] [--mirror <url>] [--containerd-version <ver>] [--docker-version <ver>]"
			exit 1
			;;
	esac
	shift
done

if [ "$debug_mode" = "true" ]; then
	set -ex
fi

if [ $(id -u) != 0 ]; then
	echo "fatal! require_root_priv"
	exit 1
fi

linux_distro=$(lsb_release -i | cut -d':' -f2 | sed 's/\t//g' | tr '[:upper:]' '[:lower:]')
linux_rel=$(lsb_release -c | cut -d':' -f2 | sed 's/\t//g' | tr '[:upper:]' '[:lower:]')

if [ "$linux_distro" != "ubuntu" ]; then
	echo "fatal! unsupported_linux_distro ${linux_distro}"
	exit 1
fi

echo "info: docker_branch ${linux_distro}"
pkg_extension="deb"
docker_repo_baseurl="${docker_baseurl}/${linux_distro}/dists/${linux_rel}/pool/stable/amd64"

if [ "$linux_rel" = "bionic" ]; then
	if [ "$docker_ver" = "latest" ]; then
		docker_ver="18.09.9~3-0"
	fi
	if [ "$containerd_ver" = "latest" ]; then
		containderd_ver="1.2.13-1"
	fi
elif [ "$linux_rel" = "xenial" ]; then
	if [ "$docker_ver" = "latest" ]; then
		docker_ver="18.09.9~3-0"
	fi
	if [ "$containerd_ver" = "latest" ]; then
		containderd_ver="1.2.13-1"
	fi
else
	echo "fatal! unsupported_lsb_release ${linux_rel}"
	exit 1
fi

docker_cliurl="${docker_repo_baseurl}/docker-ce-cli_${docker_ver}~${linux_distro}-${linux_rel}_amd64.${pkg_extension}"
docker_url="${docker_repo_baseurl}/docker-ce_${docker_ver}~${linux_distro}-${linux_rel}_amd64.${pkg_extension}"
containerd_url="${docker_repo_baseurl}/containerd.io_${containderd_ver}_amd64.${pkg_extension}"

echo "info: download_docker_pkg"
curl -L "$containerd_url" -o "/tmp/containerd.deb"
curl -L "$docker_cliurl" -o "/tmp/docker-cli.deb"
curl -L "$docker_url" -o "/tmp/docker.deb"

echo "info: install_docker_pkg"
dpkg -i /tmp/containerd.deb
dpkg -i /tmp/docker-cli.deb
dpkg -i /tmp/docker.deb
rm /tmp/*.deb

if [ "x${data_disk}x" != "xx" ]; then
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
	xfs_admin -L SSDVOL "$data_partition"

	echo "info: mount_data_disk ${data_disk} mountpoint=/storage/ssd permanent=yes"
	mkdir -p /storage/ssd
	mount "$data_partition" /storage/ssd
	echo 'LABEL=SSDVOL  /storage/ssd  xfs  rw,pquota  0 2' | sed 's/  /\t/g' >> /etc/fstab

	echo "info: move_docker_dir /storage/ssd/docker"
	echo '{ "graph": "/storage/ssd/docker" }' > /etc/docker/daemon.json
	chmod 600 /etc/docker/daemon.json
	systemctl daemon-reload
	systemctl restart docker
	rm -rf /var/lib/docker
fi

echo "info: add_docker_admin ${docker_admin}"
usermod -aG docker "$docker_admin"

echo "info: all_done"
exit 0
