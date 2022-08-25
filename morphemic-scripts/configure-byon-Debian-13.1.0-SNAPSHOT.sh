#!/bin/bash

# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
DATE=$(date)
LOGFILE="/var/log/byonlog.$PID.log"
DIR="/home/byon-workspace"
AGENTURL="https://proactive-node-agent.s3.eu-west-3.amazonaws.com/activeeon_enterprise-node-linux-x64-13.1.0-SNAPSHOT.zip"
AGENTFILE="activeeon_enterprise-node-linux-x64-13.1.0-SNAPSHOT.zip"
AGENTDIR="/opt"
AGENTDIRNAME="ProActive_node_agent"

# Set up the logging for the script
sudo touch $LOGFILE
sudo chown $USER:$USER $LOGFILE

exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>$LOGFILE 2>&1

log_print(){
  level=$1
  Message=$2
  echo "$level [$(date)]: $Message"
  echo "$level [$(date)]: $Message" >&3
  }

# Start the Configuration

log_print INFO "Configuration started!"
log_print INFO "Logs are saved at: $LOGFILE"

# Update the package list

log_print INFO "Updating the package list."
sudo apt-get update

# Install unzip package

log_print INFO "Installing the unzip package"
sudo apt-get install -y unzip 

# Create a workspace directory

log_print INFO "Create a workspace directory."

if [ -e ${DIR} ]; then
	log_print WARN "The Dir $DIR exists, to be deleted and recreated."
	sudo rm -r $DIR
else 
	log_print INFO "The Dir $DIR does not exist, to be created."
fi
sudo mkdir $DIR
sudo chown $USER:$USER $DIR

# Download the node agent

log_print INFO "Downloading the node agent"
wget $AGENTURL -P $DIR  -nv

# Unzip the agent

log_print INFO "Unzipping the agent $AGENTFILE started!"
unzip -q $DIR/${AGENTFILE}.zip -d $DIR

# Renaming the Agent 

log_print INFO "Renaming the Agent DIR to $AGENTDIRNAME"
mv $DIR/$AGENTFILE $DIR/$AGENTDIRNAME

# Moving the agent

if [ -e ${AGENTDIR}/${AGENTDIRNAME} ]; then
        log_print WARN "The Dir ${AGENTDIR}/${AGENTDIRNAME} exists, to be deleted and replaced."
        sudo rm -r ${AGENTDIR}/${AGENTDIRNAME}
else
        log_print INFO "The Dir ${AGENTDIR}/${AGENTDIRNAME} does not exist, agent to be moved to ${AGENTDIR}."
fi

sudo mv $DIR/$AGENTDIRNAME $AGENTDIR/
log_print INFO "Moving the Agent To DIR: $AGENTDIR"

# Change owner of the agent dir to the current user

log_print INFO "Changing the ownership of ${AGENTDIR}/${AGENTDIRNAME} to $USER"
sudo chown -R $USER:$USER ${AGENTDIR}/${AGENTDIRNAME}

# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "Configuration done successfully in $ELAPSED seconds"

