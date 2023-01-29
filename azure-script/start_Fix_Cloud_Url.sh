#!/usr/bin/env bash

# This bash script is designed to collect the public IP address and
# change the config files for the azure marketplace image.
# Author: Ali Jawad FAHS, Activeeon

# Get the public IP address of the VM
PUBLIC_IP=`/opt/proactive/config/scheduler/Get_public_ip.sh`
src=$?
# assert the public IP address is retereived correctly
if [ "$src" -lt "6" ]
then
  # delete rest.public.url from the settings.ini file
  grep -v "pa.cloud-automation.rest.public.url=" /opt/proactive/config/scheduler/settings.ini > /tmp/tmpfile && mv /tmp/tmpfile /opt/proactive/config/scheduler/settings.ini
  grep -v "pa.catalog.rest.public.url=" /opt/proactive/config/scheduler/settings.ini > /tmp/tmpfile && mv /tmp/tmpfile /opt/proactive/config/scheduler/settings.ini

  grep -v "novnc.enabled=" /opt/proactive/config/web/settings.ini > /tmp/tmpfile && mv /tmp/tmpfile /opt/proactive/config/web/settings.ini
  grep -v "novnc.url=" /opt/proactive/config/web/settings.ini > /tmp/tmpfile && mv /tmp/tmpfile /opt/proactive/config/web/settings.ini

  grep -v "sched.novnc.url=" /opt/proactive/dist/war/scheduler/scheduler.conf > /tmp/tmpfile && mv /tmp/tmpfile /opt/proactive/dist/war/scheduler/scheduler.conf
  grep -v "sched.novnc.page.url=" /opt/proactive/dist/war/scheduler/scheduler.conf > /tmp/tmpfile && mv /tmp/tmpfile /opt/proactive/dist/war/scheduler/scheduler.conf

  # if the IP is correct then create a new rest url with the public IP for CA and Catalog
  echo "pa.cloud-automation.rest.public.url=http://$PUBLIC_IP/cloud-automation-service" >> /opt/proactive/config/scheduler/settings.ini
  echo "pa.catalog.rest.public.url=http://$PUBLIC_IP/catalog" >> /opt/proactive/config/scheduler/settings.ini
  # change the config files to enable vnc at port 5900
  echo "novnc.enabled=true" >> /opt/proactive/config/web/settings.ini
  echo "novnc.url=http://$PUBLIC_IP:5900/" >> /opt/proactive/config/web/settings.ini

  echo "sched.novnc.url=http\://$PUBLIC_IP\:5900" >> /opt/proactive/dist/war/scheduler/scheduler.conf
  echo "sched.novnc.page.url=http\://$PUBLIC_IP\:8443/rest/novnc.html" >> /opt/proactive/dist/war/scheduler/scheduler.conf

  echo "The Public IP address is $PUBLIC_IP retrived form server $src"
  exit 0
else
  echo "Could not reterive the Public IP address, error $? "
  exit 1
fi
