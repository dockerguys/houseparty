#!/bin/sh

set -e

debug_mode="false"
docker_admin="administrator"
docker_ver="latest"
containerd_ver="latest"
data_dir=""
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
			echo "  -d | --datadir      move /var/lib/docker to dir"
			echo "  -m | --mirror       repo url: ${docker_baseurl}"
			echo "  -c | --containerd-version  containerd version: ${containerd_ver}"
			echo "  -k | --docker-version      docker version: ${docker_ver}"
			echo ""
			echo "Example:"
			echo "  sudo ./install-docker.sh -d /storage/ssd"
			exit 0
			;;
		-D | --debug)
			debug_mode="true"
			;;
		-u | --admin)
			shift
			docker_admin="$1"
			;;
		-d | --datadir)
			shift
			data_dir="$1"
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
			echo "FATAL! bad_param $1"
			echo "Usage: $0 [--debug] [--admin <user>] [--datadir <dir>] [--mirror <url>] [--containerd-version <ver>] [--docker-version <ver>]"
			exit 1
			;;
	esac
	shift
done

if [ "$debug_mode" = "true" ]; then
	set -ex
fi

if [ $(id -u) != 0 ]; then
	echo "FATAL! require_root_priv"
	exit 1
fi

if [ "x${data_dir}x" != "xx" ] && [ ! -d "$data_dir" ] ; then
	echo "FATAL! data_dir_not_found ${data_dir}"
	exit 1
fi

linux_distro=$(lsb_release -i | cut -d':' -f2 | sed 's/\t//g' | tr '[:upper:]' '[:lower:]')
linux_rel=$(lsb_release -c | cut -d':' -f2 | sed 's/\t//g' | tr '[:upper:]' '[:lower:]')

if [ "$linux_distro" != "ubuntu" ]; then
	echo "FATAL! unsupported_linux_distro ${linux_distro}"
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

echo "info: add_docker_admin ${docker_admin}"
usermod -aG docker "$docker_admin"

if [ "x${data_dir}x" != "xx" ]; then
	echo "info: move_docker_dir ${data_dir}"
	echo "{ \"graph\": \"${data_dir}\" }" > /etc/docker/daemon.json
	chmod 600 /etc/docker/daemon.json
	systemctl daemon-reload
	systemctl restart docker
	rm -rf /var/lib/docker
fi

echo "info: all_done"
exit 0
