#!/bin/sh

DRIVE=$1
PARTITION_TYPE=$2       
DESCRIPTION=$3

# Use this for MBR
#echo -e "$DESCRIPTION" | sfdisk -X "$PARTITION_TYPE" "$DRIVE"

# This for GPT
sgdisk -Zog "$DRIVE"
echo $?
sgdisk -n 0:0:1G -c 0:"EFI System Partition" -t 0:C12A7328-F81F-11D2-BA4B-00A0C93EC93B "$DRIVE"
sgdisk -n 0:0:8G -c 0:"Swap Partition" -t 0:0657FD6D-A4AB-43C4-84E5-0933C84B4F4F "$DRIVE"
sgdisk -n 0:0:0 -c 0:"Root Partition" -t 0:4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709 "$DRIVE"

sgdisk -p "$DRIVE"
