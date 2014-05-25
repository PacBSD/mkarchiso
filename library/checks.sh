is_mount_point() {
	check=$1
	[[ df ${check} | grep -q ${check} ]] && return 0
}

check_mounted() {
	local potential_mounts=('${iso_root}_${arch}' '${iso_root}_${arch}/etc' '${iso_root}_${arch}/dev')
	for mounts in ${potential_mounts[@]}; do
		if (( is_mount_point ${mounts} )); then
			umount ${mount}
		fi
	done

	if [ -e /dev/md1337 ]; then
		gpart destroy md1337
		mdconfig -d -u 1337
	fi
}

check_are_we_root() {
	[[ "$UID" != "0" ]]; && return 1
}

check_usb() {
	[[ "$create_usb" == "0" ]] && return 0
}

check_and_create_dirs() {
	for dirs in ArchBSD_iso_i686 ArchBSD_iso_x86_64 ArchBSD_cache_i686 ArchBSD_cache_x86_64; do
		if [ ! -d "${tmp}/${dir}" ]; then
			mkdir -p "${tmp}/${dir}"
		fi
	done
}			