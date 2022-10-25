#!/bin/bash

# This bash script is designed to install PWS for Ubuntu 20.04.
# A file with the name "inputConfig.json" should be colocated in the same DIR with the script.
# The script takes 2 input variables:
# $1 is the passphrase.
# $2 is the server DNS name or the public ip address.
# If an error occur, the script will exit with the value of the PID to point at the logfile.
# Authors: Mohamed Boussa, Ali Jawad FAHS, Activeeon


# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
EXITCODE=$PID
DATE=$(date)
LOGFILE="/var/log/install-proactive.$PID.log"
PKG_TOOL="apt-get"

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
log_print INFO "Installation started!"
log_print INFO "Logs are saved at: $LOGFILE"

newline "UPDATES"
log_print INFO "Updating libraries"
$PKG_TOOL -y update
Check_lock
log_print INFO "Checking for unattended upgrades"
sudo unattended-upgrade -d
Check_lock

newline "JQ"
log_print INFO "Parsing the input configuration file using 'jq' library..."
$PKG_TOOL -y install jq || { log_print ERROR "jq installation failed!"; exit $EXITCODE; }
log_print INFO "jq was successfully installed!"


newline "INPUT"
# get the passed settings
log_print INFO "Loading the passphrase and serverDNSName variables..."
passphrase=$1
serverDNSName=$2
FLAG=0
[ -z "$passphrase" ] && { log_print ERROR "passphrase is not passed"; FLAG=1; }
[ -z "$serverDNSName" ] && { log_print ERROR "serverDNSName is not passed"; FLAG=1; }

if [ $FLAG -eq 1 ]; then 
  log_print ERROR "The script should be called with two input varaibles: \n 
  sudo ./ProActive_Installer.sh <PASS_PHRASE> <DNS_NAME_OR_IP>"
fi

# get the settings from the inputConfig file
log_print INFO "Loading the \"inputConfig.json\" file..."
[ -f ./inputConfig.json ] || { log_print ERROR "\"inputConfig.json\" does not exist!"; exit $EXITCODE; }
serverConfig=$(cat inputConfig.json | jq '.serverConfiguration')

log_print INFO "Loading the variables in the \"inputConfig.json\" file..."
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
proactiveAdminPassword=$(echo $serverConfig | jq -r '.proactiveAdminPassword')
localNodes=$(echo $serverConfig | jq -r '.localNodes')

log_print INFO "The \"inputConfig.json\" file was loaded successfully!"
proactiveAdminPasswordDecrypted=$(echo $proactiveAdminPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)
systemUserPasswordDecrypted=$(echo $systemUserPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)

newline "VARIABLES"
log_print INFO "passphrase is set to: \t\t $passphrase"
log_print INFO "archiveLocation is set to: \t $archiveLocation"
log_print INFO "installationDirectory is set to: \t $installationDirectory"
log_print INFO "serverDNSName is set to: \t\t $serverDNSName"
log_print INFO "webProtocol is set to: \t\t $webProtocol"
log_print INFO "webPort is set to: \t\t $webPort"
log_print INFO "networkProtocol is set to: \t $networkProtocol"
log_print INFO "localNodes is set to: \t\t $localNodes"
log_print INFO "systemUser is set to: \t\t $systemUser"
log_print INFO "systemUserGroup is set to: \t $systemUserGroup"
log_print INFO "historyPeriodDays is set to: \t $historyPeriodDays"
log_print INFO "libraries is set to: \t\t $libraries"

newline "DEPS"
log_print INFO "Installing the required libraries..."
for i in ${libraries//,/ }
do
  log_print INFO "Installing $i..."
  $PKG_TOOL -y install $i
done

newline "ARCHIVE"
if [ -f /etc/init.d/proactive-scheduler ]
then
  log_print INFO "Stop the ProActive Service and remove old Installation...";
  service proactive-scheduler stop;
fi

rm -rf $installationDirectory
mkdir -p $installationDirectory

if [[ $archiveLocation == http* ]]
then
log_print INFO "Downloading the ProActive Server archive..."
  cd /tmp && { curl -k -o proactive.zip $archiveLocation; cd - >/dev/null; }
  archiveLocation="/tmp/proactive.zip";
fi

log_print INFO "Unzipping the ProActive Archive..."
unzip -q $archiveLocation -d $installationDirectory

log_print INFO "Creating default Symbolic Link..."
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

newline "NETWORK"
log_print INFO "Configuring the Network Protocol..."
sed -i "s#^\(proactive\.communication\.protocol\s*=\s*\).*#\1${networkProtocol}#" $PROACTIVE_DEFAULT/config/network/server.ini
sed -i "s#^\(proactive\.communication\.protocol\s*=\s*\).*#\1${networkProtocol}#" $PROACTIVE_DEFAULT/config/network/node.ini

log_print INFO "Configuring the Web Protocol and Port..."
sed -e "s/^web\.http\.port=.*/web.http.port=$webPort/g" -i "$PROACTIVE_DEFAULT/config/web/settings.ini"

for file in $(find $PROACTIVE_DEFAULT/dist/war -name 'application.properties')
do
  sed -e "s/$(escape_lhs_sed http://localhost:8080)/$(escape_rhs_sed ${webProtocol}://localhost:${webPort})/g" -i "$file";
  # for cloud_automation_service
  sed -e "s/^server\.port=.*/server.port=$webPort/g" -i "$file";
  sed -e "s/web\.https\.allow_any_certificate=.*/web.https.allow_any_certificate=true/g" -i "$file";
  sed -e "s/web\.https\.allow_any_hostname=.*/web.https.allow_any_hostname=true/g" -i "$file";
done

sed -e "s/$(escape_lhs_sed http://localhost:8080)/$(escape_rhs_sed ${webProtocol}://localhost:${webPort})/g" -i "$PROACTIVE_DEFAULT/config/web/settings.ini"
sed -e "s/$(escape_lhs_sed http://localhost:8080)/$(escape_rhs_sed ${webProtocol}://localhost:${webPort})/g" -i "$PROACTIVE_DEFAULT/dist/war/rm/rm.conf"
sed -e "s/$(escape_lhs_sed http://localhost:8080)/$(escape_rhs_sed ${webProtocol}://localhost:${webPort})/g" -i "$PROACTIVE_DEFAULT/dist/war/scheduler/scheduler.conf"

sed -e "s/#$(escape_lhs_sed pa.scheduler.rest.public.url=)/pa.scheduler.rest.public.url=$(escape_rhs_sed ${webProtocol}://$serverDNSName:${webPort}/rest)/g" -i "$PROACTIVE_DEFAULT/config/scheduler/settings.ini"
sed -e "s/#$(escape_lhs_sed pa.catalog.rest.public.url=)/pa.catalog.rest.public.url=$(escape_rhs_sed ${webProtocol}://$serverDNSName:${webPort}/catalog)/g" -i "$PROACTIVE_DEFAULT/config/scheduler/settings.ini"

newline "HOUSEKEEPING"
log_print INFO "Configuring the ProActive housekeeping mechanism..."
JOB_CLEANUP_DAYS=$historyPeriodDays
JOB_CLEANUP_SECONDS=$((JOB_CLEANUP_DAYS * 24 * 3600))
sed -e "s/pa\.scheduler\.core\.automaticremovejobdelay=.*/pa.scheduler.core.automaticremovejobdelay=$JOB_CLEANUP_SECONDS/g" -i "$PROACTIVE_DEFAULT/config/scheduler/settings.ini"
sed -e "s/pa\.scheduler\.job\.removeFromDataBase=.*/pa.scheduler.job.removeFromDataBase=true/g" -i "$PROACTIVE_DEFAULT/config/scheduler/settings.ini"
sed -e "s/^#pa\.rm\.history\.maxperiod=.*/pa.rm.history.maxperiod=$JOB_CLEANUP_SECONDS/g" -i "$PROACTIVE_DEFAULT/config/rm/settings.ini"
sed -e "s/^notifications\.housekeeping\.removedelay=.*/notifications.housekeeping.removedelay=$JOB_CLEANUP_SECONDS/g" -i "$PROACTIVE_DEFAULT/dist/war/notification-service/WEB-INF/classes/application.properties"
sed -e "s/^#pa\.job\.execution\.history\.maxperiod=.*/pa.job.execution.history.maxperiod=$JOB_CLEANUP_SECONDS/g" -i "$PROACTIVE_DEFAULT/dist/war/job-planner/WEB-INF/classes/application.properties"

newline "AUTH"
log_print INFO "Generating random password for internal scheduler accounts and setting admin password..."
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

log_print INFO "Generating New Private/Public key pair for the scheduler..."
${PROACTIVE_DEFAULT}/tools/proactive-key-gen -p "$AUTH_ROOT/keys/priv.key" -P "$AUTH_ROOT/keys/pub.key"

log_print INFO "Adding users..."
${PROACTIVE_DEFAULT}/tools/proactive-users -U -l admin -p "$proactiveAdminPasswordDecrypted"
${PROACTIVE_DEFAULT}/tools/proactive-users -U -l rm -p "$RM_PWD"
${PROACTIVE_DEFAULT}/tools/proactive-users -U -l scheduler -p "$SCHED_PWD"
${PROACTIVE_DEFAULT}/tools/proactive-users -U -l watcher -p "$WATCHER_PWD"

log_print INFO "Generating credential files for ProActive System accounts..."
${PROACTIVE_DEFAULT}/tools/proactive-create-cred -F $AUTH_ROOT/keys/pub.key -l admin -p "$proactiveAdminPasswordDecrypted" -o $AUTH_ROOT/admin_user.cred
${PROACTIVE_DEFAULT}/tools/proactive-create-cred -F $AUTH_ROOT/keys/pub.key -l scheduler -p "$SCHED_PWD" -o $AUTH_ROOT/scheduler.cred
${PROACTIVE_DEFAULT}/tools/proactive-create-cred -F $AUTH_ROOT/keys/pub.key -l rm -p "$RM_PWD" -o $AUTH_ROOT/rm.cred
${PROACTIVE_DEFAULT}/tools/proactive-create-cred -F $AUTH_ROOT/keys/pub.key -l watcher -p "$WATCHER_PWD" -o $AUTH_ROOT/watcher.cred

newline "JARS"
log_print INFO "Updating node jars..."
update_node_jars

newline "WATCHER"
log_print INFO "Configuring the watcher account..."
sed -e "s/scheduler\.cache\.password=.*/scheduler.cache.password=/g" -i "${PROACTIVE_DEFAULT}/config/web/settings.ini"
sed -e "s/^.*scheduler\.cache\.credential=.*$/scheduler.cache.credential=$(escape_rhs_sed $AUTH_ROOT/watcher.cred)/g" -i "${PROACTIVE_DEFAULT}/config/web/settings.ini"
sed -e "s/rm\.cache\.password=.*/rm.cache.password=/g" -i "${PROACTIVE_DEFAULT}/config/web/settings.ini"
sed -e "s/^.*rm\.cache\.credential=.*$/rm.cache.credential=$(escape_rhs_sed $AUTH_ROOT/watcher.cred)/g" -i "${PROACTIVE_DEFAULT}/config/web/settings.ini"
sed -e "s/^.*listeners\.pwd=.*$/listeners.pwd=$(escape_rhs_sed $WATCHER_PWD)/g" -i "${PROACTIVE_DEFAULT}/dist/war/notification-service/WEB-INF/classes/application.properties"

newline "TEST ACCOUNTS"
log_print INFO "Removing test accounts..."
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l demo
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l user
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l guest
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l test
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l radmin
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l nsadmin
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l nsadmin2
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l provider
${PROACTIVE_DEFAULT}/tools/proactive-users -D -l test_executor

log_print INFO "Creating the ProActive user/group..."
if id "$systemUser" &>/dev/null
then
  log_print INFO "The given user already exists...";
else
  groupadd $systemUserGroup;
  useradd $systemUser -d $installationDirectory -g $systemUserGroup;
  echo "$systemUser:$systemUserPasswordDecrypted" | chpasswd;
fi

newline "CHOWN"
log_print INFO "Chowning all Server files with provided user/group..."
chown "$systemUser:$systemUserGroup" $installationDirectory
chown -R "$systemUser:$systemUserGroup" $PROACTIVE_DEFAULT/

log_print INFO "Installing the 'proactive-scheduler' service..."
sed -e "s/^USER=.*/USER=$systemUser/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
sed -e "s/^PROTOCOL=.*/PROTOCOL=$webProtocol/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
sed -e "s/^PORT=.*/PORT=$webPort/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
sed -e "s/^NB_NODES=.*/NB_NODES=$localNodes/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
sed -e "s/^PA_ROOT=.*/PA_ROOT=$(escape_rhs_sed "$installationDirectory")/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"

if [ "$localNodes" != "0" ]
then
  sed -e "s/^SINGLE_JVM=.*/SINGLE_JVM=true/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
fi

newline "SERVICE"
log_print INFO "Creating the linux service"
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
log_print INFO "Updating the rc"
update-rc.d proactive-scheduler defaults

newline "SERVER"
log_print INFO "Starting the ProActive Server..."
log_print INFO "If a problem occurs, check output in /var/log/proactive/scheduler"
service proactive-scheduler start

log_print INFO "Waiting for the Server to be up before adding Node Sources..."
cycle=0
until curl -s --insecure --head --request GET $webProtocol://$serverDNSName:$webPort | grep "200 OK" >/dev/null;
do
  cycle=$((cycle+1))
  echo "waiting in cycle $cycle"
  sleep 5;
done

log_print INFO "ProActive Server started at: $webProtocol://$serverDNSName:$webPort"

newline "FINISHED"
# Declare configuration done successfully
log_print INFO "Full logs can be found here: $LOGFILE"
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "Configuration done successfully in $ELAPSED seconds "
