msg() {
	local mesg=$1; shift
	printf "\033[1;34m==>\033[0;0m ${mesg}\n" "$@"
}

submsg() {
	local mesg=$1; shift
	printf "\033[1;35m  ->\033[0;0m ${mesg}\n" "$@"
}

(( ! check_are_we_root )) && die "We need to be root"

create_usb_filesystem() {
	submsg "Creating partition schemes"
	gpart create -s mbr md1337 || die "Failed to Create MBR"
	gpart add -t freebsd md1337 || die "Failed to Create ufs partition"
	gpart set -a active -i 1 md1337 || die "Failed to set active partition"
	gpart create -s bsd md1337s1 || die "Failed to Create ufs partition"
	gpart add -t freebsd-ufs md1337s1 || die "Failed to Create ufs partition"
	newfs -U -j -L archbsd /dev/md1337s1a || die "Failed to Create ufs partition"
	gpart bootcode -b /boot/boot0 md1337 || die "Failed to add bootcode"
	gpart bootcode -b /boot/boot md1337s1 || die "Failed to add bootcode"
}

create_usb_image() {
	check_mounted
	check_and_create_dirs
	msg "Creating "$usb_image_size"Mb USB image	file"

	if [ -e "${tmp}/${imgfile}" ]; then
		submsg "Removing previous image file"
		rm "${tmp}/${imgfile}"
	else 
		dd if=/dev/zero of="${tmp}/${imgfile}" bs=1M count=${usb_image_size} &> /dev/null
	fi

	if [ -e /dev/md1337 ]; then
		mdconfig -a -t vnode -f "${tmp}/${imgfile}" -u 1337	
	fi
}

mount_dev() {
	mount -t devfs devfs ${iso_root}_${arch}/dev
}

install_base() {
    pacman -Syy --noconfirm ${base_package[@]} --config ${config}/pacman.conf.${arch} --cachedir ${tmp}/cache_${arch} \
        -r ${iso_root}_${arch}
}

config_setup() {
	if (( check_usb )); then
		cp ${files}/fstab.mem ${iso_root}_${arch}/etc/fstab
	else
		cp ${files}/fstab.iso ${iso_root}_${arch}/etc/fstab
		mkdir -p ${iso_root}_${arch}/etc_rw
		cp ${files}/rw_populate ${iso_root}_${arch}/etc/rc.d/rw_populate
		chmod +x ${iso_root}_${arch}/etc/rc.d/rw_populate
		echo 'rw_populate_enable="YES"' > ${iso_root}_${arch}/etc/rc.conf
		rm ${iso_root}_${arch}/etc/{motd,hostid,host.conf}
	fi

	echo 'sendmail_enable="NONE"' >> ${iso_root}_${arch}/etc/rc.conf
	echo 'hostid_enable="NO"' >> ${iso_root}_${arch}/etc/rc.conf
	echo 'hostname="ArchBSD"' >> ${iso_root}_${arch}/etc/rc.conf

	cp ${files}/pacstrap ${iso_root}_${arch}/usr/bin/pacstrap
	chmod +x ${iso_root}_${arch}/usr/bin/pacstrap

	cp ${files}/cshrc ${iso_root}_${arch}/root/.cshrc
	cp ${files}/install.txt ${iso_root}_${arch}/root/install.txt
}

create_rw_md() {
	if [ ! -e ${tmp}/=etc_files ]; then  
		dd if=/dev/zero of=${tmp}/etc_files bs=1M count=10
	fi
	if (( check_mounted )); then
		mdconfig -a -t vnode -f etc_files -u 5
		bsdlabel -w md5 auto
		newfs md5
		#remount devfs as it got cleared
		mount_dev
		mount /dev/md5 ${iso_root}_${arch}/etc_rw
	fi
}

chroot_setup() {
	if (( create_usb )); then
		chroot ${iso_root}_${arch} hostname ArchBSD
		chroot ${iso_root}_${arch} pacman-key --init
		chroot ${iso_root}_${arch} pacman-key --populate archbsd
	else
		touch ${iso_root}_${arch}/etc_rw/{resolv.conf,hostid,host.conf}
		mkdir -p ${iso_root}_${arch}/etc_rw/pacman.d/gnupg
		echo "Welcome to ArchBSD" >  ${iso_root}_${arch}/etc_rw/motd

		[[ -L "${iso_root}_${arch}"/etc/resolv.conf ]] && rm ${iso_root}_${arch}/etc/resolv.conf

		chroot ${iso_root}_${arch} ln -Lws /etc_rw/resolv.conf /etc/resolv.conf
		chroot ${iso_root)_${arch} ln -Ls  /etc_rw/pacman.d/gnupg /etc/pacman.d/gnupg
		chroot ${iso_root}_${arch} pacman-key --init
		chroot ${iso_root}_${arch} pacman-key --populate archbsd
		chroot ${iso_root}_${arch} ln -Lws /etc_rw/motd /etc/motd
		chroot ${iso_root}_${arch} ln -Lws /etc_rw/hostid /etc/hostid
		chroot ${iso_root}_${arch} ln -Lws /etc_rw/host.conf /etc/host.conf
		check_mounted
		cp ${tmp}/etc_files ${iso_root}_${arch}/
	fi
}

setup_base() {
	for arch in i686 x86_64; do
		msg "Installing base"
		if (( check_usb )); then
			create_usb_image
			submsg "Mounting USB image device to ${iso_root}_${arch}"
			mount /dev/md1337s1a ${iso_root}_${arch}
		fi

		submsg "Creating /var/lib/pacman"

		if [ ! -d ${iso_root}_${arch} ]; then
			install -dm755 ${iso_root}_${arch}/var/lib/pacman
		fi
	
		if (( ! install_base )); then
			err "Failed to install base packages"
		fi
	
		if (( ! mount_dev )); then
			err "Failed to mount dev"
		fi

    	if (( ! config_setup )); then
        	err "Failed to copy setup files"
	    fi

    	if (( ! chroot_setup )); then
        	err "Failed to copy setup files"
	    fi

	done
}

