#!/bin/bash

#set -x

#INPUTS:
#Location of the default ProActive installation directoy
PROACTIVE_DEFAULT="/opt/proactive/default"
#Protocol to be used to access the ProActive server
PWS_PROTOCOL="https"
#Internal host address of the ProActive server
PWS_HOST_ADDRESS="internal.proactive.ip.or.dns"
#Port to be used to access the ProActive server
PWS_PORT="8443"
#ProActive authentication user
PWS_LOGIN_USER="admin"
#ProActive authentication user password
PWS_LOGIN_USER_PASSWORD="changeme"
#Hosts file describing the target Node machines and the number of Nodes
#e.g., target.node.dns.or.ip 4
HOST_FILE="/tmp/hosts.txt"
#SSH user to connect to the remote Node machine
SSH_NODE_USER="changeme"
#SSH user passowrd to connect to the remote Node machine
SSH_NODE_PASSWORD="changeme"

#COMMAND TO CREATE SSH NODES
${PROACTIVE_DEFAULT}/bin/proactive-client -k -u ${PWS_PROTOCOL}://${PWS_HOST_ADDRESS}:${PWS_PORT}/rest/ -l ${PWS_LOGIN_USER} -p ${PWS_LOGIN_USER_PASSWORD} --createns CLI-SSH-Nodes -infrastructure org.ow2.proactive.resourcemanager.nodesource.infrastructure.SSHInfrastructureV2 ${HOST_FILE} 60000 5 5000 22 ''${SSH_NODE_USER}'' ''${SSH_NODE_PASSWORD}'' '' '' '' '' 'Linux' '-Dproactive.net.nolocal=true -Dproactive.communication.protocol=pamr -Dproactive.useIPaddress=true  -Dproactive.pamr.router.address='${PWS_HOST_ADDRESS}'' 'useNodeJarStartupScript' ''${PWS_PROTOCOL}'://'${PWS_HOST_ADDRESS}':'${PWS_PORT}'/rest/node.jar' '' 'rm -rf /tmp/node && mkdir -p /tmp/node && cd /tmp/node; if ! type -p jre/bin/java; then wget -nv -N https://s3.amazonaws.com/ci-materials/Latest_jre/jre-8u312b07-linux-x64.tar.gz; tar -xf jre-8u312b07-linux-x64.tar.gz; mv jre1.8.0_312b07/ jre; fi; wget --no-check-certificate -nv -O node.jar %nodeJarUrl%; rm -rf lib; %detachedModePrefix% jre/bin/java -jar node.jar %javaOptions% -Dpython.path=%jythonPath% -r %rmUrl% -n %nodeName% -s %nodeSourceName% -w %numberOfNodesPerInstance% -v %credentials% &' -policy org.ow2.proactive.resourcemanager.nodesource.policy.RestartDownNodesPolicy 'ALL' 'ME' '1800000' -X