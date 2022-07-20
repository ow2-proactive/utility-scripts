#!/bin/bash

# delete all logs files

rm -r /var/log/byonlog*log

# delete the workspace

rm -r /home/byon-workspace

#purge the unzip package 

apt-get purge -y unzip

# delete the /opt agent dir

sudo rm -r /opt/ProActive_node_agent
