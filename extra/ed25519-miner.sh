#!/bin/sh
set -e

usage() {
	echo "Usage: $0 [-c] -o <path> -w <word>"
	echo "Mining utility for vanity ed25519 public key suffix"
	echo "Version 1.0.0"
	echo ""
	echo "Parameters:"
	echo "    -c | --case-sensitive   case-sensitive search"
	echo "    -o | --outfile          path to save private key"
	echo "    -w | --word             public key suffix to match"
	echo ""
}

case_sensitive="false"
vanity_word=""
out_file=""

while [ "x${1}x" != "xx" ] ; do
	case "$1" in
		-h | --help)
			usage
			exit 0
			;;
		-c | --case-sensitive)
			case_sensitive="true"
			;;
		-o | --outfile)
			shift
			out_file="$1"
			;;
		-w | --word)
			shift
			vanity_word="$1"
			;;
		*)
			echo "[fatal] bad_param $1"
			usage
			exit 1
			;;
	esac
	shift
done

if [ "x${vanity_word}x" = "xx" ]; then
	echo "[fatal] require_param -w/--word <word>"
	usage
	exit 1
fi
if [ "x${out_file}x" = "xx" ]; then
	echo "[fatal] require_param -o/--outfile <path>"
	usage
	exit 1
fi

vanity_len=$(echo "$vanity_word" | wc -c)
try_count=0
time_start=$(date +%s)
report_interval=1000
while "true" ; do
	if [ $(awk "BEGIN { print ${try_count}%${report_interval} }") = "0" ]; then
		elapsed_seconds=$(awk "BEGIN { print $(date +%s) - ${time_start} }")
		elapsed_time=$(awk -v t="$elapsed_seconds" 'BEGIN { t=int(t*1000); printf "%d:%02d:%02d\n", t/3600000, t/60000%60, t/1000%60 }')
		echo "[info] try ${try_count} elapsed=${elapsed_time}"
	fi

	ssh-keygen -q -t ed25519 -f "$out_file" -N ''
	if [ "$case_sensitive" = "false" ] && [ "$(ssh-keygen -y -f "$out_file" | tail -c"$vanity_len" | tr '[:upper:]' '[:lower:]')" = "$vanity_word" ]; then
		break
	elif [ "$case_sensitive" = "true" ] && [ "$(ssh-keygen -y -f "$out_file" | tail -c"$vanity_len")" = "$vanity_word" ]; then
		break
	else
		rm "$out_file"
	fi
	try_count=$(awk "BEGIN { print ${try_count}+1 }")
done

echo "[info] pubkey_suffix_match_found"
echo "[info] mining_attempts ${try_count}"

elapsed_seconds=$(awk "BEGIN { print $(date +%s) - ${time_start} }")
elapsed_time=$(awk -v t="$elapsed_seconds" 'BEGIN { t=int(t*1000); printf "%d:%02d:%02d\n", t/3600000, t/60000%60, t/1000%60 }')
echo "[info] elapsed ${elapsed_time}"

ssh-keygen -y -f "$out_file"
