#!/bin/bash
#set -x
#set -e

#======================= configure message colors =============================================================
#set colors
RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'
PURPLE='\033[0;35m'

#======================= configure output messages =============================================================
# A function to print a message to the stdout
log_print() {
  level=$1
  Message=$2
  if [ "$level" == "INFO" ]; then
    printf "\e[0m ${GREEN}[$level] \e[0m ${PURPLE}[$(date)]: [INSTALLATION-SCRIPT] ${NC}$Message \n"
  elif [ "$level" == "ERROR" ]; then
    printf "\e[41m ${RED}[$level] \e[0m ${PURPLE}[$(date)]: [INSTALLATION-SCRIPT] ${NC}$Message \n"
  elif [ "$level" == "OK" ]; then
    printf "\e[42m [$level] \e[0m [$(date)]: $Message \n"
  elif [ "$level" == "WARNING" ]; then
    printf "\e[43m [$level] \e[0m [$(date)]: $Message \n"
  elif [ "$level" == "STEP" ]; then
    printf "\e[44m ############################# $2 ############################# \e[0m \n"
  fi
}

log_print INFO "Setting up the OS and Linux package system to be considered..."
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
  log_print ERROR "This operating system is not supported by the ProActive installation script."
  exit 1
fi

log_print INFO "Parsing the input configuration file using 'jq' library..."
$PKG_TOOL -y update
$PKG_TOOL -y install jq
serverConfig=$(cat inputConfig.json | jq '.serverConfiguration')
ldapConfig=$(cat inputConfig.json | jq '.ldapConfiguration')
dbConfig=$(cat inputConfig.json | jq '.dbConfiguration')

#server input
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
enableCustomDbConfig=$(echo $serverConfig | jq -r '.enableCustomDbConfig')
enableLdapConfiguration=$(echo $serverConfig | jq -r '.enableLdapConfiguration')

proactiveAdminPasswordDecrypted=$(echo $proactiveAdminPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)
certificateKeyStorePasswordDecrypted=$(echo $certificateKeyStorePassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)
systemUserPasswordDecrypted=$(echo $systemUserPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)

#ldap input
serverUrls=$(echo $ldapConfig | jq -r '.serverUrls')
userSubtree=$(echo $ldapConfig | jq -r '.userSubtree')
groupSubtree=$(echo $ldapConfig | jq -r '.groupSubtree')
bindLogin=$(echo $ldapConfig | jq -r '.bindLogin')
bindPassword=$(echo $ldapConfig | jq -r '.bindPassword')
userFilter=$(echo $ldapConfig | jq -r '.userFilter')
groupFilter=$(echo $ldapConfig | jq -r '.groupFilter')
testLogin=$(echo $ldapConfig | jq -r '.testLogin')
testPassword=$(echo $ldapConfig | jq -r '.testPassword')
adminRoles=$(echo $ldapConfig | jq -r '.adminRoles')
userRoles=$(echo $ldapConfig | jq -r '.userRoles')

bindPasswordDecrypted=$(echo $bindPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)
testPasswordDecrypted=$(echo $testPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)

#DB input
dbType=$(echo $dbConfig | jq -r '.type')
dbDriverLocation=$(echo $dbConfig | jq -r '.driverLocation')
dbApplySchedulerConfigToALL=$(echo $dbConfig | jq -r '.applySchedulerConfigToALL')
dbSchedulerHostname=$(echo $dbConfig | jq -r '.schedulerDbConfig.hostname')
dbSchedulerPort=$(echo $dbConfig | jq -r '.schedulerDbConfig.port')
dbSchedulerUsername=$(echo $dbConfig | jq -r '.schedulerDbConfig.username')
dbSchedulerPassword=$(echo $dbConfig | jq -r '.schedulerDbConfig.password')
dbSchedulerDialect=$(echo $dbConfig | jq -r '.schedulerDbConfig.dialect')
dbSchedulerSchemaName=$(echo $dbConfig | jq -r '.schedulerDbConfig.schemaName')
dbSchedulerUrl=$(echo $dbConfig | jq -r '.schedulerDbConfig.url')
dbRmHostname=$(echo $dbConfig | jq -r '.rmDbConfig.hostname')
dbRmPort=$(echo $dbConfig | jq -r '.rmDbConfig.port')
dbRmUsername=$(echo $dbConfig | jq -r '.rmDbConfig.username')
dbRmPassword=$(echo $dbConfig | jq -r '.rmDbConfig.password')
dbRmDialect=$(echo $dbConfig | jq -r '.rmDbConfig.dialect')
dbRmSchemaName=$(echo $dbConfig | jq -r '.rmDbConfig.schemaName')
dbRmUrl=$(echo $dbConfig | jq -r '.rmDbConfig.url')
dbCatalogHostname=$(echo $dbConfig | jq -r '.catalogDbConfig.hostname')
dbCatalogPort=$(echo $dbConfig | jq -r '.catalogDbConfig.port')
dbCatalogUsername=$(echo $dbConfig | jq -r '.catalogDbConfig.username')
dbCatalogPassword=$(echo $dbConfig | jq -r '.catalogDbConfig.password')
dbCatalogDialect=$(echo $dbConfig | jq -r '.catalogDbConfig.dialect')
dbCatalogSchemaName=$(echo $dbConfig | jq -r '.catalogDbConfig.schemaName')
dbCatalogUrl=$(echo $dbConfig | jq -r '.catalogDbConfig.url')
dbPsaHostname=$(echo $dbConfig | jq -r '.psaDbConfig.hostname')
dbPsaPort=$(echo $dbConfig | jq -r '.psaDbConfig.port')
dbPsaUsername=$(echo $dbConfig | jq -r '.psaDbConfig.username')
dbPsaPassword=$(echo $dbConfig | jq -r '.psaDbConfig.password')
dbPsaDialect=$(echo $dbConfig | jq -r '.psaDbConfig.dialect')
dbPsaSchemaName=$(echo $dbConfig | jq -r '.psaDbConfig.schemaName')
dbPsaUrl=$(echo $dbConfig | jq -r '.psaDbConfig.url')
dbNotificationHostname=$(echo $dbConfig | jq -r '.notificationDbConfig.hostname')
dbNotificationPort=$(echo $dbConfig | jq -r '.notificationDbConfig.port')
dbNotificationUsername=$(echo $dbConfig | jq -r '.notificationDbConfig.username')
dbNotificationPassword=$(echo $dbConfig | jq -r '.notificationDbConfig.password')
dbNotificationDialect=$(echo $dbConfig | jq -r '.notificationDbConfig.dialect')
dbNotificationSchemaName=$(echo $dbConfig | jq -r '.notificationDbConfig.schemaName')
dbNotificationUrl=$(echo $dbConfig | jq -r '.notificationDbConfig.url')

dbSchedulerPasswordDecrypted=$(echo $dbSchedulerPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)
dbRmPasswordDecrypted=$(echo $dbRmPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)
dbCatalogPasswordDecrypted=$(echo $dbCatalogPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)
dbPsaPasswordDecrypted=$(echo $dbPsaPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)
dbNotificationPasswordDecrypted=$(echo $dbNotificationPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)

log_print INFO "Installing the required libraries..."
for i in ${libraries//,/ }; do
  log_print INFO "Installing $i..."
  $PKG_TOOL -y install $i
done

log_print INFO "Stopping the ProActive service and remove old installation if it exists..."
if [ -f /etc/init.d/proactive-scheduler ]; then
  service proactive-scheduler stop
fi
rm -rf $installationDirectory
mkdir -p $installationDirectory

if [[ $archiveLocation == http* ]]; then
  log_print INFO "Downloading the ProActive Server archive..."
  cd /tmp && {
    curl -k -o proactive.zip $archiveLocation
    cd - >/dev/null
  }
  archiveLocation="/tmp/proactive.zip"
fi

log_print INFO "Unzipping the ProActive archive..."
unzip -q $archiveLocation -d $installationDirectory

log_print INFO "Creating default symbolic link..."
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

configure_db() {
  dbArgs="-c $1 -v $2"
  hostname=$3
  port=$4
  username=$5
  password=$6
  dialect=$7
  schemaName=$8
  url=$9

  if [ "$url" == "default" ]; then
    dbArgs=$dbArgs" -H $hostname -P $port -u $username -p $password"
  else
    dbArgs=$dbArgs" -U $url -u $username -p $password"
  fi
  if [ "$dialect" != "default" ]; then
    dbArgs=$dbArgs" -D $dialect"
  fi
  if [ "$schemaName" != "default" ] && [ "$1" != "all" ] && [ "$2" != "hsqldb" ]; then
    dbArgs=$dbArgs" -s $schemaName"
  fi

  $PROACTIVE_DEFAULT/tools/configure-db $dbArgs
}

if [ "$enableCustomDbConfig" == "true" ]; then
  log_print INFO "Configuring the external database..."
  log_print INFO "Downloading the database driver..."
  if [[ $dbDriverLocation == http* ]]; then
    downloaded=false
    while [ "$downloaded" = false ]; do
      log_print INFO "Downloading file..."
      export OLDPWD=$PWD
      cd "$PROACTIVE_DEFAULT/addons"
      curl -k -J -LO "$dbDriverLocation"
      if [ $? -eq 0 ]; then
        downloaded=true
        log_print INFO "File downloaded successfully."
      else
        log_print INFO "Download failed. Retrying in 5 seconds..."
        sleep 5
      fi
    done
    cd - >/dev/null
  else
    mv $dbDriverLocation "$PROACTIVE_DEFAULT/addons"
  fi

  log_print INFO "Applying the custom database configuration..."
  declare -a databases=("scheduler" "rm" "catalog" "service-automation" "notification")
  if [[ $dbApplySchedulerConfigToALL == "false" ]]; then
    for db in "${databases[@]}"; do
      if [[ $db == "scheduler" ]]; then
        configure_db $db $dbType $dbSchedulerHostname $dbSchedulerPort $dbSchedulerUsername $dbSchedulerPasswordDecrypted $dbSchedulerDialect $dbSchedulerSchemaName $dbSchedulerUrl
      fi
      if [[ $db == "rm" ]]; then
        configure_db $db $dbType $dbRmHostname $dbRmPort $dbRmUsername $dbRmPasswordDecrypted $dbRmDialect $dbRmSchemaName $dbRmUrl
      fi
      if [[ $db == "catalog" ]]; then
        configure_db $db $dbType $dbCatalogHostname $dbCatalogPort $dbCatalogUsername $dbCatalogPasswordDecrypted $dbCatalogDialect $dbCatalogSchemaName $dbCatalogUrl
      fi
      if [[ $db == "service-automation" ]]; then
        configure_db $db $dbType $dbPsaHostname $dbPsaPort $dbPsaUsername $dbPsaPasswordDecrypted $dbPsaDialect $dbPsaSchemaName $dbPsaUrl
      fi
      if [[ $db == "notification" ]]; then
        configure_db $db $dbType $dbNotificationHostname $dbNotificationPort $dbNotificationUsername $dbNotificationPasswordDecrypted $dbNotificationDialect $dbNotificationSchemaName $dbNotificationUrl
      fi
    done
  else
    configure_db "all" $dbType $dbSchedulerHostname $dbSchedulerPort $dbSchedulerUsername $dbSchedulerPasswordDecrypted $dbSchedulerDialect $dbSchedulerSchemaName $dbSchedulerUrl
  fi
fi

if [ "$enableLdapConfiguration" == "true" ]; then
  log_print INFO "Configuring LDAP authentication..."

  $PROACTIVE_DEFAULT/tools/configure-ldap -u "$serverUrls" --user.subtree "$userSubtree" --group.subtree "$groupSubtree" -l "$bindLogin" -p "$bindPasswordDecrypted" --user.filter "$userFilter" --group.filter "$groupFilter" --test.user "$testLogin" --test.pwd "$testPasswordDecrypted" -d
  if [ $? -eq 0 ]; then
    log_print INFO "The LDAP Configuration is successful ..."
  else
    log_print ERROR "The LDAP Configuration failed..."
    exit 1
  fi

  IFS=',' read -ra userRolesArray <<<"$userRoles"
  for userRole in "${userRolesArray[@]}"; do
    $PROACTIVE_DEFAULT/tools/copy-role -S "user" -D "$userRole" -y
  done
  IFS=',' read -ra adminRolesArray <<<"$adminRoles"
  for adminRole in "${adminRolesArray[@]}"; do
    $PROACTIVE_DEFAULT/tools/copy-role -S "server-admins" -D "$adminRole" -y
  done
fi

log_print INFO "Configuring the Network protocol..."
sed -i "s#^\(proactive\.communication\.protocol\s*=\s*\).*#\1${networkProtocol}#" $PROACTIVE_DEFAULT/config/network/server.ini

log_print INFO "Configuring the Web protocol and ports to be used..."
if [[ "${webProtocol}" == "https" ]]; then
  mkdir $PROACTIVE_DEFAULT/keystore

  log_print INFO "Configuring the certificate..."
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

log_print INFO "Configuring ProActive server public URLs..."
sed -e "s/#$(escape_lhs_sed sched.novnc.url=http\\://localhost\\:5900)/sched.novnc.url=$(escape_rhs_sed $webProtocol\\://$serverDNSName\\:5900)/g" -i "$PROACTIVE_DEFAULT/dist/war/scheduler/scheduler.conf"
sed -e "s/#$(escape_lhs_sed sched.novnc.page.url=http\\://localhost\\:8080/rest/novnc.html)/sched.novnc.page.url=$(escape_rhs_sed $webProtocol\\://$serverDNSName\\:$webPort/rest/novnc.html)/g" -i "$PROACTIVE_DEFAULT/dist/war/scheduler/scheduler.conf"
sed -e "s/# $(escape_lhs_sed novnc.url=)/novnc.url=$(escape_rhs_sed $webProtocol://$serverDNSName:5900)/g" -i "$PROACTIVE_DEFAULT/config/web/settings.ini"

sed -e "s/$(escape_lhs_sed http://localhost:8080)/$(escape_rhs_sed ${webProtocol}://$serverDNSName:${webPort})/g" -i "$PROACTIVE_DEFAULT/config/web/settings.ini"
sed -e "s/$(escape_lhs_sed http://localhost:8080)/$(escape_rhs_sed ${webProtocol}://$serverDNSName:${webPort})/g" -i "$PROACTIVE_DEFAULT/dist/war/rm/rm.conf"
sed -e "s/$(escape_lhs_sed http://localhost:8080)/$(escape_rhs_sed ${webProtocol}://$serverDNSName:${webPort})/g" -i "$PROACTIVE_DEFAULT/dist/war/scheduler/scheduler.conf"

sed -e "s/#$(escape_lhs_sed pa.scheduler.rest.public.url=)/pa.scheduler.rest.public.url=$(escape_rhs_sed ${webProtocol}://$serverDNSName:${webPort}/rest)/g" -i "$PROACTIVE_DEFAULT/config/scheduler/settings.ini"
sed -e "s/#$(escape_lhs_sed pa.catalog.rest.public.url=)/pa.catalog.rest.public.url=$(escape_rhs_sed ${webProtocol}://$serverDNSName:${webPort}/catalog)/g" -i "$PROACTIVE_DEFAULT/config/scheduler/settings.ini"
sed -e "s/#$(escape_lhs_sed pa.cloud-automation.rest.public.url=)/pa.cloud-automation.rest.public.url=$(escape_rhs_sed ${webProtocol}://$serverDNSName:${webPort}/cloud-automation-service)/g" -i "$PROACTIVE_DEFAULT/config/scheduler/settings.ini"

log_print INFO "Configuring the ProActive housekeeping mechanism..."
JOB_CLEANUP_DAYS=$historyPeriodDays
JOB_CLEANUP_SECONDS=$((JOB_CLEANUP_DAYS * 24 * 3600))
sed -e "s/pa\.scheduler\.core\.automaticremovejobdelay=.*/pa.scheduler.core.automaticremovejobdelay=$JOB_CLEANUP_SECONDS/g" -i "$PROACTIVE_DEFAULT/config/scheduler/settings.ini"
sed -e "s/pa\.scheduler\.job\.removeFromDataBase=.*/pa.scheduler.job.removeFromDataBase=true/g" -i "$PROACTIVE_DEFAULT/config/scheduler/settings.ini"
sed -e "s/^#pa\.rm\.history\.maxperiod=.*/pa.rm.history.maxperiod=$JOB_CLEANUP_SECONDS/g" -i "$PROACTIVE_DEFAULT/config/rm/settings.ini"
sed -e "s/^notifications\.housekeeping\.removedelay=.*/notifications.housekeeping.removedelay=$JOB_CLEANUP_SECONDS/g" -i "$PROACTIVE_DEFAULT/dist/war/notification-service/WEB-INF/classes/application.properties"
sed -e "s/^#pa\.job\.execution\.history\.maxperiod=.*/pa.job.execution.history.maxperiod=$JOB_CLEANUP_SECONDS/g" -i "$PROACTIVE_DEFAULT/dist/war/job-planner/WEB-INF/classes/application.properties"

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

log_print INFO "Generating new Private/Public key pair for the scheduler..."
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

log_print INFO "Updating node jars..."
update_node_jars

log_print INFO "Configuring the watcher account..."
sed -e "s/scheduler\.cache\.password=.*/scheduler.cache.password=/g" -i "${PROACTIVE_DEFAULT}/config/web/settings.ini"
sed -e "s/^.*scheduler\.cache\.credential=.*$/scheduler.cache.credential=$(escape_rhs_sed $AUTH_ROOT/watcher.cred)/g" -i "${PROACTIVE_DEFAULT}/config/web/settings.ini"
sed -e "s/rm\.cache\.password=.*/rm.cache.password=/g" -i "${PROACTIVE_DEFAULT}/config/web/settings.ini"
sed -e "s/^.*rm\.cache\.credential=.*$/rm.cache.credential=$(escape_rhs_sed $AUTH_ROOT/watcher.cred)/g" -i "${PROACTIVE_DEFAULT}/config/web/settings.ini"
sed -e "s/^.*listeners\.pwd=.*$/listeners.pwd=$(escape_rhs_sed $WATCHER_PWD)/g" -i "${PROACTIVE_DEFAULT}/dist/war/notification-service/WEB-INF/classes/application.properties"

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
if id "$systemUser" &>/dev/null; then
  log_print INFO "The given user already exists."
else
  groupadd $systemUserGroup
  useradd $systemUser -d $installationDirectory -g $systemUserGroup
  echo "$systemUser:$systemUserPasswordDecrypted" | chpasswd
fi

log_print INFO "Chowning all Server files with provided user/group..."
chown "$systemUser:$systemUserGroup" $installationDirectory
chown -R "$systemUser:$systemUserGroup" $PROACTIVE_DEFAULT/

log_print INFO "Installing the 'proactive-scheduler' service..."
sed -e "s/^USER=.*/USER=$systemUser/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
sed -e "s/^PROTOCOL=.*/PROTOCOL=$webProtocol/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
sed -e "s/^PORT=.*/PORT=$webPort/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
sed -e "s/^NB_NODES=.*/NB_NODES=$localNodes/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
sed -e "s/^PA_ROOT=.*/PA_ROOT=$(escape_rhs_sed "$installationDirectory")/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"

if [ "$localNodes" != "0" ]; then
  sed -e "s/^SINGLE_JVM=.*/SINGLE_JVM=true/g" -i "${PROACTIVE_DEFAULT}/tools/proactive-scheduler"
fi

if [[ "$webPort" -lt "1024" ]]; then
  if ! which setcap >/dev/null 2>&1; then
    log_print INFO "libcap2 is not installed on this computer and is required to start the server on a port below 1024."
    if [[ "$OS" == "RedHat" ]]; then
      $PKG_TOOL -y install libcap2
    elif [[ "$OS" == "Debian" ]]; then
      $PKG_TOOL -y install libcap2-bin
    fi
  fi
  log_print INFO "Enabling privilege to run server on port lower than 1024..."

  echo "${PROACTIVE_DEFAULT}/jre/lib/amd64/jli" >/etc/ld.so.conf.d/proactive-java.conf
  ldconfig | grep libjli
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

log_print INFO "Starting the ProActive Server..."
log_print INFO "If a problem occurs, check output in /var/log/proactive/scheduler."
service proactive-scheduler start

log_print INFO "Waiting for the ProActive Server to be up before adding Node Sources..."
until curl -s --insecure --head --request GET $webProtocol://$serverDNSName:$webPort | grep "200 OK" >/dev/null; do
  sleep 5
done

log_print INFO "ProActive Server started at: $webProtocol://$serverDNSName:$webPort"

if [ "$addExternalNodeSources" == "true" ]; then

  log_print INFO "Adding Node Sources..."
  nodesConfig=$(cat inputConfig.json | jq '.nodesConfiguration')
  numberOfNodeSources=$(echo $nodesConfig | jq '. | length')

  for ((i = 0; i < $numberOfNodeSources; i++)); do
    rm -f /tmp/hostlist.txt 2>/dev/null

    nodeConfig=$(cat inputConfig.json | jq -r '.nodesConfiguration['$i']')
    nodeName=$(echo $nodeConfig | jq -r '.name')
    nodeType=$(echo $nodeConfig | jq -r '.type')
    nodeServerAddress=$(echo $nodeConfig | jq -r '.serverAddress')
    nodePortRange=$(echo $nodeConfig | jq -r '.portRange')
    nodeOsFamily=$(echo $nodeConfig | jq -r '.osFamily')
    nodeSshUserName=$(echo $nodeConfig | jq -r '.sshUserName')
    nodeSshUserGroup=$(echo $nodeConfig | jq -r '.sshUserGroup')
    nodeSshPassword=$(echo $nodeConfig | jq -r '.sshPassword')
    nodeSshPasswordDecrypted=$(echo $nodeSshPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)
    nodeSshUserHomeDir=$(echo $nodeConfig | jq -r '.sshUserHomeDir')
    nodeSudoUser=$(echo $nodeConfig | jq -r '.sudoUser')
    nodeSudoUserPassword=$(echo $nodeConfig | jq -r '.sudoUserPassword')
    nodeSudoUserPasswordDecrypted=$(echo $nodeSudoUserPassword | base64 -d | gpg -d --batch --passphrase "$passphrase" --ignore-crc-error --ignore-mdc-error 2>/dev/null)
    nodeInstallAllDependencies=$(echo $nodeConfig | jq -r '.installAllDependencies')
    nodeLibraries=$(echo $nodeConfig | jq -r '.libraries')
    nodePython3Modules=$(echo $nodeConfig | jq -r '.python3Modules')
    nodeAdditionalInstallationCommand=$(echo $nodeConfig | jq -r '.additionalInstallationCommand')

    log_print INFO "Setting up the linux packaging system on the Node machine..."
    NODE_PKG_TOOL=""
    if [ "$nodeOsFamily" == "debian" ]; then
      NODE_PKG_TOOL="apt-get"
    elif [ "$nodeOsFamily" == "redhat" ]; then
      NODE_PKG_TOOL="dnf"
    elif [ "$nodeOsFamily" == "centos" ]; then
      NODE_PKG_TOOL="yum"
    else
      log_print ERROR "The operating system of the node machine is not supported by the ProActive installation script."
      exit 1
    fi

    hostsConfig=$(echo $nodeConfig | jq '.hosts')
    numberOfHosts=$(echo $hostsConfig | jq '. | length')

    if [ "$nodeType" == "SSHV2-pamrssh" ]; then
      log_print INFO "Generating SSH key pairs..."
      mkdir -p "$installationDirectory"/.ssh
      ssh-keygen -q -f "$installationDirectory/.ssh/id_rsa" -N "" <<<y >/dev/null 2>&1
      cat "$installationDirectory"/.ssh/id_rsa.pub >"$installationDirectory"/.ssh/authorized_keys
      chmod 644 "$installationDirectory"/.ssh/id_rsa.pub
      chmod 600 "$installationDirectory"/.ssh/authorized_keys
      chown -R "$systemUser:$systemUserGroup" "$installationDirectory"/.ssh
    fi

    if [ "$nodeServerAddress" == "default" ]; then
      nodeServerAddress=$serverDNSName
    fi

    for ((j = 0; j < $numberOfHosts; j++)); do
      hostnameOrIpAddress=$(echo $hostsConfig | jq -r '.['$j'].hostnameOrIpAddress')
      nodesNumber=$(echo $hostsConfig | jq -r '.['$j'].nodesNumber')
      echo "$hostnameOrIpAddress $nodesNumber" >>/tmp/hostlist.txt

      log_print INFO "Installing the desired libraries on the Node machine..."
      sshpass -p $nodeSudoUserPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSudoUser@$hostnameOrIpAddress "sudo $NODE_PKG_TOOL -y update"

      for k in ${nodeLibraries//,/ }; do
        sshpass -p $nodeSudoUserPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSudoUser@$hostnameOrIpAddress "sudo $NODE_PKG_TOOL -y install $k"
      done

      log_print INFO "Installing python3Modules..."
      sshpass -p $nodeSudoUserPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSudoUser@$hostnameOrIpAddress "sudo -H pip3 install $nodePython3Modules"

      log_print INFO "Running additional installation commands..."
      sshpass -p $nodeSudoUserPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSudoUser@$hostnameOrIpAddress "sudo $nodeAdditionalInstallationCommand"

      if [ "$nodeInstallAllDependencies" == "true" ]; then
        log_print INFO "Install all needed dependencies..."
        sshpass -p $nodeSudoUserPasswordDecrypted scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no install-dependencies-debian.sh $nodeSudoUser@$hostnameOrIpAddress:/tmp/
        sshpass -p $nodeSudoUserPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSudoUser@$hostnameOrIpAddress "sudo chmod +x /tmp/install-dependencies-debian.sh; sudo /tmp/install-dependencies-debian.sh -sv"
      fi

      if [ "$nodeType" == "SSHV2-pamrssh" ]; then
        log_print INFO "Copying the private and public keys to the Node machines..."
        sshpass -p $nodeSudoUserPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSudoUser@$hostnameOrIpAddress "id '$nodeSshUserName'"
        if [ $? -eq 0 ]; then
          log_print INFO "The given user already exists."
        else
          sshpass -p $nodeSudoUserPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSudoUser@$hostnameOrIpAddress "sudo groupadd '$nodeSshUserGroup'"
          sshpass -p $nodeSudoUserPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSudoUser@$hostnameOrIpAddress "sudo useradd -m -d '$nodeSshUserHomeDir' '$nodeSshUserName' -g '$nodeSshUserGroup'"
          sshpass -p $nodeSudoUserPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSudoUser@$hostnameOrIpAddress "sudo echo '$nodeSshUserName:$nodeSshPasswordDecrypted' | sudo chpasswd"
        fi
        sshpass -p $nodeSshPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSshUserName@$hostnameOrIpAddress "rm -rf $nodeSshUserHomeDir/ssh; mkdir -p $nodeSshUserHomeDir/ssh"
        sshpass -p $nodeSshPasswordDecrypted scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$installationDirectory"/.ssh/id_rsa $nodeSshUserName@$hostnameOrIpAddress:"$nodeSshUserHomeDir"/ssh/
        sshpass -p $nodeSshPasswordDecrypted scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$installationDirectory"/.ssh/id_rsa.pub $nodeSshUserName@$hostnameOrIpAddress:"$nodeSshUserHomeDir"/ssh/
        sshpass -p $nodeSudoUserPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSudoUser@$hostnameOrIpAddress "sudo chown -R $nodeSshUserName: $nodeSshUserHomeDir"
        sshpass -p $nodeSshPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSshUserName@$hostnameOrIpAddress "chmod 600 $nodeSshUserHomeDir/ssh/id_rsa"
        sshpass -p $nodeSshPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSshUserName@$hostnameOrIpAddress "chmod 644 $nodeSshUserHomeDir/ssh/id_rsa.pub"
      fi
    done

    log_print INFO "Adding the Node Sources..."
    if [ "$nodeType" == "SSHV2-pamr" ]; then
      su "$systemUser" -c "${PROACTIVE_DEFAULT}/bin/proactive-client -k -u $webProtocol://$serverDNSName:$webPort/rest/ -l admin -p $proactiveAdminPasswordDecrypted --createns $nodeName -infrastructure org.ow2.proactive.resourcemanager.nodesource.infrastructure.SSHInfrastructureV2 /tmp/hostlist.txt 60000 5 5000 22 '$nodeSshUserName' '$nodeSshPasswordDecrypted' '' '' '' '' 'Linux' '-Dproactive.net.nolocal=true -Dproactive.communication.protocol=$networkProtocol -Dproactive.useIPaddress=true  -Dproactive.pamr.router.address=$nodeServerAddress' 'useNodeJarStartupScript' '$webProtocol://$serverDNSName:$webPort/rest/node.jar' '' 'rm -rf /tmp/node && mkdir -p /tmp/node && cd /tmp/node; if ! type -p jre/bin/java; then wget -nv -N https://s3.amazonaws.com/ci-materials/Latest_jre/jre-8u312b07-linux-x64.tar.gz; tar -xf jre-8u312b07-linux-x64.tar.gz; mv jre1.8.0_312b07/ jre; fi; wget --no-check-certificate -nv -O node.jar %nodeJarUrl%; rm -rf lib; %detachedModePrefix% jre/bin/java -jar node.jar %javaOptions% -Dpython.path=%jythonPath% -r %rmUrl% -n %nodeName% -s %nodeSourceName% -w %numberOfNodesPerInstance% -v %credentials% &' -policy org.ow2.proactive.resourcemanager.nodesource.policy.RestartDownNodesPolicy 'ALL' 'ME' '1800000' -X"
      log_print INFO "Node Source '$nodeName' successfully created"
    fi

    if [ "$nodeType" == "SSHV2-pamrssh" ]; then
      su "$systemUser" -c "${PROACTIVE_DEFAULT}/bin/proactive-client -k -u $webProtocol://$serverDNSName:$webPort/rest/ -l admin -p $proactiveAdminPasswordDecrypted --createns $nodeName -infrastructure org.ow2.proactive.resourcemanager.nodesource.infrastructure.SSHInfrastructureV2 /tmp/hostlist.txt 60000 5 5000 22 '$nodeSshUserName' '$nodeSshPasswordDecrypted' '' '' '' '' 'Linux' '-Dproactive.net.nolocal=true -Dproactive.communication.protocol=$networkProtocol -Dproactive.useIPaddress=true  -Dproactive.pamr.router.address=$nodeServerAddress -Dproactive.pamrssh.key_directory=$nodeSshUserHomeDir/ssh -Djava.net.preferIPv4Stack=true -Dproactive.pamr.socketfactory=ssh -Dproactive.pamrssh.username=$nodeSshUserName' 'useNodeJarStartupScript' '$webProtocol://$serverDNSName:$webPort/rest/node.jar' '' 'rm -rf /tmp/node && mkdir -p /tmp/node && cd /tmp/node; if ! type -p jre/bin/java; then wget -nv -N https://s3.amazonaws.com/ci-materials/Latest_jre/jre-8u312b07-linux-x64.tar.gz; tar -xf jre-8u312b07-linux-x64.tar.gz; mv jre1.8.0_312b07/ jre; fi; wget --no-check-certificate -nv -O node.jar %nodeJarUrl%; rm -rf lib; %detachedModePrefix% jre/bin/java -jar node.jar %javaOptions% -Dpython.path=%jythonPath% -r %rmUrl% -n %nodeName% -s %nodeSourceName% -w %numberOfNodesPerInstance% -v %credentials% &' -policy org.ow2.proactive.resourcemanager.nodesource.policy.RestartDownNodesPolicy 'ALL' 'ME' '1800000' -X"
      log_print INFO "Node Source '$nodeName' successfully created"
    fi

    if [ ! -z "${nodePortRange}" ]; then
      log_print INFO "Configuring services port range on target nodes..."
      for ((j = 0; j < $numberOfHosts; j++)); do
        hostnameOrIpAddress=$(echo $hostsConfig | jq -r '.['$j'].hostnameOrIpAddress')
        IFS=- read -r portMin portMax <<<$nodePortRange
        sshpass -p $nodeSshPasswordDecrypted ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no $nodeSshUserName@$hostnameOrIpAddress "mkdir /tmp/node/config; echo '$portMin	$portMax' > /tmp/node/config/pca_services_port_range"
      done
    fi

  done
fi

log_print INFO "Running Api Health check tests..."
chmod +x apiHealthcheck.sh
./apiHealthcheck.sh
