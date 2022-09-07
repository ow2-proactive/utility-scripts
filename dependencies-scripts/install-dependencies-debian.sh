#!/bin/bash

# This bash script is designed to install PWS & PAIO dependencies for Debian distros.
# If an error occur, the script will exit with the value of the PID to point at the logfile.
# Author: Ali Jawad FAHS, Activeeon


# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
EXITCODE=$PID
DATE=$(date)
LOGFILE="/var/log/install-dependencies.$PID.log"


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
  echo "$level [$(date)]: $Message"
  echo "$level [$(date)]: $Message" >&3
  if [ "$level" == "ERROR" ]; then newline FAILED; echo "Printing the full logs:" >&3; cat $LOGFILE >&3; fi
  }

# A function to print new line with title
newline(){
	Message=$1
	n=${#Message}
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

# A function to check for the apt lock
Check_lock() {
i=0
log_print INFO "Checking for apt lock"
while [ `ps aux | grep [l]ock_is_held | wc -l` != 0 ]; do
    echo "Lock_is_held $i"
    ps aux | grep [l]ock_is_held
    sleep 10
    ((i=i+10));
done
log_print INFO "Exited the while loop, time spent: $i"
echo "ps aux | grep apt"
ps aux | grep apt
log_print INFO "Waiting for lock task ended properly."
}

newline "STARTED"
# Start the Configuration
log_print INFO "Configuration started!"
log_print INFO "Logs are saved at: $LOGFILE"


# Update the package list
log_print INFO "Updating the package list."
sudo apt-get update

# Check for lock
Check_lock

newline "USEFUL PACKAGES"

# Install curl
log_print INFO "Installing curl"
sudo apt-get install -y curl || log_print WARN "curl installation failed!"

# Install net-tools
log_print INFO "Installing net-tools"
sudo apt-get install -y net-tools || log_print WARN "net-tools installation failed!"

# Install x11vnc
log_print INFO "Installing x11vnc"
sudo apt-get install -y x11vnc || log_print WARN "x11vnc installation failed!"


newline "DOCKER"
# Install Docker
log_print INFO "Installing docker"
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl status docker
sudo systemctl start docker

sudo docker -v || { log_print ERROR "Docker installation failed!"; exit $EXITCODE; }


newline "PYTHON"
# Check if python3 is installed
log_print INFO "Installing python3"
INS=0
python3 -V || { log_print WARN "python3 was not installed => installing now!"; sudo apt-get install -y python3; INS=1; }
if [ $INS -eq 1 ]; then python3 -V || { log_print ERROR "Unable to install python3!"; exit $EXITCODE; }; fi

# Set python3 as python
sudo apt-get install -y python-is-python3 && python -V || log_print WARN "Could not set python as python3";

if [ ! -z "$(diff <( python3 -V ) <( python -V))" ]; then log_print WARN "pyhton is not python3"; else log_print INFO "python is python3";fi

#install pip3
log_print INFO "Installing pip3"
sudo apt-get install -y python3-pip
pip3 -V || { log_print ERROR "Unable to install pip3!"; exit $EXITCODE; }
if [ ! -z "$(diff <( pip3 -V ) <( pip -V))" ]; then log_print WARN "pip is not pip3"; else log_print INFO "pip is pip3";fi


newline "PIP PACKAGES"
# install py4j
log_print INFO "Installing py4j"
pip3 install py4j || { log_print ERROR "py4j installation failed!"; exit $EXITCODE; }

# install cryptography
log_print INFO "Installing cryptography"
pip3 install cryptography || { log_print ERROR "cryptography installation failed!"; exit $EXITCODE; }

# install requests
log_print INFO "Installing requests"
pip3 install requests || { log_print ERROR "requests installation failed!"; exit $EXITCODE; }

# install urllib3
log_print INFO "Installing urllib3"
pip3 install urllib3 || { log_print ERROR "urllib3 installation failed!"; exit $EXITCODE; }

# install wget
log_print INFO "Installing wget"
pip3 install wget || { log_print ERROR "wget installation failed!"; exit $EXITCODE; }


newline "VERSIONS"
#list installed versions
log_print INFO "Listing installed versions"

log_print INFO "curl version: $(curl -V | head -n 1 | cut -d" " -f2)"
log_print INFO "net-tools version: $(apt list 2>&1 | grep "net-tools" | grep -v -e "ddnet" | cut -d " " -f 2)"
log_print INFO "x11vnc version: $(apt list 2>&1 | grep  x11vnc | cut -d" " -f2)"
log_print INFO "docker version: $(docker -v | head -n 1 | cut -d" " -f3 | sed 's/,//') "
log_print INFO "python3 version: $(python3 -V | cut -d " " -f 2)"
log_print INFO "pip3 version: $(pip3 -V | head -n 1 | cut -d" " -f 2)"
log_print INFO "py4j version: $(pip3 list --format freeze | grep py4j | cut -d "=" -f3)"
log_print INFO "cryptography version: $(pip3 list --format freeze | grep cryptography | cut -d "=" -f3)"
log_print INFO "requests version: $(pip3 list --format freeze | grep requests | head -n 1 | cut -d "=" -f3)"
log_print INFO "urllib3 version: $(pip3 list --format freeze | grep urllib3 | cut -d "=" -f3)"
log_print INFO "wget version: $(pip3 list --format freeze | grep wget | cut -d "=" -f3)"


newline "FINISHED"
# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "Configuration done successfully in $ELAPSED seconds "

