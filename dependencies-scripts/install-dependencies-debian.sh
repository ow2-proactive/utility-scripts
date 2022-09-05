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
  if [ "$Message" == "ERROR" ]; then cat $LOGFILE; fi
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


# Start the Configuration
log_print INFO "Configuration started!"
log_print INFO "Logs are saved at: $LOGFILE"


# Update the package list
log_print INFO "Updating the package list."
sudo apt-get update

# Check for lock
Check_lock

# Install curl
log_print INFO "Installing curl"
sudo apt-get install -y curl || { log_print ERROR "curl installation failed!"; exit $EXITCODE; }

# Install Docker
log_print INFO "Installing docker"
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl status docker
sudo systemctl start docker

sudo docker -v || { log_print ERROR "Docker installation failed!"; exit $EXITCODE; }


# Check if python3 is installed
log_print INFO "Installing python3"
python3 -V || { log_print WARN "python3 was installed => installing now!"; sudo apt install -y python3; INS = 1; }
if [ $INS -eq 1 ]; then python3 -V || { log_print ERROR "Unable to install python3!"; exit $EXITCODE; }; fi

# Set python3 as python
sudo apt install python-is-python3 && python -V || log_print WARN "Could not set python as python3";

if [ ! -z "$(diff <( python3 -V ) <( python -V))" ]; then log_print WARN "pyhton is not python3"; fi

#install pip3
log_print INFO "Installing pip3"
sudo apt install -y python3-pip 
pip3 -v || { log_print ERROR "Unable to install PIP3!"; exit $EXITCODE; }
if [ ! -z "$(diff <( pip3 -V ) <( pip -V))" ]; then log_print WARN "pip is not pip3"; fi

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

#list installed versions
log_print INFO "Listing installed versions"

log_print INFO "curl version: $(curl -V | head -n 1 | cut -d" " -f1-2)"
log_print INFO "docker version: $(docker -v)"
log_print INFO "docker version: $(docker -v | head -n 1 | cut -d" " -f1,3) | | sed 's/,//'"
log_print INFO "pip3 version: $(pip3 -V | head -n 1 | cut -d" " -f1-2)"
log_print INFO "py4j version: $(pip list --format freeze | grep py4j )"
log_print INFO "cryptography version: $(pip list --format freeze | grep cryptography )"
log_print INFO "requests version: $(pip list --format freeze | grep requests )"
log_print INFO "urllib3 version: $(pip list --format freeze | grep urllib3 )"
log_print INFO "wget version: $(pip list --format freeze | grep wget )"



# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "Configuration done successfully in $ELAPSED seconds "

