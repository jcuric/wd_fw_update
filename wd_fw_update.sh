#!/bin/bash

wdhost="https://wddashboarddownloads.wdc.com"
wddevices="/wdDashboard/config/devices/lista_devices.xml"


Help()
{
   echo "Firmware update for WD NVME SDDs"
   echo
   echo "Syntax: $0 [-d|h|v"
   echo "options:"
   echo "-d     device to upgrade (nvme0)"
   echo "-h     Print this Help."
   echo "-v     Verbose mode."
   echo
}

while getopts "hd:" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      d) # Enter a name
         device=$OPTARG;;
     *) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

if [ -z "$device" ]; then
        echo "Missing device" >&2
	Help
        exit 1
fi

model=$(cat /sys/class/nvme/$device/model)
fw=$(cat /sys/class/nvme/$device/firmware_rev)

#model='WD_BLACK SN850X HS 2000GB'
#fw="620241WD"

echo "Device $device model \"$model\" firmware version \"$fw\""

if [ -z "$model" ] || [ -z "$fw" ]; then
	echo "No NVME device $device" >&2
	Help
	exit 2
fi
tmp=$(curl -s $wdhost$wddevices)
deviceurl=$(echo $tmp | xmllint --xpath "/lista_devices/lista_device[@model='$model']/url/text()" - 2>/dev/null)

if [ -z $deviceurl ]; then
	echo "Model \"$model\" not found in $wdhost$wddevices"
	exit 3
fi

devicexml=$(curl -s $wdhost/$deviceurl)
if [ -z "$devicexml" ]; then
        echo "File not found $wdhost/$deviceurl"
        exit 4
fi

fwversion=$(echo $devicexml | xmllint --xpath '/ffu/fwversion/text()' - 2>/dev/null)
fwfile=$(echo $devicexml | xmllint --xpath '/ffu/fwfile/text()' - 2>/dev/null)
depends=$(echo $devicexml | xmllint --xpath '/ffu/dependency/text()' - 2>/dev/null)

if [ -z "$fwversion" ] || [ -z "$fwfile" ] || [ -z "$depends" ]; then
	echo "Params not found in $devicexml"
	exit 5
fi

echo Lastest firmware: $fwversion
echo Lastest firmware file: $fwfile
echo Lastest firmware dependancies: $depends
if [[ "${depends[@]}" =~ "${fw}" ]]; then
	fwurl=$wdhost/${deviceurl%/*}/$fwfile
	echo "Downloading firmware file $fwfile from $fwurl"
	curl -s $fwurl -o $fwfile
	if [ -f "$fwfile" ]; then
		echo "Download firmware to drive: nvme fw-download -f 620331WD.fluf /dev/$device"
		echo "Commit firmware and restart drive: nvme fw-commit -s 2 -a 3 /dev/$device"
                echo "Commit firmware and DO NOT restart drive: nvme fw-commit -s 2 -a 2 /dev/$device"
		echo "Check Firmware update log: nvme fw-log /dev/$device"	
	else
		echo "Could not download $fwurl"
		exit 6
	fi
else
       	echo "Dependancy for Model \"$model\", version \"$fw\" not satisfied ";
	echo "Firmware update dependany list:"
        echo "$depends"
	exit 7
fi
