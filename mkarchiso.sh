#!/usr/bin/bash

tmpdir="/var/tmp/pacbsd"

date=`date +"%Y%m%d"`

init="openrc"

iso_root="${tmpdir}/PacBSD-amd64"

usb_image_size=1200

imgfile="PacBSD-amd64-${date}.img"

files="$(pwd)/files"

die() {
	echo "$@"
	exit 1
}

msg() {
        local mesg=$1; shift
        printf "\033[1;34m==>\033[0;0m ${mesg}\n" "$@"
}

submsg() {
        local mesg=$1; shift
        printf "\033[1;35m  ->\033[0;0m ${mesg}\n" "$@"
}

if [[ ! -d  "${iso_root}" ]]; then
        msg "Creating ${iso_root}"
        mkdir -p "${iso_root}"
fi

create_usb_image() {
        msg "Creating ${usb_image_size}Mb USB image file"

        if [ -e "$(pwd)/${imgfile}" ]; then
                submsg "Removing previous image file"
                rm "$(pwd)/${imgfile}"
	fi

        dd if=/dev/zero of="$(pwd)/${imgfile}" bs=1M count=${usb_image_size} > /dev/null 2>&1

        if [ ! -e /dev/md133 ]; then
                mdconfig -a -t vnode -f "$(pwd)/${imgfile}" -u "133"
        fi
}

create_usb_filesystem() {
        submsg "Creating partition schemes"
        gpart create -s mbr md133 || die "Failed to Create MBR"
        gpart add -t freebsd md133 || die "Failed to Create ufs partition"
        gpart set -a active -i 1 md133 || die "Failed to set active partition"
        gpart create -s bsd md133s1 || die "Failed to Create ufs partition"
        gpart add -t freebsd-ufs md133s1 || die "Failed to Create ufs partition"
        newfs -U -j -L pacbsd /dev/md133s1a || die "Failed to Create ufs partition"
        gpart bootcode -b /boot/boot0 md133 || die "Failed to add bootcode"
        gpart bootcode -b /boot/boot md133s1 || die "Failed to add bootcode"
}

install_base() {
	install -dm755 "${iso_root}/var/lib/pacman"

	pacman -Syy --noconfirm base ${init} --config "${files}/pacman.conf" \
		-r "${iso_root}"
}

create_iso_root() {
        if [[ -e "${tmpdir}/mfsroot" ]]; then
                rm "${tmpdir}/mfsroot"
        fi

	submsg "Creating 40MB mfsroot"
        dd if=/dev/zero of="${tmpdir}/mfsroot" bs=1M count=40 > /dev/null 2>&1

        mdconfig -a -t vnode -f "${tmpdir}/mfsroot" -u "133"

        mkdir -p "${tmpdir}/"/{boot,usr}

        newfs -U -j -L pacbsd /dev/md133

        mount -t ufs /dev/md133 ${iso_root}/

	if [[ -d ${tmpdir}/boot ]]; then
		rm -rf ${tmpdir}/boot
	fi

        if [[ -d ${tmpdir}/usr ]]; then
                rm -rf ${tmpdir}/usr
        fi

	mkdir -p ${tmpdir}/{boot,usr}
        mkdir -p ${iso_root}/{boot,usr}

        mount -t unionfs "${tmpdir}/boot" ${iso_root}/boot

        mount -t unionfs "${tmpdir}/usr" ${iso_root}/usr


}


mount_dev() {
	if [[ ! -d ${iso_root}/dev ]]; then
		mkdir -p ${iso_root}/dev
	fi

        mount -t devfs devfs ${iso_root}/dev
}

config_setup() {
	local media="${1}"
        echo 'hostname="PacBSD"' > ${iso_root}/etc/conf.d/hostname

        cp ${files}/{arch-chroot,pacstrap} ${iso_root}/usr/bin/
        chmod +x ${iso_root}/usr/bin/{pacstrap,arch-chroot}

        cp ${files}/cshrc ${iso_root}/root/.cshrc
        cp ${files}/install.txt ${iso_root}/root/install.txt

        if [[ "${media}" == "usb" ]]; then
                cp ${files}/fstab.mem ${iso_root}/etc/fstab
        else
                cp ${files}/fstab.iso ${iso_root}/etc/fstab
		cp ${files}/loader.conf ${iso_root}/boot/loader.conf
		mkdir -p "${iso_root}/var/iso"
		umount -f ${iso_root}/usr
		umount -f ${iso_root}/boot
		rm -rf ${iso_root}/{usr,boot}
		ln -s /var/iso/usr ${iso_root}/usr
		ln -s /var/iso/boot ${iso_root}/boot
	fi
}

gen_iso() {
        msg "Generating ISO"
        mkisofs -quiet -R -b boot/cdboot -no-emul-boot -V PacBSD -o $(pwd)/PacBSD-amd64-${date}.iso ${iso_root}/
}

cleanup() {
	fuser -k "${iso_root}"
	umount "${iso_root}/dev"
	umount ${iso_root}
	mdconfig -d -u 133

	rm -rf ${iso_root}
	
}

for medium in iso; do
	if [[ "${medium}" == "usb" ]]; then
		msg "Creating USB imagefile"
		create_usb_image

		msg "Creating usb filesystem"
		create_usb_filesystem

		submsg "Mounting USB image device to ${iso_root}"
		mount /dev/md133s1a ${iso_root}
	else
		msg "Creating ISO root"
		create_iso_root
	fi

	mount_dev
	
	install_base

	config_setup "${medium}"

	if [[ "${medium}" == "iso" ]]; then
		umount ${iso_root}/boot
		umount ${iso_root}/usr
		
		cleanup
		mkdir -p "${iso_root}"
		cp -R "${tmpdir}/boot" "${iso_root}/boot"
		cp -R "${tmpdir}/usr" "${iso_root}/usr"
		cp -R "${tmpdir}/mfsroot" "${iso_root}/boot/mfsroot"
		gen_iso
	else
		cleanup
	fi
done

