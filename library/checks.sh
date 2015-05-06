is_mount_point() {
	check=$1
	if ( df ${check} | grep -q ${check} ); then
		return 0 
	else
		return 1
	fi
}

is_openrc() {
	[[ "$init" != "openrc" ]] && return 1
}
check_mounted() {
	local potential_mounts=("${iso_root}_i686" "${iso_root}_x86_64" "${iso_root}_i686/etc" "${iso_root}_x86_64/etc"  "${iso_root}_i686/dev" 
		"${iso_root}_x86_64/dev" "${iso_root}_i686/etc_rw" "${iso_root}_x86_64/etc_rw")
	msg "Unmounting FileSystems"
	for mounts in ${potential_mounts[@]}; do
		if ( is_mount_point ${mounts} ); then
			umount ${mounts}
		fi
	done

	if [ -e /dev/md"${usb_md_device}" ]; then
		mdconfig -d -u "${usb_md_device}"
	fi

	if [ -e /dev/md"${iso_md_device}" ]; then
		sync
		mdconfig -d -u "${iso_md_device}"
	fi
}

check_usb() {
	[[ "$create_usb" == "0" ]] && return 0
}

check_iso() {
	[[ "$create_iso" == "0" ]] && return 0
}

check_and_create_dirs() {
	for i in ${arches[@]}; do
		for dirs in ArchBSD_iso_"${i}" ArchBSD_cache_"${i}"; do
			if [ ! -d "${tmp}/${dirs}" ]; then
				mkdir -p "${tmp}/${dirs}"
			fi
		done
	done

	if ( check_iso ); then
		for i in ${arches[@]}; do
			for dirs in ArchBSD_iso_"${i}"/etc_rw; do
				if [ ! -d "${tmp}/${dirs}" ]; then
					mkdir -p "${tmp}/${dirs}"
				fi
			done
		done
	fi
}			
