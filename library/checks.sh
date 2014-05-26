is_mount_point() {
	check=$1
	if ( df ${check} | grep -q ${check} ); then
		return 0
	else
		return 1
	fi
}

check_mounted() {
	local potential_mounts=("${iso_root}_${arch}" "${iso_root}_${arch}/etc" "${iso_root}_${arch}/dev")
	msg "unmounted filesystems"
	for mounts in ${potential_mounts[@]}; do
		if ( is_mount_point ${mounts} ); then
			umount ${mounts}
		fi
	done

	if [ -e /dev/md1337 ]; then
		msg "Destroying previous filesystems"
		gpart destroy md1337
		mdconfig -d -u 1337
	fi
}

check_are_we_root() {
	[[ "$UID" != "0" ]] && return 1
}

check_usb() {
	[[ "$create_usb" == "0" ]] && return 0
}

check_and_create_dirs() {
	for dirs in ArchBSD_iso_i686 ArchBSD_iso_x86_64 ArchBSD_cache_i686 ArchBSD_cache_x86_64; do
		if [ ! -d "${tmp}/${dirs}" ]; then
			mkdir -p "${tmp}/${dirs}"
		fi
	done
}			
