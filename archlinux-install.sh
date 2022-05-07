#!/bin/bash
# Run this script directly in the boot medium with an internet connection
# Make sure the drives that are going to be partitioned are empty
# Run the 'archlinux-post_install.sh' script once this is done in the freshly installed system

# TODO:
#	Secure Boot

#	Make sure BIOS works with extended partitions - Not urgent
#	Validation: Fat32 only has capital labels, etc - Not urgent

# Testing Notes:
#	Log installation and check any errors
#	Make sure each line does what it's supposed to do

readonly HOSTNAME="retro"
readonly TIMEZONE_REGION="America"
readonly TIMEZONE_CITY="New_York"
readonly CPU_TYPE="amd"
readonly ENCRYPT="y"
readonly NVIDIA="n"
readonly VM="y"
readonly DEBUG="y"

# Boot, Root, Swap, EFI, Additonal Drives
readonly SWAP_DRIVE="/dev/sdb"
readonly SWAP_TYPE="drive" # Can be one of the following: (drive or none)
readonly SWAP_SIZE=("1MiB" "1GiB")
readonly SWAP_LABEL="Swap"
readonly SWAP_NAME="LinuxSwap"
readonly SWAP_PARTITION="1"

# Drive, Size, Name, Partition
readonly ROOT_DRIVE="/dev/sda"
readonly ROOT_SIZE=("2GiB" "8GiB")
readonly ROOT_LABEL="Root"
readonly ROOT_NAME="LinuxRoot"
readonly ROOT_PARTITION="3"

# Drive or root (Included in root), Size, Name
readonly BOOT_DRIVE="/dev/sda"
readonly BOOT_SIZE=("1MiB" "1GiB")
readonly BOOT_LABEL="BOOT"
readonly BOOT_NAME="LinuxBoot"
readonly BOOT_PARTITION="1"

# Drive, Size, Name, Partition
readonly EFI_DRIVE="/dev/sda"
readonly EFI_SIZE=("1GiB" "2GiB")
readonly EFI_LABEL="EFI"
readonly EFI_NAME="EFI"
readonly EFI_PARTITION="2"

# Drive, Size, Name, Partition
readonly ADDITIONAL_DRIVES=("/dev/sda" "/dev/sdb")
readonly ADDITIONAL_SIZE1=("8GiB" "1GiB")
readonly ADDITIONAL_SIZE2=("100%" "100%")
readonly ADDITIONAL_LABEL=("TestDrive" "OtherDrive")
readonly ADDITIONAL_PARTITION=("4" "2")
readonly ADDITIONAL_NAME=("Test" "Other")
readonly ADDITIONAL_MOUNTPOINT=("/mnt/root/test" "/mnt/home/alex")
readonly ADDITIONAL_ENCRYPTION_MAPPING=("test" "other")

readonly Addons=("DisableWatchdog" "Ethernet")
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
}

partition_drives() {
	# Check each drive type for their device
	local drivesToPart=()

	if [ "$SWAP_TYPE" = "drive" ]; then
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
					mkswap -L "$SWAP_LABEL" "${SWAP_DRIVE}${SWAP_PARTITION}"
					swapon "${SWAP_DRIVE}${SWAP_PARTITION}"
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
					cryptsetup -y -v luksFormat "${ROOT_DRIVE}${ROOT_PARTITION}"
					cryptsetup open "${ROOT_DRIVE}${ROOT_PARTITION}" root
					mkfs.ext4 -L "$ROOT_LABEL" /dev/mapper/root
					mount -v /dev/mapper/root /mnt
				else
					mkfs.ext4 -L "$ROOT_LABEL" "${ROOT_DRIVE}${ROOT_PARTITION}"
					mount -v "${ROOT_DRIVE}${ROOT_PARTITION}" /mnt
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
						
						cryptsetup -qv luksFormat "${ADDITIONAL_DRIVES[$i]}${ADDITIONAL_PARTITION[$i]}" /root/"${ADDITIONAL_ENCRYPTION_MAPPING[$i]}"
						cryptsetup open "${ADDITIONAL_DRIVES[$i]}${ADDITIONAL_PARTITION[$i]}" "${ADDITIONAL_ENCRYPTION_MAPPING[$i]}" -d /root/"${ADDITIONAL_ENCRYPTION_MAPPING[$i]}"
						mkfs.ext4 -L "${ADDITIONAL_LABEL[$i]}" "/dev/mapper/${ADDITIONAL_ENCRYPTION_MAPPING[$i]}"
					else
						mkfs.ext4 -L "${ADDITIONAL_LABEL[$i]}" "${ADDITIONAL_DRIVES[$i]}${ADDITIONAL_PARTITION[$i]}"
					fi

					currentPartition=$((currentPartition + 1))
				fi
			done

			if [[ "$IS_UEFI" = "true" && "$EFI_DRIVE" = "$drive" && "$EFI_PARTITION" -eq $currentPartition ]]; then
				parted -s "$drive" mkpart "$EFI_NAME" fat32 "${EFI_SIZE[0]}" "${EFI_SIZE[1]}"
				parted -s "$drive" set "$EFI_PARTITION" esp on

				mkfs.fat -F 32 -n "$EFI_LABEL" "${EFI_DRIVE}${EFI_PARTITION}"
				currentPartition=$((currentPartition + 1))
			fi

			if [[ "$BOOT_DRIVE" = "$drive" && "$BOOT_PARTITION" -eq "$currentPartition" ]]; then
				if [ "$IS_UEFI" = "true" ]; then
					parted -s "$drive" mkpart "$BOOT_NAME" fat32 "${BOOT_SIZE[0]}" "${BOOT_SIZE[1]}"
					parted -s "$drive" set "$BOOT_PARTITION" bls_boot on
					mkfs.fat -F 32 -n "$BOOT_LABEL" "${BOOT_DRIVE}${BOOT_PARTITION}"
				else
					parted -s "$drive" mkpart primary ext4 "${BOOT_SIZE[0]}" "${BOOT_SIZE[1]}"
					parted -s "$drive" set "$BOOT_PARTITION" boot on
					mkfs.ext4 -L "$BOOT_LABEL" "${BOOT_DRIVE}${BOOT_PARTITION}"
				fi

				currentPartition=$((currentPartition + 1))
			fi
		done
	done

	if [ "$BOOT_DRIVE" != "root" ]; then
		mkdir -p /mnt/boot
		mount -v "${BOOT_DRIVE}${BOOT_PARTITION}" /mnt/boot
	fi

	if [ "$IS_UEFI" = "true" ]; then
		mkdir -p /mnt/efi
		mount -v "${EFI_DRIVE}${EFI_PARTITION}" /mnt/efi
	fi

	for (( i=0; i<${#ADDITIONAL_DRIVES[@]}; i++ )); 
	do
		if [ "$ENCRYPT" = "y" ]; then
			mkdir -p "${ADDITIONAL_MOUNTPOINT[$i]}"
			mount -v "/dev/mapper/${ADDITIONAL_ENCRYPTION_MAPPING[$i]}" "${ADDITIONAL_MOUNTPOINT[$i]}"
		else
			mkdir -p "${ADDITIONAL_MOUNTPOINT[$i]}"
			mount -v "${ADDITIONAL_DRIVES[$i]}${ADDITIONAL_PARTITION[$i]}" "${ADDITIONAL_MOUNTPOINT[$i]}"
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
			arch-chroot /mnt ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf # TODO: Fix this
		fi
	done
}

os_installation() {
	pacstrap /mnt "${PackagesNeeded[@]}"

	if [ "$BOOT_DRIVE" != "root" ]; then
		umount -v /mnt/boot
	fi
	if [ "$IS_UEFI" = "true" ]; then
		umount -v /mnt/efi
	fi

	genfstab -U /mnt >> /mnt/etc/fstab

	mkdir -p /mnt/etc/pacman.d/hooks
	if [ "$BOOT_DRIVE" != "root" ]; then
		mount -v "${BOOT_DRIVE}${BOOT_PARTITION}" /mnt/boot
		printf "[Trigger]\nType = Package\nOperation = Upgrade\nTarget = *\n\n[Action]\nDescription = Mounting boot\nWhen = PreTransaction\nExec = /usr/bin/mount -v %s /boot\n" "${BOOT_DRIVE}${BOOT_PARTITION}" > /mnt/etc/pacman.d/hooks/01-mount-boot.hook
	fi
	if [ "$IS_UEFI" = "true" ]; then
		mount -v "${EFI_DRIVE}${EFI_PARTITION}" /mnt/efi
		printf "[Trigger]\nType = Package\nOperation = Upgrade\nTarget = *\n\n[Action]\nDescription = Mounting EFI\nWhen = PreTransaction\nExec = /usr/bin/mount -v %s /efi\n" "${EFI_DRIVE}${EFI_PARTITION}" > /mnt/etc/pacman.d/hooks/01-mount-efi.hook
	fi

	printf "[Trigger]\nType = Package\nOperation = Upgrade\nTarget = systemd\n\n[Action]\nDescription = Gracefully upgrading systemd-boot...\nWhen = PostTransaction\nExec = /usr/bin/systemctl restart systemd-boot-update.service\n" >/mnt/etc/pacman.d/hooks/100-systemd-boot.hook
	
	arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE_REGION/$TIMEZONE_CITY /etc/localtime
	arch-chroot /mnt hwclock --systohc

	sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /mnt/etc/locale.gen
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
		if [ "$SWAP_TYPE" = "drive" ]; then
			# Swap encryption
			printf "swap\t%s\t/dev/urandom\tswap,cipher=aes-cbc-essiv:sha256,size=256\n" "$(find -L /dev/disk -samefile ${SWAP_DRIVE}${SWAP_PARTITION} | head -n1)" | tee -a /mnt/etc/crypttab
			printf "/dev/mapper/swap\tnone\tswap\tdefaults\t0 0\n" >> /mnt/etc/fstab
		fi

		# Additional Drive encryption
		for (( i=0; i<${#ADDITIONAL_DRIVES[@]}; i++ )); 
		do
			mv /root/"${ADDITIONAL_ENCRYPTION_MAPPING[$i]}" /mnt/root/"${ADDITIONAL_ENCRYPTION_MAPPING[$i]}.key"
			printf "%s\tUUID=$(lsblk -dno UUID "${ADDITIONAL_DRIVES[$i]}${ADDITIONAL_PARTITION[$i]}")\t%s\n" "${ADDITIONAL_ENCRYPTION_MAPPING[$i]}" "/root/${ADDITIONAL_ENCRYPTION_MAPPING[$i]}.key" | tee -a /mnt/etc/crypttab
		done

		sed -i "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard modconf block encrypt filesystems fsck)/" /mnt/etc/mkinitcpio.conf	

		KernelParameters[${#KernelParameters[@]}]="cryptdevice=UUID=$(lsblk -dno UUID ${ROOT_DRIVE}${ROOT_PARTITION}):root"
		KernelParameters[${#KernelParameters[@]}]="root=/dev/mapper/root"
		arch-chroot /mnt mkinitcpio -P
	fi

	echo "Enter the root password"
	arch-chroot /mnt passwd

	if [ "$IS_UEFI" = "true" ]; then
		arch-chroot /mnt bootctl --esp-path=/efi --boot-path=/boot install

		local ucode
		if [ "$CPU_TYPE" = "amd" ]; then
			ucode="amd-ucode.img"
		elif [ "$CPU_TYPE" = "intel" ]; then
			ucode="intel-ucode.img"
		fi

		if [ "$ENCRYPT" = "n" ]; then
			KernelParameters[${#KernelParameters[@]}]="root=UUID=$(lsblk -dno UUID ${ROOT_DRIVE}${ROOT_PARTITION})"
		fi
		KernelParameters[${#KernelParameters[@]}]="rw"

		# TODO: Possible issue, if a BOOT partition isn't specified, change /mnt/boot to /mnt/efi
		printf "title Arch Linux\nlinux /vmlinuz-linux\ninitrd /%s\ninitrd /initramfs-linux.img\noptions %s %s\n" "$ucode" "${KernelParameters[*]}" "${NonFallbackParameters[*]}" > /mnt/boot/loader/entries/arch.conf
		printf "title Arch Linux (Fallback Initramfs)\nlinux /vmlinuz-linux\ninitrd /%s\ninitrd /initramfs-linux-fallback.img\noptions %s\n" "$ucode" "${KernelParameters[*]}" > /mnt/boot/loader/entries/arch-fallback.conf
		printf "default arch.conf\ntimeout 4\nconsole-mode max\n" > /mnt/efi/loader/loader.conf
	else
		if [ "$BOOT_DRIVE" = "root" ]; then
			arch-chroot /mnt grub-install --target=i386-pc "$ROOT_DRIVE"
		else
			arch-chroot /mnt grub-install --target=i386-pc "$BOOT_DRIVE"
		fi

		sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"%GRUB_CMDLINE_LINUX_DEFAULT=\"${NonFallbackParameters[*]}\"%" /mnt/etc/default/grub
		sed -i "s%GRUB_CMDLINE_LINUX=\"\"%GRUB_CMDLINE_LINUX=\"${KernelParameters[*]}\"%" /mnt/etc/default/grub
		arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
	fi
}

validate_variables
pre_checks
partition_drives
os_installation

echo "Installation complete! Reboot your system into the freshly installed OS and run the 'archlinux-post_install.sh' script as root"
