#!/bin/bash
#set -x
#set -e

echo "[INSTALLATION-SCRIPT] Setting up the OS and Linux package system to be considered..."
OS=
PKG_TOOL=
if which dnf >/dev/null 2>&1; then
  OS="RedHat"
  PKG_TOOL="dnf"
elif which yum >/dev/null 2>&1; then
  OS="RedHat"
  PKG_TOOL="yum"
elif which apt-get >/dev/null 2>&1; then
  OS="Debian"
  PKG_TOOL="apt-get"
else
  echo "[INSTALLATION-SCRIPT] This operating system is not supported by the ProActive installation script."
  exit 1
fi

echo "[INSTALLATION-SCRIPT] Parsing the input configuration file using 'jq' library..."
$PKG_TOOL -y update
$PKG_TOOL -y install jq
serverConfig=$(cat inputConfig.json | jq '.serverConfiguration')

archiveLocation=$(echo $serverConfig | jq -r '.archiveLocation')
libraries=$(echo $serverConfig | jq -r '.libraries')
installationDirectory=$(echo $serverConfig | jq -r '.installationDirectory')
systemUser=$(echo $serverConfig | jq -r '.systemUser')
systemUserGroup=$(echo $serverConfig | jq -r '.systemUserGroup')
systemUserPassword=$(echo $serverConfig | jq -r '.systemUserPassword')
networkProtocol=$(echo $serverConfig | jq -r '.networkProtocol')
webProtocol=$(echo $serverConfig | jq -r '.webProtocol')
webPort=$(echo $serverConfig | jq -r '.webPort')
historyPeriodDays=$(echo $serverConfig | jq -r '.historyPeriodDays')
serverDNSName=$(echo $serverConfig | jq -r '.serverDNSName')
certificatePath=$(echo $serverConfig | jq -r '.certificatePath')
certificateKeyPath=$(echo $serverConfig | jq -r '.certificateKeyPath')
certificateKeyStorePassword=$(echo $serverConfig | jq -r '.certificateKeyStorePassword')
passphrase=$(echo $serverConfig | jq -r '.passphrase')
proactiveAdminPassword=$(echo $serverConfig | jq -r '.proactiveAdminPassword')
localNodes=$(echo $serverConfig | jq -r '.localNodes')
addExternalNodeSources=$(echo $serverConfig | jq -r '.addExternalNodeSources')

proactiveAdminPasswordDecrypted=$(echo $proactiveAdminPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)
certificateKeyStorePasswordDecrypted=$(echo $certificateKeyStorePassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)
systemUserPasswordDecrypted=$(echo $systemUserPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)

echo "[INSTALLATION-SCRIPT] Installing the required libraries..."
for i in ${libraries//,/ }; do
  echo "[INSTALLATION-SCRIPT] Installing $i..."
  $PKG_TOOL -y install $i
done

echo "[INSTALLATION-SCRIPT] Stop the ProActive Service and remove old Installation..."
if [ -f /etc/init.d/proactive-scheduler ]; then
  service proactive-scheduler stop
fi
rm -rf $installationDirectory
mkdir -p $installationDirectory

if [[ $archiveLocation == http* ]]; then
  echo "[INSTALLATION-SCRIPT] Downloading the ProActive Server archive..."
  cd /tmp && {
    curl -k -o proactive.zip $archiveLocation
    cd - >/dev/null
  }
  archiveLocation="/tmp/proactive.zip"
fi

echo "[INSTALLATION-SCRIPT] Unzipping the ProActive Archive..."
unzip -q $archiveLocation -d $installationDirectory

echo "[INSTALLATION-SCRIPT] Creating default Symbolic Link..."
ln -s -f $installationDirectory/activeeon_enterprise-pca_server* "$installationDirectory/default"
PROACTIVE_DEFAULT=$installationDirectory/default

# Escape functions for sed
escape_rhs_sed() {
  echo $(printf '%s\n' "$1" | sed 's:[\/&]:\\&:g;$!s/$/\\/')
}

escape_lhs_sed() {
  echo $(printf '%s\n' "$1" | sed 's:[][\/.^$*]:\\&:g')
}

update_node_jars() {
  (cd ${PROACTIVE_DEFAULT} && zip dist/lib/rm-node-*.jar config/authentication/rm.cred)
  (cd ${PROACTIVE_DEFAULT}/dist && zip war/rest/node.jar lib/rm-node-*.jar)
}

echo "[INSTALLATION-SCRIPT] Configuring the Network Protocol..."
sed -i "s#^\(proactive\.communication\.protocol\s*=\s*\).*#\1${networkProtocol}#" $PROACTIVE_DEFAULT/config/network/server.ini

echo "[INSTALLATION-SCRIPT] Configuring the Web Protocol and Port..."
if [[ "${webProtocol}" == "https" ]]; then
  mkdir $PROACTIVE_DEFAULT/keystore

  echo "[INSTALLATION-SCRIPT] Configuring the certificate..."
  if [[ $certificatePath == *.pfx ]]; then
    $PROACTIVE_DEFAULT/jre/bin/keytool -importkeystore -srckeystore $certificatePath -srcstoretype PKCS12 -destkeystore $PROACTIVE_DEFAULT/keystore/keystore -srcstorepass $certificateKeyStorePasswordDecrypted -deststorepass $certificateKeyStorePasswordDecrypted
  else
    openssl pkcs12 -inkey $certificateKeyPath -in $certificatePath -export -out $PROACTIVE_DEFAULT/keystore/keystore.pkcs12 -passout pass:$certificateKeyStorePasswordDecrypted
    $PROACTIVE_DEFAULT/jre/bin/keytool -importkeystore -srckeystore $PROACTIVE_DEFAULT/keystore/keystore.pkcs12 -srcstoretype PKCS12 -destkeystore $PROACTIVE_DEFAULT/keystore/keystore -srcstorepass $certificateKeyStorePasswordDecrypted -deststorepass $certificateKeyStorePasswordDecrypted
  fi

  sed -e "s/^web\.https=.*/web.https=true/g" -i "$PROACTIVE_DEFAULT/config/web/settings.ini"
  sed -e "s/^web\.https\.keystore=\(.*\)/web.https.keystore=$(escape_rhs_sed $PROACTIVE_DEFAULT/keystore/keystore)/g" -i "$PROACTIVE_DEFAULT/config/web/settings.ini"
  sed -e "s/^web\.https\.keystore\.password=\(.*\)/web.https.keystore.password=$certificateKeyStorePasswordDecrypted/g" -i "$PROACTIVE_DEFAULT/config/web/settings.ini"

  sed -e "s/^#web\.https\.allow_any_hostname=.*/web.https.allow_any_hostname=true/g" -i "$PROACTIVE_DEFAULT/config/web/settings.ini"
  sed -e "s/^#web\.https\.allow_any_certificate=.*/web.https.allow_any_certificate=true/g" -i "$PROACTIVE_DEFAULT/config/web/settings.ini"
  sed -e "s/^#web\.https\.allow_any_hostname=.*/web.https.allow_any_hostname=true/g" -i "$PROACTIVE_DEFAULT/dist/war/rm/rm.conf"
  sed -e "s/^#web\.https\.allow_any_certificate=.*/web.https.allow_any_certificate=true/g" -i "$PROACTIVE_DEFAULT/dist/war/rm/rm.conf"
  sed -e "s/^#web\.https\.allow_any_hostname=.*/web.https.allow_any_hostname=true/g" -i "$PROACTIVE_DEFAULT/dist/war/scheduler/scheduler.conf"
  sed -e "s/^#web\.https\.allow_any_certificate=.*/web.https.allow_any_certificate=true/g" -i "$PROACTIVE_DEFAULT/dist/war/scheduler/scheduler.conf"
  sed -e "s/^web\.https\.port=.*/web.https.port=$webPort/g" -i "$PROACTIVE_DEFAULT/config/web/settings.ini"
else
  sed -e "s/^web\.http\.port=.*/web.http.port=$webPort/g" -i "$PROACTIVE_DEFAULT/config/web/settings.ini"
fi

for file in $(find $PROACTIVE_DEFAULT/dist/war -name 'application.properties'); do
  sed -e "s/$(escape_lhs_sed http://localhost:8080)/$(escape_rhs_sed ${webProtocol}://localhost:${webPort})/g" -i "$file"
  # for cloud_automation_service
  sed -e "s/^server\.port=.*/server.port=$webPort/g" -i "$file"
  sed -e "s/web\.https\.allow_any_certificate=.*/web.https.allow_any_certificate=true/g" -i "$file"
  sed -e "s/web\.https\.allow_any_hostname=.*/web.https.allow_any_hostname=true/g" -i "$file"

done

sed -e "s/$(escape_lhs_sed http://localhost:8080)/$(escape_rhs_sed ${webProtocol}://localhost:${webPort})/g" -i "$PROACTIVE_DEFAULT/config/web/settings.ini"
sed -e "s/$(escape_lhs_sed http://localhost:8080)/$(escape_rhs_sed ${webProtocol}://localhost:${webPort})/g" -i "$PROACTIVE_DEFAULT/dist/war/rm/rm.conf"
sed -e "s/$(escape_lhs_sed http://localhost:8080)/$(escape_rhs_sed ${webProtocol}://localhost:${webPort})/g" -i "$PROACTIVE_DEFAULT/dist/war/scheduler/scheduler.conf"

sed -e "s/#$(escape_lhs_sed pa.scheduler.rest.public.url=)/pa.scheduler.rest.public.url=$(escape_rhs_sed ${webProtocol}://$serverDNSName:${webPort}/rest)/g" -i "$PROACTIVE_DEFAULT/config/scheduler/settings.ini"
sed -e "s/#$(escape_lhs_sed pa.catalog.rest.public.url=)/pa.catalog.rest.public.url=$(escape_rhs_sed ${webProtocol}://$serverDNSName:${webPort}/catalog)/g" -i "$PROACTIVE_DEFAULT/config/scheduler/settings.ini"

echo "[INSTALLATION-SCRIPT] Configuring the ProActive housekeeping mechanism..."
JOB_CLEANUP_DAYS=$historyPeriodDays
JOB_CLEANUP_SECONDS=$((JOB_CLEANUP_DAYS * 24 * 3600))
sed -e "s/pa\.scheduler\.core\.automaticremovejobdelay=.*/pa.scheduler.core.automaticremovejobdelay=$JOB_CLEANUP_SECONDS/g" -i "$PROACTIVE_DEFAULT/config/scheduler/settings.ini"
sed -e "s/pa\.scheduler\.job\.removeFromDataBase=.*/pa.scheduler.job.removeFromDataBase=true/g" -i "$PROACTIVE_DEFAULT/config/scheduler/settings.ini"
sed -e "s/^#pa\.rm\.history\.maxperiod=.*/pa.rm.history.maxperiod=$JOB_CLEANUP_SECONDS/g" -i "$PROACTIVE_DEFAULT/config/rm/settings.ini"
sed -e "s/^notifications\.housekeeping\.removedelay=.*/notifications.housekeeping.removedelay=$JOB_CLEANUP_SECONDS/g" -i "$PROACTIVE_DEFAULT/dist/war/notification-service/WEB-INF/classes/application.properties"
sed -e "s/^#pa\.job\.execution\.history\.maxperiod=.*/pa.job.execution.history.maxperiod=$JOB_CLEANUP_SECONDS/g" -i "$PROACTIVE_DEFAULT/dist/war/job-planner/WEB-INF/classes/application.properties"

echo "[INSTALLATION-SCRIPT] Generating random password for internal scheduler accounts and setting admin password..."
RM_PWD=$(
  date +%s | sha256sum | base64 | head -c 32
  echo
)
SCHED_PWD=$(
  date +%s | sha256sum | base64 | head -c 32
  echo
)
WATCHER_PWD=$(
  date +%s | sha256sum | base64 | head -c 32
  echo
)

AUTH_ROOT=${PROACTIVE_DEFAULT}/config/authentication

echo "[INSTALLATION-SCRIPT] Generating New Private/Public key pair for the scheduler..."
${PROACTIVE_DEFAULT}/tools/proactive-key-gen -p "$AUTH_ROOT/keys/priv.key" -P "$AUTH_ROOT/keys/pub.key"

echo "[INSTALLATION-SCRIPT] Adding users..."
${PROACTIVE_DEFAULT}/tools/proactive-users -U -l admin -p "$proactiveAdminPasswordDecrypted"
${PROACTIVE_DEFAULT}/tools/proactive-users -U -l rm -p "$RM_PWD"
${PROACTIVE_DEFAULT}/tools/proactive-users -U -l scheduler -p "$SCHED_PWD"
${PROACTIVE_DEFAULT}/tools/proactive-users -U -l watcher -p "$WATCHER_PWD"

echo "[INSTALLATION-SCRIPT] Generating credential files for ProActive System accounts..."
${PROACTIVE_DEFAULT}/tools/proactive-create-cred -F $AUTH_ROOT/keys/pub.key -l admin -p "$proactiveAdminPasswordDecrypted" -o $AUTH_ROOT/admin_user.cred
${PROACTIVE_DEFAULT}/tools/proactive-create-cred -F $AUTH_ROOT/keys/pub.key -l scheduler -p "$SCHED_PWD" -o $AUTH_ROOT/scheduler.cred
${PROACTIVE_DEFAULT}/tools/proactive-create-cred -F $AUTH_ROOT/keys/pub.key -l rm -p "$RM_PWD" -o $AUTH_ROOT/rm.cred
${PROACTIVE_DEFAULT}/tools/proactive-create-cred -F $AUTH_ROOT/keys/pub.key -l watcher -p "$WATCHER_PWD" -o $AUTH_ROOT/watcher.cred

echo "[INSTALLATION-SCRIPT] Updating node jars..."
update_node_jars

echo "[INSTALLATION-SCRIPT] Configuring the watcher account..."
sed -e "s/scheduler\.cache\.password=.*/scheduler.cache.password=/g" -i "${PROACTIVE_DEFAULT}/config/web/settings.ini"
sed -e "s/^.*scheduler\.cache\.credential=.*$/scheduler.cache.credential=$(escape_rhs_sed $AUTH_ROOT/watcher.cred)/g" -i "${PROACTIVE_DEFAULT}/config/web/settings.ini"
sed -e "s/rm\.cache\.password=.*/rm.cache.password=/g" -i "${PROACTIVE_DEFAULT}/config/web/settings.ini"
sed -e "s/^.*rm\.cache\.credential=.*$/rm.cache.credential=$(escape_rhs_sed $AUTH_ROOT/watcher.cred)/g" -i "${PROACTIVE_DEFAULT}/config/web/settings.ini"
sed -e "s/^.*listeners\.pwd=.*$/listeners.pwd=$(escape_rhs_sed $WATCHER_PWD)/g" -i "${PROACTIVE_DEFAULT}/dist/war/notification-service/WEB-INF/classes/application.properties"

echo "[INSTALLATION-SCRIPT] Removing test accounts..."
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l demo
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l user
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l guest
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l test
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l radmin
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l nsadmin
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l nsadmin2
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l provider
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l test_executor

echo "[INSTALLATION-SCRIPT] Creating the ProActive user/group..."
if id "$systemUser" &>/dev/null; then
  echo "[INSTALLATION-SCRIPT] The given user already exists..."
else
  groupadd $systemUserGroup
  useradd $systemUser -d $installationDirectory -g $systemUserGroup
  echo "$systemUser:$systemUserPasswordDecrypted" | chpasswd
fi

echo "[INSTALLATION-SCRIPT] Chowning all Server files with provided user/group..."
chown "$systemUser:$systemUserGroup" $installationDirectory
chown -R "$systemUser:$systemUserGroup" $PROACTIVE_DEFAULT/

echo "[INSTALLATION-SCRIPT] Installing the 'proactive-scheduler' service..."
sed -e "s/^USER=.*/USER=$systemUser/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
sed -e "s/^PROTOCOL=.*/PROTOCOL=$webProtocol/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
sed -e "s/^PORT=.*/PORT=$webPort/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
sed -e "s/^NB_NODES=.*/NB_NODES=$localNodes/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
sed -e "s/^PA_ROOT=.*/PA_ROOT=$(escape_rhs_sed "$installationDirectory")/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"

if [ "$localNodes" != "0" ]; then
  sed -e "s/^SINGLE_JVM=.*/SINGLE_JVM=true/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
fi

if [[ "$OS" == "Debian" ]]; then
  tail -n +5 "${PROACTIVE_DEFAULT}/tools/proactive-scheduler" >"${PROACTIVE_DEFAULT}/tools/proactive-scheduler.tmp"
  echo '#!/bin/bash
### BEGIN INIT INFO
# Provides:          proactive-scheduler
# Required-Start:    $all
# Required-Stop:
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
### END INIT INFO
 ' >"${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
  cat "${PROACTIVE_DEFAULT}/tools/proactive-scheduler.tmp" >>"${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
  rm "${PROACTIVE_DEFAULT}/tools/proactive-scheduler.tmp"
fi

cp "${PROACTIVE_DEFAULT}/tools/proactive-scheduler" /etc/init.d/

chmod 700 /etc/init.d/proactive-scheduler

mkdir -p /var/log/proactive
touch /var/log/proactive/scheduler

# configure infinite timeout and service type for systemd
mkdir -p /etc/systemd/system/proactive-scheduler.service.d
echo '[Service]
Type=simple
TimeoutSec=0
' >/etc/systemd/system/proactive-scheduler.service.d/timeout.conf

chown -R $systemUser:$systemUserGroup /var/log/proactive

if [[ "$OS" == "RedHat" ]]; then
  chkconfig proactive-scheduler on
elif [[ "$OS" == "Debian" ]]; then
  update-rc.d proactive-scheduler defaults
fi

echo "[INSTALLATION-SCRIPT] Starting the ProActive Server..."
echo "[INSTALLATION-SCRIPT] If a problem occurs, check output in /var/log/proactive/scheduler"
service proactive-scheduler start

echo "[INSTALLATION-SCRIPT] Waiting for the Server to be up before adding Node Sources..."
until curl -s --insecure --head --request GET $webProtocol://$serverDNSName:$webPort | grep "200 OK" >/dev/null; do
  sleep 5
done

echo "[INSTALLATION-SCRIPT] ProActive Server started at: $webProtocol://$serverDNSName:$webPort"

if [ "$addExternalNodeSources" == "true" ]; then

  echo "[INSTALLATION-SCRIPT] Adding Node Sources..."
  nodesConfig=$(cat inputConfig.json | jq '.nodesConfiguration')
  numberOfNodeSources=$(echo $nodesConfig | jq '. | length')

  for ((i = 0; i < $numberOfNodeSources; i++)); do
    rm -f /tmp/hostlist.txt 2>/dev/null

    nodeConfig=$(cat inputConfig.json | jq -r '.nodesConfiguration['$i']')
    nodeName=$(echo $nodeConfig | jq -r '.name')
    nodeType=$(echo $nodeConfig | jq -r '.type')
    nodeOsFamily=$(echo $nodeConfig | jq -r '.osFamily')
    nodeSshUserName=$(echo $nodeConfig | jq -r '.sshUserName')
    nodeSshPassword=$(echo $nodeConfig | jq -r '.sshPassword')
    nodeSshPasswordDecrypted=$(echo $nodeSshPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)
    nodeSudoUser=$(echo $nodeConfig | jq -r '.sudoUser')
    nodeSudoUserPassword=$(echo $nodeConfig | jq -r '.sudoUserPassword')
    nodeSudoUserPasswordDecrypted=$(echo $nodeSudoUserPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)
    nodeLibraries=$(echo $nodeConfig | jq -r '.libraries')
    nodePython3Modules=$(echo $nodeConfig | jq -r '.python3Modules')
    nodeAdditionalInstallationCommand=$(echo $nodeConfig | jq -r '.additionalInstallationCommand')

    echo "[INSTALLATION-SCRIPT] Setting up the linux packaging system on the Node machine..."
    NODE_PKG_TOOL=""
    if [ "$nodeOsFamily" == "debian" ]; then
      NODE_PKG_TOOL="apt-get"
    elif [ "$nodeOsFamily" == "redhat" ]; then
      NODE_PKG_TOOL="dnf"
    elif [ "$nodeOsFamily" == "centos" ]; then
      NODE_PKG_TOOL="yum"
    else
      echo "[INSTALLATION-SCRIPT] The operating system of the node machine is not supported by the ProActive installation script."
      exit 1
    fi

    hostsConfig=$(echo $nodeConfig | jq '.hosts')
    numberOfHosts=$(echo $hostsConfig | jq '. | length')
    for ((j = 0; j < $numberOfHosts; j++)); do
      hostnameOrIpAddress=$(echo $hostsConfig | jq -r '.['$j'].hostnameOrIpAddress')
      nodesNumber=$(echo $hostsConfig | jq -r '.['$j'].nodesNumber')
      echo "$hostnameOrIpAddress $nodesNumber" >>/tmp/hostlist.txt

      echo "[INSTALLATION-SCRIPT] Installing the desired libraries on the Node machine..."
      sshpass -p $nodeSudoUserPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSudoUser@$hostnameOrIpAddress "sudo $NODE_PKG_TOOL -y update"

      for k in ${nodeLibraries//,/ }; do
        sshpass -p $nodeSudoUserPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSudoUser@$hostnameOrIpAddress "sudo $NODE_PKG_TOOL -y install $k"
      done

      echo "[INSTALLATION-SCRIPT] Installing python3Modules..."
      sshpass -p $nodeSudoUserPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSudoUser@$hostnameOrIpAddress "sudo -H pip3 install $nodePython3Modules"

      echo "[INSTALLATION-SCRIPT] Running additional Installation Commands..."
      sshpass -p $nodeSudoUserPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSudoUser@$hostnameOrIpAddress "sudo $nodeAdditionalInstallationCommand"
    done

    echo "[INSTALLATION-SCRIPT] Adding the Node Source..."
    if [ "$nodeType" == "ssh" ]; then
      su "$systemUser" -c "${PROACTIVE_DEFAULT}/bin/proactive-client -k -u $webProtocol://$serverDNSName:$webPort/rest/ -l admin -p $proactiveAdminPasswordDecrypted --createns $nodeName -infrastructure org.ow2.proactive.resourcemanager.nodesource.infrastructure.SSHInfrastructureV2 /tmp/hostlist.txt 60000 5 5000 22 '$nodeSshUserName' '$nodeSshPasswordDecrypted' '' '' '' '' 'Linux' '-Dproactive.net.nolocal=true -Dproactive.communication.protocol=$networkProtocol -Dproactive.useIPaddress=true  -Dproactive.pamr.router.address=$serverDNSName' 'useNodeJarStartupScript' '$webProtocol://$serverDNSName:$webPort/rest/node.jar' '' 'mkdir -p /tmp/node && cd /tmp/node; if ! type -p jre/bin/java; then wget -nv -N https://s3.amazonaws.com/ci-materials/Latest_jre/jre-8u312b07-linux-x64.tar.gz; tar -xf jre-8u312b07-linux-x64.tar.gz; mv jre1.8.0_312b07/ jre; fi; wget --no-check-certificate -nv -O node.jar %nodeJarUrl%; rm -rf lib; %detachedModePrefix% jre/bin/java -jar node.jar %javaOptions% -Dpython.path=%jythonPath% -r %rmUrl% -n %nodeName% -s %nodeSourceName% -w %numberOfNodesPerInstance% -v %credentials% &' -policy org.ow2.proactive.resourcemanager.nodesource.policy.RestartDownNodesPolicy 'ALL' 'ME' '1800000' -X"
      echo -e "\n[INSTALLATION-SCRIPT] Node Source '$nodeName' successfully created"
    fi
  done
fi
