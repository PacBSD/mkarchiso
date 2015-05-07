msg() {
	local mesg=$1; shift
	printf "\033[1;34m==>\033[0;0m ${mesg}\n" "$@"
}

submsg() {
	local mesg=$1; shift
	printf "\033[1;35m  ->\033[0;0m ${mesg}\n" "$@"
}

create_usb_filesystem() {
	submsg "Creating partition schemes"
	gpart create -s mbr md"${usb_md_device}" || die "Failed to Create MBR"
	gpart add -t freebsd md"${usb_md_device}" || die "Failed to Create ufs partition"
	gpart set -a active -i 1 md"${usb_md_device}" || die "Failed to set active partition"
	gpart create -s bsd md"${usb_md_device}"s1 || die "Failed to Create ufs partition"
	gpart add -t freebsd-ufs md"${usb_md_device}"s1 || die "Failed to Create ufs partition"
	newfs -U -j -L archbsd /dev/md"${usb_md_device}"s1a || die "Failed to Create ufs partition"
	gpart bootcode -b /boot/boot0 md"${usb_md_device}" || die "Failed to add bootcode"
	gpart bootcode -b /boot/boot md"${usb_md_device}"s1 || die "Failed to add bootcode"
}

create_usb_image() {
	check_mounted
	check_and_create_dirs
	msg "Creating $usb_image_size Mb USB image	file"

	if [ -e "${tmp}/${imgfile}" ]; then
		submsg "Removing previous image file"
		rm "${tmp}/${imgfile}"
	else 
		dd if=/dev/zero of="${tmp}/${imgfile}" bs=1M count=${usb_image_size} > /dev/null 2>&1
	fi

	if [ ! -e /dev/md"${usb_md_device}" ]; then
		mdconfig -a -t vnode -f "${tmp}/${imgfile}" -u "${usb_md_device}"	
	fi
}

gen_iso() {
	msg "Generating ISO"
	mkisofs -quiet -R -b boot/cdboot -no-emul-boot -V ArchBSD -o /tmp/ArchBSD-${arch}-${date}.iso ${iso_root}_${arch}/
}

mount_dev() {
	mount -t devfs devfs ${iso_root}_${arch}/dev
}

install_base() {
    pacman -Syy --noconfirm ${base_package[@]} ${init} --config ${config}/pacman.conf.${arch} --cachedir ${tmp}/cache_${arch} \
        -r ${iso_root}_${arch}
}

config_setup() {
	if ( check_usb ); then
		cp ${files}/fstab.mem ${iso_root}_${arch}/etc/fstab
	fi

	if ( check_iso ); then
		cp ${files}/fstab.iso ${iso_root}_${arch}/etc/fstab
		mkdir -p ${iso_root}_${arch}/etc_rw
		if ( is_openrc ); then
			cp ${files}/rw_populate.openrc ${iso_root}_${arch}/etc/init.d/rw_populate
			chmod +x ${iso_root}_${arch}/etc/init.d/rw_populate
			chroot ${iso_root}_${arch} /sbin/rc-update add rw_populate default
		else
			cp ${files}/rw_populate ${iso_root}_${arch}/etc/rc.d/rw_populate
			chmod +x ${iso_root}_${arch}/etc/rc.d/rw_populate
			echo 'tmpmfs="NO"' > ${iso_root}_${arch}/etc/rc.conf
			echo 'rw_populate_enable="YES"' >> ${iso_root}_${arch}/etc/rc.conf
		fi

		for file in motd hostid host.conf; do
			if [ -f ${iso_root}_${arch}/etc/${file} ]; then
				rm ${iso_root}_${arch}/etc/${file}
			fi
		done
	fi

	if ( is_openrc); then
		echo 'hostname="ArchBSD"' > ${iso_root}_${arch}/etc/conf.d/hostname
	else
		echo 'sendmail_enable="NONE"' >> ${iso_root}_${arch}/etc/rc.conf
		echo 'hostid_enable="NO"' >> ${iso_root}_${arch}/etc/rc.conf
		echo 'hostname="ArchBSD"' >> ${iso_root}_${arch}/etc/rc.conf
	fi

	cp ${files}/{arch-chroot,pacstrap} ${iso_root}_${arch}/usr/bin/
	chmod +x ${iso_root}_${arch}/usr/bin/{pacstrap,arch-chroot}

	cp ${files}/cshrc ${iso_root}_${arch}/root/.cshrc
	cp ${files}/install.txt ${iso_root}_${arch}/root/install.txt
}

create_rw_md() {
	if [ -e ${tmp}/etc_files ]; then
		rm ${tmp}/etc_files
	fi
	
	dd if=/dev/zero of=${tmp}/etc_files bs=1M count=10 > /dev/null 2>&1

	if ( check_mounted ); then
		mdconfig -a -t vnode -f ${tmp}/etc_files -u "${rw_md_device}"
		bsdlabel -w md"${rw_md_device}" auto
		newfs md"${rw_md_device}"
		mount /dev/md"${rw_md_device}" ${iso_root}_${arch}/etc_rw
	fi

        if [ -e ${tmp}/var_files ]; then
                rm ${tmp}/var_files
        fi

        dd if=/dev/zero of=${tmp}/var_files bs=1M count=10 > /dev/null 2>&1

        if ( check_mounted ); then
                mdconfig -a -t vnode -f ${tmp}/var_files -u "${var_md_device}"
                bsdlabel -w md"${var_md_device}" auto
                newfs md"${var_md_device}"
                mount /dev/md"${var_md_device}" ${iso_root}_${arch}/var
        fi

}

chroot_setup() {
	if ( check_usb ); then
		chroot ${iso_root}_${arch} hostname ArchBSD
		chroot ${iso_root}_${arch} pacman-key --init
		chroot ${iso_root}_${arch} pacman-key --populate archbsd
	else
		touch ${iso_root}_${arch}/etc_rw/{resolv.conf,hostid,host.conf}
		mkdir -p ${iso_root}_${arch}/etc_rw/pacman.d/gnupg
		echo "Welcome to ArchBSD" > ${iso_root}_${arch}/etc_rw/motd

		[[ -L "${iso_root}_${arch}"/etc/resolv.conf ]] && rm ${iso_root}_${arch}/etc/resolv.conf

		chroot ${iso_root}_${arch} ln -Lws /etc_rw/resolv.conf /etc/resolv.conf
		chroot ${iso_root}_${arch} ln -Ls  /etc_rw/pacman.d/gnupg /etc/pacman.d/gnupg
		chroot ${iso_root}_${arch} pacman-key --init
		chroot ${iso_root}_${arch} pacman-key --populate archbsd
		chroot ${iso_root}_${arch} ln -Lws /etc_rw/motd /etc/motd
		chroot ${iso_root}_${arch} ln -Lws /etc_rw/hostid /etc/hostid
		chroot ${iso_root}_${arch} ln -Lws /etc_rw/host.conf /etc/host.conf
		check_mounted
		cp ${tmp}/etc_files ${iso_root}_${arch}/
		cp ${tmp}/var_files ${iso_root}_${arch}/
	fi
}

clean_up() {
	if [ -d ${iso_root}_${arch} ]; then
		rm -r ${iso_root}_${arch}/
	fi
}

setup_base() {
	for arch in ${arches[@]}; do
		imgfile="ArchBSD-${arch}-${date}.img"
		isofile="ArchBSD-${arch}-${date}.iso"
		# make sure nothing is mounted first
		check_mounted
		# clean up so we're not having left over files from previous runs
		clean_up

		msg "Installing base"
		check_and_create_dirs

		if ( check_usb ); then
			if ( create_usb_image ); then
				create_usb_filesystem
			fi
			submsg "Mounting USB image device to ${iso_root}_${arch}"
			mount /dev/md"${usb_md_device}"s1a ${iso_root}_${arch}
		fi

		if ( check_iso ); then
			create_rw_md
		fi

		submsg "Creating /var/lib/pacman"

		if [ ! -d ${iso_root}_${arch}/var/lib/pacman ]; then
			install -dm755 ${iso_root}_${arch}/var/lib/pacman
		fi
	
		if ( ! install_base ); then
			die "Failed to install base packages"
		fi
	
		if ( ! mount_dev ); then
			die "Failed to mount dev"
		fi

		if ( ! config_setup ); then
			die "Failed to copy setup files"
		fi

		if ( ! chroot_setup ); then
			die "Failed to copy setup files"
		fi

                if [ "${chroot_base}" == "1" ]; then
			chroot ${iso_root}_${arch}
		fi

		if ( check_iso ); then
			echo 'kern.vt.fb.default_mode="1024x768"' >> ${iso_root}_${arch}/boot/loader.conf
			gen_iso
		fi

		if ( ! check_mounted ); then
			die "Failed to unmount file systems"
		fi
	done
}
