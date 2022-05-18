#!/bin/bash
# Run this script directly in the boot medium with an internet connection
# Make sure the drives that are going to be partitioned are empty
# Run the 'archlinux-post_install.sh' script once this is done in the freshly installed system

# TODO:
#	Test Secure Boot, Sign the EFI binary whenver a new one is built
#	Make sure BIOS works with extended partitions - Not urgent
#	Validation: Fat32 only has capital labels, etc - Not urgent

readonly HOSTNAME="retro"
readonly UEFI_LABEL="Arch Linux T"
readonly TIMEZONE_REGION="America"
readonly TIMEZONE_CITY="New_York"
readonly CPU_TYPE="amd"
readonly ENCRYPT="n"
readonly NVIDIA="n"
readonly VM="y"
readonly DEBUG="y"
readonly Addons=("DisableWatchdog" "Ethernet" "SecureBoot" "Bluetooth")

# Boot, Root, Swap, EFI, Additonal Drives
readonly SWAP_DRIVE="/dev/sdb"
readonly SWAP_TYPE="drive" # Can be one of the following: (drive, nvme, or none)
readonly SWAP_SIZE=("1MiB" "1GiB")
readonly SWAP_LABEL="Swap"
readonly SWAP_NAME="LinuxSwap"
readonly SWAP_PARTITION="1"

# Drive, Size, Name, Partition
readonly ROOT_DRIVE="/dev/sda"
readonly ROOT_SIZE=("1GiB" "8GiB")
readonly ROOT_LABEL="Root"
readonly ROOT_NAME="LinuxRoot"
readonly ROOT_PARTITION="2"
readonly ROOT_TYPE="nvme"

# Drive or root (Included in root), Size, Name
readonly BOOT_DRIVE="root"
readonly BOOT_SIZE=("1MiB" "1GiB")
readonly BOOT_LABEL="BOOT"
readonly BOOT_NAME="LinuxBoot"
readonly BOOT_PARTITION="1"
readonly BOOT_TYPE="nvme"

# Drive, Size, Name, Partition
readonly EFI_DRIVE="/dev/sda"
readonly EFI_SIZE=("1MiB" "1GiB")
readonly EFI_LABEL="EFI"
readonly EFI_NAME="EFI"
readonly EFI_PARTITION="1"
readonly EFI_DIR="/boot"
readonly EFI_TYPE="nvme"

# Drive, Size, Name, Partition
readonly ADDITIONAL_DRIVES=("/dev/sda" "/dev/sdb")
readonly ADDITIONAL_SIZE1=("8GiB" "1GiB")
readonly ADDITIONAL_SIZE2=("100%" "100%")
readonly ADDITIONAL_LABEL=("TestDrive" "OtherDrive")
readonly ADDITIONAL_PARTITION=("3" "2")
readonly ADDITIONAL_NAME=("Test" "Other")
readonly ADDITIONAL_MOUNTPOINT=("/mnt/root/test" "/mnt/home/alex")
readonly ADDITIONAL_ENCRYPTION_MAPPING=("test" "other")
readonly ADDITIONAL_TYPE=("nvme" "nvme")

PackagesNeeded=(base linux linux-firmware iptables-nft sudo pacman-contrib vim ufw python python2 man-db man-pages texinfo git polkit htop base-devel)
KernelParameters=()
NonFallbackParameters=("loglevel=3" "quiet")

validate_variables() {
	if [ "$DEBUG" == "y" ]; then
		echo "Debug mode is turned on. Set the 'DEBUG' variable to something other than 'y' to run the installation"
		exit 2
	fi

	if [ -z "$HOSTNAME" ]; then
		echo "'HOSTNAME' variable cannot be empty"
		exit 2
	fi

	if [ ! -d /usr/share/zoneinfo/"$TIMEZONE_REGION" ]; then
		echo "'TIMEZONE_REGION' variable has a non-existing region"
		exit 2
	fi

	if [ ! -e /usr/share/zoneinfo/"$TIMEZONE_REGION"/"$TIMEZONE_CITY" ]; then
		echo "'TIMEZONE_CITY' variable has a non-existing city"
		exit 2
	fi

	if [[ "$CPU_TYPE" != "amd" && "$CPU_TYPE" != "intel" ]]; then
		echo "'CPU_TYPE' variable must be 'amd' or 'intel'"
		exit 2
	fi

	if [[ "$ENCRYPT" != "y" && "$ENCRYPT" != "n" ]]; then
		echo "'ENCRYPT' variable must be 'y' or 'n'"
		exit 2
	fi

	# for addon in "${Addons[@]}"; do
	# 	if [[ ! "${Addons[*]}" =~ $addon ]]; then
	# 		printf "Only the following addons exist:\n\tDisableWatchdog\n\tEthernet\n\tWi-Fi\n\tSecureBoot\n"
	# 		exit 2
	# 	fi
	# done
}

partition_drives() {
	# Check each drive type for their device
	local drivesToPart=()

	if [[ "$SWAP_TYPE" = "drive" || "$SWAP_TYPE" = "nvme" ]]; then
		drivesToPart[${#drivesToPart[@]}]=$SWAP_DRIVE
	fi

	if [[ ! "${drivesToPart[*]}" =~ ${ROOT_DRIVE} ]]; then
		drivesToPart[${#drivesToPart[@]}]=$ROOT_DRIVE
	fi

	if [[ "$BOOT_DRIVE" != "root" && ! "${drivesToPart[*]}" =~ ${BOOT_DRIVE} ]]; then
		drivesToPart[${#drivesToPart[@]}]=$BOOT_DRIVE
	fi
	
	if [[ "$IS_UEFI" = "true" && ! "${drivesToPart[*]}" =~ ${EFI_DRIVE} ]]; then
		drivesToPart[${#drivesToPart[@]}]=$EFI_DRIVE
	fi

	for drive in "${ADDITIONAL_DRIVES[@]}"; do
		if [[ ! "${drivesToPart[*]}" =~ $drive ]]; then
			drivesToPart[${#drivesToPart[@]}]=$drive
		fi
	done

	for drive in "${drivesToPart[@]}"; do
		local totalPartitions="0"
		local currentPartition="1"
		if [ "$IS_UEFI" = "true" ]; then
			parted -s "$drive" mklabel gpt
		else
			parted -s "$drive" mklabel msdos
		fi

		# Checking how many partitions in the drive are needed
		if [ "$SWAP_DRIVE" = "$drive" ]; then
			totalPartitions=$((totalPartitions + 1))
		fi

		if [ "$ROOT_DRIVE" = "$drive" ]; then
			totalPartitions=$((totalPartitions + 1))
		fi

		if [ "$BOOT_DRIVE" = "$drive" ]; then
			totalPartitions=$((totalPartitions + 1))
		fi

		if [[ "$IS_UEFI" = "true" && "$EFI_DRIVE" = "$drive" ]]; then
			totalPartitions=$((totalPartitions + 1))
		fi

		for additionalDrive in "${ADDITIONAL_DRIVES[@]}"; do
			if [ "$additionalDrive" = "$drive" ]; then
				totalPartitions=$((totalPartitions + 1))
			fi
		done

		while [ $currentPartition -le "$totalPartitions" ]; do
			# Partitioning any needed drives
			if [[ "$SWAP_DRIVE" = "$drive" && $SWAP_PARTITION -eq $currentPartition ]]; then
				if [ "$IS_UEFI" = "true" ]; then
					parted -s "$drive" mkpart "$SWAP_NAME" linux-swap "${SWAP_SIZE[0]}" "${SWAP_SIZE[1]}"
				else
					parted -s "$drive" mkpart primary linux-swap "${SWAP_SIZE[0]}" "${SWAP_SIZE[1]}"
				fi

				if [ "$ENCRYPT" = "n" ]; then
					mkswap -L "$SWAP_LABEL" "${SWAP_DRIVE}$(if [ "${SWAP_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${SWAP_PARTITION}"
					swapon "${SWAP_DRIVE}$(if [ "${SWAP_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${SWAP_PARTITION}"
				fi

				currentPartition=$((currentPartition + 1))
			fi

			if [[ "$ROOT_DRIVE" = "$drive" && "$ROOT_PARTITION" -eq "$currentPartition" ]]; then
				if [ "$IS_UEFI" = "true" ]; then
					parted -s "$drive" mkpart "$ROOT_NAME" ext4 "${ROOT_SIZE[0]}" "${ROOT_SIZE[1]}"
				else
					parted -s "$drive" mkpart primary ext4 "${ROOT_SIZE[0]}" "${ROOT_SIZE[1]}"
				fi

				if [ "$ENCRYPT" = "y" ]; then
					cryptsetup -y -v luksFormat "${ROOT_DRIVE}$(if [ "${ROOT_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${ROOT_PARTITION}"
					cryptsetup open "${ROOT_DRIVE}$(if [ "${ROOT_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${ROOT_PARTITION}" root
					mkfs.ext4 -L "$ROOT_LABEL" /dev/mapper/root
					mount -v /dev/mapper/root /mnt
				else
					mkfs.ext4 -L "$ROOT_LABEL" "${ROOT_DRIVE}$(if [ "${ROOT_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${ROOT_PARTITION}"
					mount -v "${ROOT_DRIVE}$(if [ "${ROOT_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${ROOT_PARTITION}" /mnt
				fi

				currentPartition=$((currentPartition + 1))

				if [[ "$BOOT_DRIVE" = "root" && "$IS_UEFI" = "false" ]]; then
					parted -s "$drive" set "$ROOT_PARTITION" boot on
				fi
			fi

			for (( i=0; i<${#ADDITIONAL_DRIVES[@]}; i++ )); 
			do
				if [[ "${ADDITIONAL_DRIVES[$i]}" = "$drive" && "${ADDITIONAL_PARTITION[$i]}" -eq "$currentPartition" ]]; then
					if [ "$IS_UEFI" = "true" ]; then
						parted -s "$drive" mkpart "${ADDITIONAL_NAME[$i]}" ext4 "${ADDITIONAL_SIZE1[$i]}" "${ADDITIONAL_SIZE2[$i]}"
					else
						parted -s "$drive" mkpart primary ext4 "${ADDITIONAL_SIZE1[$i]}" "${ADDITIONAL_SIZE2[$i]}"
					fi

					if [ "$ENCRYPT" = "y" ]; then
						dd bs=512 count=4 if=/dev/random of=/root/"${ADDITIONAL_ENCRYPTION_MAPPING[$i]}" iflag=fullblock
						chmod 600 /root/"${ADDITIONAL_ENCRYPTION_MAPPING[$i]}"
						
						cryptsetup -qv luksFormat "${ADDITIONAL_DRIVES[$i]}$(if [ "${ADDITIONAL_TYPE[$i]}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${ADDITIONAL_PARTITION[$i]}" /root/"${ADDITIONAL_ENCRYPTION_MAPPING[$i]}"
						cryptsetup open "${ADDITIONAL_DRIVES[$i]}$(if [ "${ADDITIONAL_TYPE[$i]}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${ADDITIONAL_PARTITION[$i]}" "${ADDITIONAL_ENCRYPTION_MAPPING[$i]}" -d /root/"${ADDITIONAL_ENCRYPTION_MAPPING[$i]}"
						mkfs.ext4 -L "${ADDITIONAL_LABEL[$i]}" "/dev/mapper/${ADDITIONAL_ENCRYPTION_MAPPING[$i]}"
					else
						mkfs.ext4 -L "${ADDITIONAL_LABEL[$i]}" "${ADDITIONAL_DRIVES[$i]}$(if [ "${ADDITIONAL_TYPE[$i]}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${ADDITIONAL_PARTITION[$i]}"
					fi

					currentPartition=$((currentPartition + 1))
				fi
			done

			if [[ "$IS_UEFI" = "true" && "$EFI_DRIVE" = "$drive" && "$EFI_PARTITION" -eq $currentPartition ]]; then
				parted -s "$drive" mkpart "$EFI_NAME" fat32 "${EFI_SIZE[0]}" "${EFI_SIZE[1]}"
				parted -s "$drive" set "$EFI_PARTITION" esp on

				mkfs.fat -F 32 -n "$EFI_LABEL" "${EFI_DRIVE}$(if [ "${EFI_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${EFI_PARTITION}"
				currentPartition=$((currentPartition + 1))
			fi

			if [[ "$BOOT_DRIVE" = "$drive" && "$BOOT_PARTITION" -eq "$currentPartition" ]]; then
				if [ "$IS_UEFI" = "true" ]; then
					parted -s "$drive" mkpart "$BOOT_NAME" fat32 "${BOOT_SIZE[0]}" "${BOOT_SIZE[1]}"
					parted -s "$drive" set "$BOOT_PARTITION" bls_boot on
					mkfs.fat -F 32 -n "$BOOT_LABEL" "${BOOT_DRIVE}$(if [ "${BOOT_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${BOOT_PARTITION}"
				else
					parted -s "$drive" mkpart primary ext4 "${BOOT_SIZE[0]}" "${BOOT_SIZE[1]}"
					parted -s "$drive" set "$BOOT_PARTITION" boot on
					mkfs.ext4 -L "$BOOT_LABEL" "${BOOT_DRIVE}$(if [ "${BOOT_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${BOOT_PARTITION}"
				fi

				currentPartition=$((currentPartition + 1))
			fi
		done
	done

	if [ "$BOOT_DRIVE" != "root" ]; then
		mkdir -p /mnt/boot
		mount -v "${BOOT_DRIVE}$(if [ "${BOOT_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${BOOT_PARTITION}" /mnt/boot
	fi

	if [ "$IS_UEFI" = "true" ]; then
		mkdir -p /mnt"${EFI_DIR}"
		mount -v "${EFI_DRIVE}$(if [ "${EFI_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${EFI_PARTITION}" /mnt"${EFI_DIR}"
	fi

	for (( i=0; i<${#ADDITIONAL_DRIVES[@]}; i++ )); 
	do
		if [ "$ENCRYPT" = "y" ]; then
			mkdir -p "${ADDITIONAL_MOUNTPOINT[$i]}"
			mount -v "/dev/mapper/${ADDITIONAL_ENCRYPTION_MAPPING[$i]}" "${ADDITIONAL_MOUNTPOINT[$i]}"
		else
			mkdir -p "${ADDITIONAL_MOUNTPOINT[$i]}"
			mount -v "${ADDITIONAL_DRIVES[$i]}$(if [ "${ADDITIONAL_TYPE[$i]}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${ADDITIONAL_PARTITION[$i]}" "${ADDITIONAL_MOUNTPOINT[$i]}"
		fi
	done
}

pre_checks() {
	# Get CPU ucode
	if [ "$CPU_TYPE" = "amd" ]; then
		PackagesNeeded[${#PackagesNeeded[@]}]="amd-ucode"
	elif [ "$CPU_TYPE" = "intel" ]; then
		PackagesNeeded[${#PackagesNeeded[@]}]="intel-ucode"
	fi

	# Is booted in UEFI or not
	IS_UEFI=false
	if [ -d /sys/firmware/efi/efivars ]; then
		echo "We booted in UEFI mode"
		IS_UEFI=true
		PackagesNeeded[${#PackagesNeeded[@]}]="efibootmgr"
	else
		PackagesNeeded[${#PackagesNeeded[@]}]="grub"
	fi

	if [ "$ENCRYPT" = "y" ]; then
		modprobe dm_crypt
	fi

	timedatectl set-ntp true
}

install_addons() {
	for addon in "${Addons[@]}"; do
		if [ "$addon" = "DisableWatchdog" ]; then
			KernelParameters[${#KernelParameters[@]}]="nowatchdog"
			printf "blacklist iTCO_wdt\n" > /mnt/etc/modprobe.d/nowatchdog.conf
		fi

		if [ "$addon" = "Ethernet" ]; then
			arch-chroot /mnt pacman -S --noconfirm --asexplicit dhcpcd
			printf "noarp\n" >> /mnt/etc/dhcpcd.conf
		fi

		if [ "$addon" = "Wi-Fi" ]; then
			arch-chroot /mnt pacman -S --noconfirm --asexplicit networkmanager
			arch-chroot /mnt systemctl enable NetworkManager.service
			arch-chroot /mnt systemctl enable systemd-resolved.service

			rm -rf /mnt/etc/resolv.conf
			arch-chroot /mnt ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
		fi

		if [ "$addon" = "Bluetooth" ]; then
			arch-chroot /mnt pacman -S --noconfirm --asexplicit bluez bluez-utils blueman
			arch-chroot /mnt modprobe btusb
			arch-chroot /mnt systemctl enable bluetooth.service
		fi

		if [ "$addon" = "SecureBoot" ]; then
			arch-chroot /mnt pacman -S --noconfirm --asexplicit sbsigntools efitools

			local secureBootDir="/root/secure-boot"
			mkdir -p /mnt"$secureBootDir"/{db,dbx,KEK,PK,windows,backups}
			arch-chroot /mnt efi-readvar -v PK -o "$secureBootDir"/backups/old_PK.esl
			arch-chroot /mnt efi-readvar -v KEK -o "$secureBootDir"/backups/old_KEK.esl
			arch-chroot /mnt efi-readvar -v db -o "$secureBootDir"/backups/old_db.esl
			arch-chroot /mnt efi-readvar -v dbx -o "$secureBootDir"/backups/old_dbx.esl
			arch-chroot /mnt uuidgen --random > /mnt"$secureBootDir"/GUID.txt

			# Platform Key
			arch-chroot /mnt openssl req -newkey rsa:4096 -nodes -keyout "$secureBootDir"/PK/PK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Platform Key/" -out "$secureBootDir"/PK/PK.crt
			arch-chroot /mnt openssl x509 -outform DER -in "$secureBootDir"/PK/PK.crt -out "$secureBootDir"/PK/PK.cer
			arch-chroot /mnt cert-to-efi-sig-list -g "$(< /mnt"$secureBootDir"/GUID.txt)" "$secureBootDir"/PK/PK.crt "$secureBootDir"/PK/PK.esl
			arch-chroot /mnt sign-efi-sig-list -g "$(< /mnt"$secureBootDir"/GUID.txt)" -k "$secureBootDir"/PK/PK.key -c "$secureBootDir"/PK/PK.crt PK "$secureBootDir"/PK/PK.esl "$secureBootDir"/PK/PK.auth

			# KEK
			arch-chroot /mnt openssl req -newkey rsa:4096 -nodes -keyout "$secureBootDir"/KEK/KEK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Key Exchange Key/" -out "$secureBootDir"/KEK/KEK.crt
			arch-chroot /mnt openssl x509 -outform DER -in "$secureBootDir"/KEK/KEK.crt -out "$secureBootDir"/KEK/KEK.cer
			arch-chroot /mnt cert-to-efi-sig-list -g "$(< /mnt"$secureBootDir"/GUID.txt)" "$secureBootDir"/KEK/KEK.crt "$secureBootDir"/KEK/KEK.esl
			arch-chroot /mnt sign-efi-sig-list -g "$(< /mnt"$secureBootDir"/GUID.txt)" -k "$secureBootDir"/PK/PK.key -c "$secureBootDir"/PK/PK.crt KEK "$secureBootDir"/KEK/KEK.esl "$secureBootDir"/KEK/KEK.auth

			# db
			arch-chroot /mnt openssl req -newkey rsa:4096 -nodes -keyout "$secureBootDir"/db/db.key -new -x509 -sha256 -days 3650 -subj "/CN=my Signature Database key/" -out "$secureBootDir"/db/db.crt
			arch-chroot /mnt openssl x509 -outform DER -in "$secureBootDir"/db/db.crt -out "$secureBootDir"/db/db.cer
			arch-chroot /mnt cert-to-efi-sig-list -g "$(< /mnt"$secureBootDir"/GUID.txt)" "$secureBootDir"/db/db.crt "$secureBootDir"/db/db.esl
			arch-chroot /mnt sign-efi-sig-list -g "$(< /mnt"$secureBootDir"/GUID.txt)" -k "$secureBootDir"/KEK/KEK.key -c "$secureBootDir"/KEK/KEK.crt db "$secureBootDir"/db/db.esl "$secureBootDir"/db/db.auth

			# Windows signatures
			arch-chroot /mnt curl -o "$secureBootDir"/windows/win_boot.crt "https://www.microsoft.com/pkiops/certs/MicWinProPCA2011_2011-10-19.crt"
			arch-chroot /mnt curl -o "$secureBootDir"/windows/win_firmware.crt "https://www.microsoft.com/pkiops/certs/MicCorUEFCA2011_2011-06-27.crt"
			arch-chroot /mnt curl -o "$secureBootDir"/windows/win_dbx.bin "https://uefi.org/sites/default/files/resources/dbxupdate_x64.bin"

			arch-chroot /mnt sbsiglist --owner 77fa9abd-0359-4d32-bd60-28f4e78f784b --type x509 --output "$secureBootDir"/windows/MS_Win_db.esl "$secureBootDir"/windows/win_boot.crt
			arch-chroot /mnt sbsiglist --owner 77fa9abd-0359-4d32-bd60-28f4e78f784b --type x509 --output "$secureBootDir"/windows/MS_UEFI_db.esl "$secureBootDir"/windows/win_firmware.crt
			arch-chroot /mnt cat "$secureBootDir"/windows/MS_Win_db.esl "$secureBootDir"/windows/MS_UEFI_db.esl > /mnt"$secureBootDir"/windows/MS_db.esl

			arch-chroot /mnt sign-efi-sig-list -a -g 77fa9abd-0359-4d32-bd60-28f4e78f784b -k "$secureBootDir"/KEK/KEK.key -c "$secureBootDir"/KEK/KEK.crt db "$secureBootDir"/windows/MS_db.esl "$secureBootDir"/windows/add_MS_db.auth

			# Enrolling Keys
			mkdir -p /mnt/etc/secureboot/keys/{db,dbx,KEK,PK}
			cp /mnt"$secureBootDir"/PK/PK.auth /mnt/etc/secureboot/keys/PK/PK.auth
			cp /mnt"$secureBootDir"/KEK/KEK.auth /mnt/etc/secureboot/keys/KEK/KEK.auth
			cp /mnt"$secureBootDir"/db/db.auth /mnt/etc/secureboot/keys/db/db.auth
			cp /mnt"$secureBootDir"/windows/add_MS_db.auth /mnt/etc/secureboot/keys/db/add_MS_db.auth
			cp /mnt"$secureBootDir"/windows/win_dbx.bin /mnt/etc/secureboot/keys/dbx/win_dbx.bin

			arch-chroot /mnt sbkeysync --verbose
			arch-chroot /mnt sbkeysync --verbose --pk
		fi
	done
}

os_installation() {
	pacstrap /mnt "${PackagesNeeded[@]}"

	if [ "$BOOT_DRIVE" != "root" ]; then
		umount -v /mnt/boot
	fi
	if [ "$IS_UEFI" = "true" ]; then
		umount -v /mnt"${EFI_DIR}"
	fi

	genfstab -U /mnt >> /mnt/etc/fstab

	if [ "$BOOT_DRIVE" != "root" ]; then
		mount -v "${BOOT_DRIVE}$(if [ "${BOOT_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${BOOT_PARTITION}" /mnt/boot
	fi
	if [ "$IS_UEFI" = "true" ]; then
		mount -v "${EFI_DRIVE}$(if [ "${EFI_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${EFI_PARTITION}" /mnt"${EFI_DIR}"
	fi
	
	arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE_REGION/$TIMEZONE_CITY /etc/localtime
	arch-chroot /mnt hwclock --systohc

	sed -i "s/#en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /mnt/etc/locale.gen
	arch-chroot /mnt locale-gen
	echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

	echo "$HOSTNAME" > /mnt/etc/hostname
	printf '127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\t%s\n' "$HOSTNAME" > /mnt/etc/hosts

	install_addons

	if [ "$VM" = "y" ]; then
		arch-chroot /mnt pacman -S --noconfirm --asexplicit virtualbox-guest-utils
		arch-chroot /mnt systemctl enable vboxservice.service
	fi

	if [ "$NVIDIA" = "y" ]; then
		KernelParameters[${#KernelParameters[@]}]="nvidia-drm.modeset=1"
	fi

	if [ "$ENCRYPT" = "y" ]; then
		if [[ "$SWAP_TYPE" = "drive" || "$SWAP_TYPE" = "nvme" ]]; then
			# Swap encryption
			printf "swap\t%s\t/dev/urandom\tswap,cipher=aes-cbc-essiv:sha256,size=256\n" "$(find -L /dev/disk -samefile ${SWAP_DRIVE}"$(if [ "${SWAP_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)"${SWAP_PARTITION} | head -n1)" | tee -a /mnt/etc/crypttab
			printf "/dev/mapper/swap\tnone\tswap\tdefaults\t0 0\n" >> /mnt/etc/fstab
		fi

		# Additional Drive encryption
		for (( i=0; i<${#ADDITIONAL_DRIVES[@]}; i++ )); 
		do
			mv /root/"${ADDITIONAL_ENCRYPTION_MAPPING[$i]}" /mnt/root/"${ADDITIONAL_ENCRYPTION_MAPPING[$i]}.key"
			printf "%s\tUUID=$(lsblk -dno UUID "${ADDITIONAL_DRIVES[$i]}$(if [ "${ADDITIONAL_TYPE[$i]}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${ADDITIONAL_PARTITION[$i]}")\t%s\n" "${ADDITIONAL_ENCRYPTION_MAPPING[$i]}" "/root/${ADDITIONAL_ENCRYPTION_MAPPING[$i]}.key" | tee -a /mnt/etc/crypttab
		done

		sed -i "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard modconf block encrypt filesystems fsck)/" /mnt/etc/mkinitcpio.conf	

		KernelParameters[${#KernelParameters[@]}]="cryptdevice=UUID=$(lsblk -dno UUID ${ROOT_DRIVE}"$(if [ "${ROOT_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)"${ROOT_PARTITION}):root"
		KernelParameters[${#KernelParameters[@]}]="root=/dev/mapper/root"
	fi

	echo "Enter the root password"
	arch-chroot /mnt passwd

	if [ "$IS_UEFI" = "true" ]; then
		local ucode
		local cmdlineDir="/root"

		if [ "$CPU_TYPE" = "amd" ]; then
			ucode="amd-ucode.img"
		elif [ "$CPU_TYPE" = "intel" ]; then
			ucode="intel-ucode.img"
		fi

		if [ "$ENCRYPT" = "n" ]; then
			KernelParameters[${#KernelParameters[@]}]="root=UUID=$(lsblk -dno UUID ${ROOT_DRIVE}"$(if [ "${ROOT_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)"${ROOT_PARTITION})"
		fi
		KernelParameters[${#KernelParameters[@]}]="rw"

		mkdir -p /mnt/etc/kernel
		mkdir -p /mnt/boot/EFI/Linux
		mkdir -p /mnt"$cmdlineDir"
		printf "# mkinitcpio preset file for the 'linux' package\n\nALL_config=\"/etc/mkinitcpio.conf\"\nALL_kver=\"/boot/vmlinuz-linux\"\nALL_microcode=(/boot/%s)\n\nPRESETS=('default' 'fallback')\n\ndefault_image=\"/boot/initramfs-linux.img\"\ndefault_efi_image=\"/boot/EFI/Linux/arch-linux.efi\"\ndefault_options=\"--splash /usr/share/systemd/bootctl/splash-arch.bmp --cmdline %s/cmdline\"\n\nfallback_image=\"/boot/initramfs-linux-fallback.img\"\nfallback_efi_image=\"/boot/EFI/Linux/arch-linux-fallback.efi\"\nfallback_options=\"-S autodetect --splash /usr/share/systemd/bootctl/splash-arch.bmp --cmdline %s/cmdline-fallback\"\n" "$ucode" "$cmdlineDir" "$cmdlineDir" > /mnt/etc/mkinitcpio.d/linux.preset
		printf "%s %s\n" "${KernelParameters[*]}" "${NonFallbackParameters[*]}" > /mnt/"$cmdlineDir"/cmdline
		printf "%s\n" "${KernelParameters[*]}" > /mnt"$cmdlineDir"/cmdline-fallback
		arch-chroot /mnt mkinitcpio -p linux

		if [[ "${Addons[*]}" =~ "SecureBoot" ]]; then
			arch-chroot /mnt sbsign --key /root/secure-boot/db/db.key --cert /root/secure-boot/db/db.crt --output /boot/EFI/Linux/arch-linux.efi /boot/EFI/Linux/arch-linux.efi
			arch-chroot /mnt sbsign --key /root/secure-boot/db/db.key --cert /root/secure-boot/db/db.crt --output /boot/EFI/Linux/arch-linux-fallback.efi /boot/EFI/Linux/arch-linux-fallback.efi
		fi

		arch-chroot /mnt efibootmgr --create --disk "$EFI_DRIVE" --part "$EFI_PARTITION" --label "$UEFI_LABEL" --loader "/EFI/Linux/arch-linux.efi" --verbose
		arch-chroot /mnt efibootmgr --create --disk "$EFI_DRIVE" --part "$EFI_PARTITION" --label "$UEFI_LABEL-Fallback" --loader "/EFI/Linux/arch-linux-fallback.efi" --verbose
	else
		arch-chroot /mnt mkinitcpio -P
		if [ "$BOOT_DRIVE" = "root" ]; then
			arch-chroot /mnt grub-install --target=i386-pc "$ROOT_DRIVE"
		else
			arch-chroot /mnt grub-install --target=i386-pc "$BOOT_DRIVE"
		fi

		sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"%GRUB_CMDLINE_LINUX_DEFAULT=\"${NonFallbackParameters[*]}\"%" /mnt/etc/default/grub
		sed -i "s%GRUB_CMDLINE_LINUX=\"\"%GRUB_CMDLINE_LINUX=\"${KernelParameters[*]}\"%" /mnt/etc/default/grub
		arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
	fi

	# Post setup
	mkdir -p /mnt/etc/pacman.d/hooks
	if [ "$BOOT_DRIVE" != "root" ]; then
		printf "[Trigger]\nType = Package\nOperation = Upgrade\nOperation = Install\nOperation = Remove\nTarget = *\n\n[Action]\nDescription = Mounting boot\nWhen = PreTransaction\nExec = /usr/bin/mount -v %s /boot\n" "${BOOT_DRIVE}$(if [ "${BOOT_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${BOOT_PARTITION}" > /mnt/etc/pacman.d/hooks/0-mount-boot.hook
		printf "[Trigger]\nType = Package\nOperation = Upgrade\nOperation = Install\nOperation = Remove\nTarget = *\n\n[Action]\nDescription = Un-Mounting boot\nWhen = PostTransaction\nExec = /usr/bin/umount -v /boot\n" > /mnt/etc/pacman.d/hooks/99-unmount-boot.hook
	fi
	if [ "$IS_UEFI" = "true" ]; then
		printf "[Trigger]\nType = Package\nOperation = Upgrade\nOperation = Install\nOperation = Remove\nTarget = *\n\n[Action]\nDescription = Mounting ESP\nWhen = PreTransaction\nExec = /usr/bin/mount -v %s %s\n" "${EFI_DRIVE}$(if [ "${EFI_TYPE}" = "nvme" ]; then echo "p" ;else echo "" ;fi)${EFI_PARTITION}" "${EFI_DIR}" > /mnt/etc/pacman.d/hooks/0-mount-esp.hook
		printf "[Trigger]\nType = Package\nOperation = Upgrade\nOperation = Install\nOperation = Remove\nTarget = *\n\n[Action]\nDescription = Un-Mounting ESP\nWhen = PostTransaction\nExec = /usr/bin/umount -v %s\n" "${EFI_DIR}" > /mnt/etc/pacman.d/hooks/99-unmount-esp.hook
	fi
	if [[ "${Addons[*]}" =~ "SecureBoot" ]]; then
		printf "[Trigger]\nOperation = Upgrade\nOperation = Install\nOperation = Remove\nType = Package\nTarget = *\n\n[Action]\nDescription = Signing the Unified Kernel Images\nWhen = PostTransaction\nExec = /bin/sh -c 'sbsign --key /root/secure-boot/db/db.key --cert /root/secure-boot/db/db.crt --output /boot/EFI/Linux/arch-linux.efi /boot/EFI/Linux/arch-linux.efi && sbsign --key /root/secure-boot/db/db.key --cert /root/secure-boot/db/db.crt --output /boot/EFI/Linux/arch-linux-fallback.efi /boot/EFI/Linux/arch-linux-fallback.efi'\nDepends = sbsigntools\n" > /mnt/etc/pacman.d/hooks/98-sign-kernel-images.hook
	fi

	if [ "$VM" = "y" ]; then
		arch-chroot /mnt ln -s /dev/null /etc/tmpfiles.d/linux-firmware.conf
	fi
}

validate_variables
pre_checks
partition_drives
os_installation

echo "Installation complete! Reboot your system into the freshly installed OS and run the 'archlinux-post_install.sh' script as root"
