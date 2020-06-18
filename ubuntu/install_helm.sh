#!/bin/sh
set -e

helm_ver_check_urlbase="https://github.com/helm/helm/releases"
helm_dist_urlbase="https://get.helm.sh"
helm_ver="latest"

while [ "x${1}x" != "xx" ] ; do
	case "$1" in
		-h | --help)
			echo "Usage:"
			echo "  $0 -f <path> [-k <ver>] [-m <url>] [-M <url>] [--skip-checksum] [-D]"
			echo ""
			echo "Install helper for helm"
			echo ""
			echo "Arguments:"
			echo "  -h | --help           shows this documentation"
			echo "  -D | --debug          run in -ex mode"
			echo "  -f | --outfile        download and extract helm binary to here"
			echo "       --skip-checksum  skip tarball checksum"
			echo "  -m | --mirror         binary mirror url"
			echo "  -M | --ver-mirror     version check url"
			echo "  -k | --helm-version   specify version"
			echo ""
			echo "Defaults:"
			echo "  mirror        ${helm_dist_urlbase}"
			echo "  ver-mirror    ${helm_dist_urlbase}"
			echo "  helm-version  ${install_helm_ver}"
			exit 0
			;;
		-D | --debug)
			debug_mode="true"
			;;
		-f | --outfile)
			shift
			install_bin_path="$1"
			;;
		--skip-checksum)
			skip_checksum=true
			;;
		-m | --mirror)
			shift
			helm_dist_urlbase="$1"
			;;
		-M | --ver-mirror)
			shift
			helm_ver_check_urlbase="$1"
			;;
		-k | --helm-version)
			shift
			install_helm_ver="$1"
			;;
		*)
			echo "FATAL! bad_param $1"
			exit 1
			;;
	esac
	shift
done

if [ "x${install_bin_path}x" = "xx" ]; then
	echo "FATAL! arg_mandatory -f|--outfile"
	exit 1
fi

if [ "$debug_mode" = "true" ]; then
	echo "[info] debug_mode"
	set -ex
fi

use_curl=$(which curl || true)
if [ "x${use_curl}x" != "xx" ]; then
	use_curl="true"
else
	use_wget=$(which wget || true)
	if [ "x${use_wget}x" != "xx" ]; then
		echo "[info] curl_not_found"
		use_curl="false"
	else
		echo "FATAL! dep_not_found curl|wget"
		exit 1
	fi
fi

if [ "$helm_ver" = "latest" ]; then
	echo "[info] fetch_latest_version"
	if [ "$use_curl" = "true" ]; then
		latest_helm_ver=$(curl -sL "$helm_ver_check_urlbase" | grep 'href="/helm/helm/releases/tag/v3.[0-9]*.[0-9]*\"' | grep -v no-underline | head -n 1 | cut -d '"' -f 2 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}')
	else
		latest_helm_ver=$(wget "$helm_ver_check_urlbase" -O - 2>&1 | grep 'href="/helm/helm/releases/tag/v3.[0-9]*.[0-9]*\"' | grep -v no-underline | head -n 1 | cut -d '"' -f 2 | awk '{n=split($NF,a,"/");print a[n]}' | awk 'a !~ $0{print}; {a=$0}')
	fi

	echo "[info] latest_version ${latest_helm_ver}"
	helm_ver="$latest_helm_ver"
fi

if [ -f "$install_bin_path" ]; then
	echo "[info] get_installed_version"
	installed_ver=$("$install_bin_path" version --template="{{ .Version }}")

	if [ "$installed_ver" = "$helm_ver" ]; then
		echo "FATAL! already_installed ${helm_ver}"
		exit 1
	fi

	echo "[info] change_version ${installed_ver} to=${helm_ver}"
fi

platform=$(uname | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case $arch in
	armv5*)  arch="armv5";;
	armv6*)  arch="armv6";;
	armv7*)  arch="arm"  ;;
	aarch64) arch="arm64";;
	x86)     arch="386"  ;;
	x86_64)  arch="amd64";;
	i686)    arch="386"  ;;
	i386)    arch="386"  ;;
esac
helm_dist="helm-${helm_ver}-${platform}-${arch}.tar.gz"

download_url="${helm_dist_urlbase}/${helm_dist}"
checksum_url="${download_url}.sha256"

dl_tmp_dir="$(mktemp -dt helm-installer-XXXXXX)"
helm_archive="${dl_tmp_dir}/${helm_dist}"

echo "[info] download_tarball ${download_url} to=${helm_archive}"
if [ "$use_curl" = "true" ]; then
	curl -SL "$download_url" -o "$helm_archive"
else
	wget -O "$helm_archive" "$download_url"
fi

if [ "$skip_checksum" = "true" ]; then
	echo "WARNING! skip_checksum"
else
	echo "[info] download_checksum ${checksum_url} to=${helm_archive}.sha"
	if [ "$use_curl" = "true" ]; then
		curl -SL "$checksum_url" -o "${helm_archive}.sha"
	else
		wget -O "${helm_archive}.sha" "$checksum_url"
	fi

	binary_checksum=$(openssl sha1 -sha256 "$helm_archive" | awk '{print $2}')
	expected_checksum=$(cat "${helm_archive}.sha")

	if [ "$expected_checksum" != "$binary_checksum" ]; then
		echo "FATAL! checksum_error"
		exit 1
	fi
fi

echo "[info] extract_tarball ${helm_archive} to=${dl_tmp_dir}/helm"
mkdir "${dl_tmp_dir}/helm"
tar xf "$helm_archive" -C "${dl_tmp_dir}/helm"

echo "[info] install_binary ${install_bin_path} src=${dl_tmp_dir}/helm/${platform}-${arch}/helm"
sudo cp "${dl_tmp_dir}/helm/${platform}-${arch}/helm" "$install_bin_path"

echo "[info] cleanup ${dl_tmp_dir}"
rm -rf "$dl_tmp_dir"

echo "[info] smoke_test"
new_version=$("$install_bin_path" version --template="{{ .Version }}")
if [ "$new_version" = "$helm_ver" ]; then
	echo "[info] install_success ${helm_ver}"
	exit 0
else
	echo "[info] install_fail ${new_version} expect=${helm_ver}"
	exit 1
fi
