#!/bin/bash
# Run this script directly in the boot medium with an internet connection
# Make sure the drives that are going to be partitioned are empty
# Run the 'archlinux-post_install.sh' script once this is done in the freshly installed system

# TODO:
#	Encryption
#	Fix UEFI
#	Secure Boot
#	New bootloader?
#	Support Wi-Fi - Not urgent
#	Mount /boot when pacman updates
#	Test unmounted /boot with UEFI

# TODO Easy:
#	Improving performance page - https://wiki.archlinux.org/title/Improving_performance
#	Security page - https://wiki.archlinux.org/title/Security
#	Sudo permissions in post-install
#	Pipewire
#	nowatchdog
#	Multilib 32bit support
#	Pacman colors

readonly HOSTNAME="retro"
readonly TIMEZONE_REGION="America"
readonly TIMEZONE_CITY="New_York"
readonly CPU_TYPE="amd"
readonly ENCRYPT="y"
readonly DEBUG="y"
readonly GPU="other"

# Boot, Root, Swap, EFI, Additonal Drives
readonly SWAP_DRIVE="/dev/sdb"
readonly SWAP_TYPE="drive" # Can be one of the following: (drive or none)
readonly SWAP_SIZE=("1MiB" "1GiB")
readonly SWAP_LABEL="Swap"
readonly SWAP_PARTITION="1"

# Drive, Size, Name, Partition
readonly ROOT_DRIVE="/dev/sda"
readonly ROOT_SIZE=("1GiB" "8GiB")
readonly ROOT_LABEL="Root"
readonly ROOT_PARTITION="2"

# Drive or root (Included in root), Size, Name
readonly BOOT_DRIVE="/dev/sda"
readonly BOOT_SIZE=("1MiB" "1GiB")
readonly BOOT_LABEL="Boot"
readonly BOOT_PARTITION="1"

# Drive, Size, Name, Partition
readonly ADDITIONAL_DRIVES=("/dev/sda" "/dev/sdb")
readonly ADDITIONAL_SIZE1=("8GiB" "1GiB")
readonly ADDITIONAL_SIZE2=("100%" "100%")
readonly ADDITIONAL_LABEL=("TestDrive" "OtherDrive")
readonly ADDITIONAL_PARTITION=("3" "2")
readonly ADDITIONAL_MOUNTPOINT=("/mnt/root/test" "/mnt/home/alex")

PackagesNeeded=(base linux linux-firmware iptables-nft sudo pacman-contrib vim ufw grub python python2 man-db man-pages texinfo git polkit dhcpcd htop)

function validate_variables() {
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

	if [[ "$GPU" != "nvidia" && "$GPU" != "other" ]]; then
		echo "'GPU' variable must be 'nvidia' or 'other'"
		exit 2
	fi
}

function partition_drives() {
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
					echo "working?"
					parted -s "$drive" mkpart "$SWAP_NAME" linux-swap "${SWAP_SIZE[0]}" "${SWAP_SIZE[1]}"
					echo "maybe?"
				else
					parted -s "$drive" mkpart primary linux-swap "${SWAP_SIZE[0]}" "${SWAP_SIZE[1]}"
				fi

				mkswap -L "$SWAP_LABEL" "${SWAP_DRIVE}${SWAP_PARTITION}"
				swapon "${SWAP_DRIVE}${SWAP_PARTITION}"

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
					mount /dev/mapper/root /mnt
				else
					mkfs.ext4 -L "$ROOT_LABEL" "${ROOT_DRIVE}${ROOT_PARTITION}"
					mount "${ROOT_DRIVE}${ROOT_PARTITION}" /mnt
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
						parted -s "$drive" mkpart "${ADDITIONAL_LABEL[$i]}" ext4 "${ADDITIONAL_SIZE1[$i]}" "${ADDITIONAL_SIZE2[$i]}"
					else
						parted -s "$drive" mkpart primary ext4 "${ADDITIONAL_SIZE1[$i]}" "${ADDITIONAL_SIZE2[$i]}"
					fi

					# TODO: Change the encrypted name mapping
					if [ "$ENCRYPT" = "y" ]; then
						cryptsetup -y -v luksFormat "${ADDITIONAL_DRIVES[$i]}${ADDITIONAL_PARTITION[$i]}"
						cryptsetup open "${ADDITIONAL_DRIVES[$i]}${ADDITIONAL_PARTITION[$i]}" root
						mkfs.ext4 -L "${ADDITIONAL_LABEL[$i]}" /dev/mapper/root
						mkdir -p "${ADDITIONAL_MOUNTPOINT[$i]}"
						mount /dev/mapper/root "${ADDITIONAL_MOUNTPOINT[$i]}"
					else # TODO: Fix this bug
						mkfs.ext4 -L "${ADDITIONAL_LABEL[$i]}" "${ADDITIONAL_DRIVES[$i]}${ADDITIONAL_PARTITION[$i]}"
						echo "${ADDITIONAL_MOUNTPOINT[$i]}"
						mkdir -p "${ADDITIONAL_MOUNTPOINT[$i]}"
						echo "${ADDITIONAL_DRIVES[$i]}${ADDITIONAL_PARTITION[$i]}"
						mount "${ADDITIONAL_DRIVES[$i]}${ADDITIONAL_PARTITION[$i]}" "${ADDITIONAL_MOUNTPOINT[$i]}"
					fi

					currentPartition=$((currentPartition + 1))
				fi
			done

			if [[ "$IS_UEFI" = "true" && "$EFI_DRIVE" = "$drive" && "$EFI_PARTITION" -eq $currentPartition ]]; then
				parted -s "$drive" mkpart "$EFI_NAME" fat32 "${EFI_SIZE[0]}" "${EFI_SIZE[1]}"
				parted -s "$drive" set "$EFI_PARTITION" esp on

				mkfs.fat -F 32 -n "$EFI_LABEL" "${EFI_DRIVE}${EFI_PARTITION}"
				mkdir -p /mnt/efi
				mount "${EFI_DRIVE}${EFI_PARTITION}" /mnt/efi

				currentPartition=$((currentPartition + 1))
			fi

			if [[ "$BOOT_DRIVE" = "$drive" && "$BOOT_PARTITION" -eq "$currentPartition" ]]; then
				if [ "$IS_UEFI" = "true" ]; then
					parted -s "$drive" mkpart "$BOOT_NAME" ext4 "${BOOT_SIZE[0]}" "${BOOT_SIZE[1]}"
					parted -s "$drive" set "$BOOT_PARTITION" bls_boot on
				else
					parted -s "$drive" mkpart primary ext4 "${BOOT_SIZE[0]}" "${BOOT_SIZE[1]}"
					parted -s "$drive" set "$BOOT_PARTITION" boot on
				fi

				mkfs.ext4 -L "$BOOT_LABEL" "${BOOT_DRIVE}${BOOT_PARTITION}"

				currentPartition=$((currentPartition + 1))
			fi
		done
	done
}

function pre_checks() {
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
	fi

	if [ "$ENCRYPT" = "y" ]; then
		modprobe dm_crypt
	fi

	timedatectl set-ntp true
}

function os_installation() {
	if [ "$BOOT_DRIVE" != "root" ]; then
		mkdir -p /mnt/boot
		mount "${BOOT_DRIVE}${BOOT_PARTITION}" /mnt/boot
	fi

	pacstrap /mnt "${PackagesNeeded[@]}" > archlinux-install_pacstrap.log 2>&1
	umount /mnt/boot
	genfstab -U /mnt >> /mnt/etc/fstab
	if [ "$BOOT_DRIVE" != "root" ]; then
		mkdir -p /mnt/boot
		mount "${BOOT_DRIVE}${BOOT_PARTITION}" /mnt/boot
	fi
	
	arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE_REGION/$TIMEZONE_CITY /etc/localtime
	arch-chroot /mnt hwclock --systohc

	sed -i "s/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/" /mnt/etc/locale.gen
	arch-chroot /mnt locale-gen
	echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf

	echo "$HOSTNAME" > /mnt/etc/hostname
	printf '127.0.0.1\tlocalhost\n::1\tlocalhost\n127.0.1.1\t%s\n' "$HOSTNAME" > /mnt/etc/hosts

	# TODO: Make sure this is correct
	if [ "$GPU" = "nvidia" ]; then
		sed -i "s/MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/" /mnt/etc/mkinitcpio.conf
		sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"%GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet nvidia-drm.modeset=1\"%"
		printf "[Trigger]\nOperation=Install\nOperation=Upgrade\nOperation=Remove\nType=Package\nTarget=nvidia\nTarget=linux\n# Change the linux part above and in the Exec line if a different kernel is used\n\n[Action]\nDescription=Update Nvidia module in initcpio\nDepends=mkinitcpio\nWhen=PostTransaction\nNeedsTargets\nExec=/bin/sh -c 'while read -r trg; do case \$trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'\n" > /mnt/etc/pacman.d/hooks/nvidia.hook
	fi

	# TODO: Correct this
	if [ "$ENCRYPT" = "y" ]; then
		sed -i "s%GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet\"%GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet cryptdevice=UUID=$(lsblk -dno UUID ${ROOT_DRIVE}${ROOT_PARTITION}):root root=/dev/mapper/root\"%" /mnt/etc/default/grub
		sed -i "s/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect keyboard modconf block encrypt filesystems keyboard fsck)/" /mnt/etc/mkinitcpio.conf	
		arch-chroot /mnt mkinitcpio -P
	fi

	echo "Enter the root password"
	arch-chroot /mnt passwd

	if [ "$IS_UEFI" = "true" ]; then
		arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
	else
		if [ "$BOOT_DRIVE" = "root" ]; then
			arch-chroot /mnt grub-install --target=i386-pc "$ROOT_DRIVE"
		else
			arch-chroot /mnt grub-install --target=i386-pc "$BOOT_DRIVE"
		fi
	fi

	arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}

validate_variables
pre_checks
partition_drives
os_installation

echo "Installation complete! Reboot your system into the freshly installed OS and run the 'archlinux-post_install.sh' script as root"
