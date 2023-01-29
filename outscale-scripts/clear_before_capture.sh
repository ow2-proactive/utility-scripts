#!/bin/bash

# This bash script is designed to clean a virtual machine personal files before capturing an OutScale Image.
# It was created based on this documentation: https://docs.outscale.com/en/userguide/Linux-Instances-Clean-up-to-Create-OMIs.html
# If an error occur, the script will exit with the value of the PID to point at the logfile.
# If the error code is 1000 then the code is not ran by the root user.
# after the script is executed successfully please delete the log file
# Authors: Ali Jawad FAHS, Activeeon

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
EXITCODE=$PID
DATE=$(date)
LOGFILE="/var/log/clear-instance.$PID.log"


if [ "$EUID" -ne 0 ]; then
	echo "Please run as root"
	exit 1000;
fi

# Set up the logging for the script
sudo touch $LOGFILE
sudo chown $USER:$USER $LOGFILE

# All the output of this shell script is redirected to the LOGFILE
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>$LOGFILE 2>&1

# A function to print a message to the stdout as well as as the LOGFILE
log_print(){
  level=$1
  Message=$2
  echo -e "$level [$(date)]: $Message"
  echo -e "$level [$(date)]: $Message" >&3
  if [ "$level" == "ERROR" ]; then
  newline "FAILED"
  echo -e "Printing the last 50 logs:" >&3
  tail -n 20 $LOGFILE >&3
  echo -e "the full logs here: $LOGFILE";
  fi
  }

# A function to print new line with title
newline(){
  Message=$1
  n=${#Message}
  if [ -z "$COLUMNS" ]; then COLUMNS=100; fi
  DL=$COLUMNS
  num=$(expr $DL - $n - 4)
  reminder=$(expr $num % 2)
  num=$(expr $num / 2)
  num1=$(expr $num + $reminder)

  echo ""
  printf %"$num1"s |tr " " "#"
  echo -n "  $Message  "
  printf %"$num"s |tr " " "#"
  echo ""
  echo "" >&3
  printf %"$num1"s |tr " " "#" >&3
  echo -n "  $Message  " >&3
  printf %"$num"s |tr " " "#" >&3
  echo "" >&3
  }

####### Preparation


newline "STARTED"
log_print INFO "Cleaing the instance started!"
log_print INFO "Logs are saved at: $LOGFILE"

log_print INFO "Stopping rsyslog"
service rsyslog stop

log INFO "Clear tmp dirs"
/bin/rm -Rf /tmp/*
/bin/rm -Rf /var/tmp/*

log_print INFO "Clear Network config"
/bin/rm -f /etc/sysconfig/network-scripts/{ifcfg,route}-eth[1-9]

log_print INFO "Clear DHCP configs"
/bin/rm -f /var/lib/dhclient/dhclient*.lease
sed -i '/dhclient-script/d' /etc/ntp.conf

log_print INFO "Clear osc"
/bin/rm -f /var/osc/*

log_print INFO "clear authorized_keys"
/bin/rm -f ~/.ssh/authorized_keys
/bin/rm -f /home/outscale/.ssh/authorized_keys

log_print INFO "Clear Vim info"
/bin/rm -f ~/.viminfo
/bin/rm -f /home/outscale/.viminfo
/bin/rm -f /home/User_Name/.viminfo

log_print INFO "Clear history"
/bin/rm -f ~/.bash_history
/bin/rm -f /home/outscale/.bash_history
history -c


log_print INFO "Instance cleared, please execute the following commands before capturing the images: \n \"/bin/rm $LOGFILE\" \n \" history -c\" (from all the users you used)"

newline "FINISHED"
# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "Configuration done successfully in $ELAPSED seconds "