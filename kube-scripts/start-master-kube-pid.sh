#!/bin/bash

# This bash script is designed to prepare and install docker and Kubernetes for Ubuntu 18.04.
# The stpes were taken from https://phoenixnap.com/kb/install-kubernetes-on-ubuntu with modifications done once necessary.
# If an error occur, the script will exit with the value of the PID to point at the logfile.
# Author: Ali Jawad FAHS, Activeeon


# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
EXITCODE=$PID
DATE=$(date)
LOGFILE="/var/log/kube-start-master.$PID.log"


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
  }


# Start the Configuration
log_print INFO "Starting the master script is loaded!"
log_print INFO "Logs are saved at: $LOGFILE"



log_print INFO "Starting the cluster"
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

log_print INFO "Checking the user"
echo "HOME: $(pwd), USER: $(id -u -n)"

log_print INFO "Setting the kubeconfig file"
mkdir -p ~/.kube && sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config && sudo chown $(id -u):$(id -g) ~/.kube/config
id -u ubuntu &> /dev/null

if [[ $? -eq 0 ]]
then
#USER ubuntu is found
mkdir -p /home/ubuntu/.kube && sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config && sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config
else
# to be changed soon 
log_print ERROR "USER ubuntu is not found"
fi

log_print INFO "Setting  flannel"
sudo kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

log_print INFO "Getting the token for the cluster"
kubeadm token create $(kubeadm token generate) --print-join-command --ttl=1h >  /tmp/join_call.txt


log_print INFO "Publishing the token"
# TO BE ADDED
echo "to be added"

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "Configuration done successfully in $ELAPSED seconds "

