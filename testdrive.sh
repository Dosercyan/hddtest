#!/bin/bash
# Author: Carl Martin <cmartin@nexcess.net>
# Tests a drive with badblocks and creates a log of it. Sends summary email on completion.
# Usage:
#    testdrive.sh sdf email@address.com


thedate=$(date +%Y-%m-%d-%H%M)
log_file=logs/badblocks-$1-$thedate.log

echo "Testing drive /dev/$1" | tee $log_file   # no -a here, to create a new file
echo "Starting at $(date +%Y-%m-%d-%H:%M:%S)" | tee -a $log_file

#serialnum=$(hdparm -I /dev/$1 | grep "Serial Number" | awk '{print $3}')
# Retrieve serial number - compatible with both SAS and SATA
serialnum=$(sdparm --page=SN /dev/$1  | tail -1 | awk '{print $1}')



# Determine SATA or SAS for other variables
is_ata=$(sdparm /dev/$1 | awk '{print $2}' | head -1)
echo "is_ata: $is_ata"
if [ $is_ata = "ATA" ]
then
    echo "Drive is SATA" | tee -a $log_file
    manuf=$(hdparm -I /dev/$1 | grep "Model Number" | awk '{print $3}')
    modelnum=$(hdparm -I /dev/$1 | grep "Model Number" | awk '{print $4}')
else
    echo "Drive is SAS" | tee -a $log_file
    manuf=$(sdparm /dev/$1 | awk '{print $2}' | head -1)
    modelnum=$is_ata
fi



echo "Manufacturer: $manuf" | tee -a $log_file
echo "Model: $modelnum" | tee -a $log_file
echo "Serial: $serialnum" | tee -a $log_file


devsize=$(fdisk -l /dev/$1 2>/dev/null | head -2 | tail -1 | awk '{print $3,$4}' | sed s/,//)

#devsize=$(hdparm -I /dev/$1 | grep "device size with M = 1000" | awk '{print $9}' | cut -c2-)
echo "Size: $devsize" | tee -a $log_file


#run the test
bbcount=$(badblocks -swft random /dev/$1 | tee -a $log_file | wc -l)

#check smart after the test
smartline=$(smartctl -a /dev/$1 | egrep -o "FAILURE PREDICTION THRESHOLD EXCEEDED")

echo "$bbcount bad block(s) found. $smartline" | tee -a $log_file # echo to screen and log
echo "$bbcount bad block(s) found. $smartline" |  mail -s "/dev/$1: test complete. $serialnum" $2  # echo to email
echo "Finished at $(date +%Y-%m-%d-%H:%M:%S)." | tee -a $log_file;

#unable to ctrl-c the loop, just the individual dd
#if [ $bbcount -gt 0 ];
#then
	#Speed changes in drive don't matter, as the 'off' time is still constant
#	echo "Blinking 1 second on, 5 seconds off to indicate BAD BLOCKS"
#	while (true); do dd if=/dev/$1 of=/dev/null count=100K 2> /dev/null; sleep 5; done;

#else
#	echo "Blinking 1 second on, 1 second off to indicate NO BAD BLOCKS"
#	while (true); do dd if=/dev/$1 of=/dev/null count=100K 2> /dev/null; sleep 1; done;
#fi

