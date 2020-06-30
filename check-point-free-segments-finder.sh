#!/bin/bash

# ================================
# check-point-free-segments-finder
# ================================
#
# This script will scan your network interfaces and look for an allocatable free spaces inside your class-c segments for smaller subnetting.
# Check Point system administrators which uses smaller-than-class-c subnets may find this script useful.
#
# Tested on Check Point GAiA R80.10-R80.30
# -----------------------------
# Written by Elad Ben-Matityahu
# -----------------------------

function handleSubnet {
	cidr=$(getCIDR $2)
	network_range=$(getNetworkRange $2)
	segment_prefix=$(echo $1 | awk -F"." '{print $1 "." $2 "." $3 "."}')
	last_octet=$(echo $1 | awk -F"." '{print $4}')
	network_address=$(getNetworkAddress $last_octet $network_range)
	broadcast_address=$(($network_address + $network_range - 1))
	network=$(echo "${segment_prefix}${network_address}/$cidr")
}

function getCIDR {
	if [[ "$1" == "255.255.255.255" ]]; then
		echo 32
	elif [ "$1" == "255.255.255.254" ]; then
		echo 31
	elif [ "$1" == "255.255.255.252" ]; then
		echo 30
	elif [ "$1" == "255.255.255.248" ]; then
		echo 29
	elif [ "$1" == "255.255.255.240" ]; then
		echo 28
	elif [ "$1" == "255.255.255.224" ]; then
		echo 27
	elif [ "$1" == "255.255.255.192" ]; then
		echo 26
	elif [ "$1" == "255.255.255.128" ]; then
		echo 25
	elif [ "$1" == "255.255.255.0" ]; then
		echo 24
	else
		echo 0
	fi
}

function getNetworkRange {
	if [[ "$1" == "255.255.255.255" ]]; then
		echo 1
	elif [ "$1" == "255.255.255.254" ]; then
		echo 2
	elif [ "$1" == "255.255.255.252" ]; then
		echo 4
	elif [ "$1" == "255.255.255.248" ]; then
		echo 8
	elif [ "$1" == "255.255.255.240" ]; then
		echo 16
	elif [ "$1" == "255.255.255.224" ]; then
		echo 32
	elif [ "$1" == "255.255.255.192" ]; then
		echo 64
	elif [ "$1" == "255.255.255.128" ]; then
		echo 128
	elif [ "$1" == "255.255.255.0" ]; then
		echo 256
	else
		echo 0
	fi
}

function getNetworkAddress {
	curr_network=256
	while [ $curr_network -ge 0 ]; do
		if [ $curr_network -le $1 ]; then
			echo "$curr_network"
			return 0
		fi
		curr_network=$(($curr_network - $2))
	done
}

function handleNetworkPrefix {
	ifconfig | grep $1 | grep "inet addr" | awk -F":" '{print $2, $4}' | sed s/Bcast/,/g | sed s/\ //g | grep -v 127.0.0.1| while read line ; do
		IFS=',' read -r -a nic <<< "$line"
		ip_address="${nic[0]}"
		subnet_mask="${nic[1]}"
		handleSubnet $ip_address $subnet_mask
		#echo "net: $network"
		for i in $(seq $network_address $broadcast_address); do touch "/tmp/elad_$1$i";  done
	done
	
	free_range=0
	range_start=0
	range_end=0
	i=0
	while [ $i -le 255 ]; do
		if [ -f "/tmp/elad_$1$i" ]; then
			if [ $free_range == 1 ]; then
				free_range=0
				range_end=$(($i-1))
				echo "free range found: $1${range_start}-${range_end}"
			fi
		else
			if [ $free_range == 0 ]; then
				free_range=1
				range_start=$i
			elif [ $free_range == 1 ] && [ $i == 255 ]; then
				free_range=0
				range_end=255
				echo "free range found: $1${range_start}-${range_end}"
			fi
			
		fi
		i=$(($i + 1))
	done
}

function listSubnets {
	ifconfig | grep "inet addr" | awk -F":" '{print $2, $4}' | sed s/Bcast/,/g | sed s/\ //g | grep -v 127.0.0.1| while read line ; do
		IFS=',' read -r -a nic <<< "$line"
		ip_address="${nic[0]}"
		echo $ip_address | awk -F"." '{print $1 "." $2 "." $3 "."}'
	done
}

function startScanning {
	rm /tmp/elad_* 2> /dev/null
	listSubnets | sort -u | while read prefix ; do
		handleNetworkPrefix $prefix
	done
	rm /tmp/elad_* 2> /dev/null
}

startScanning


