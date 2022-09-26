#!/bin/bash
#set -x

#input parameters
#username to connect to the ProActive Portals
username=changeme
#password of the user connecting to the ProActive Portals
proactiveAdminPasswordDecrypted=changeme
#server DNS name or public IP
serverDNSName=try.activeeon.com
#server Port
webPort=8443
#web protocol, http or https
webProtocol=https
#name of one of the node sources, needed in a test to get its description
nsName=local

#set colors for printf state of services
RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'
PURPLE='\033[0;35m'

#number of failed tests
FAIL=0
#number of successful tests
SUCCESS=0

#complete ProActive server web URL
URL="${webProtocol}://${serverDNSName}:${webPort}"

#function used by tests to check the returned status and print messages
check_endpoint() {
  endpoint=$1
  message=$2
  if [ "$endpoint" == "200" ]; then
    echo -e "${GREEN} OK ${message}"
    ((SUCCESS++))
  else
    echo -e "${RED} NOK ${message}"
    ((FAIL++))
  fi
}

#get the session id, needed for all tests
endpoint=$(curl -o - -d "username=${username}&password=${proactiveAdminPasswordDecrypted}" --write-out "\n%{http_code}\n" --silent --output /dev/null ${URL}/rest/scheduler/login)
response=($endpoint)
sessionid=${response[0]}
status=${response[1]}
message="$NC: ${PURPLE}(POST: scheduler/login)$NC GET A SESSION ID"
if [ "$status" == "200" ]; then
  ((SUCCESS++))
  echo -e "${GREEN} OK $message"
else
  echo -e "${RED} NOK $message"
  ((FAIL++))
  #exit the script if the session id could not be retrieved since it is required by most of the tests
  exit 1
fi

#wait until a node becomes free before starting the tests
nodeState=""
until [[ $nodeState == "FREE" ]]; do
  monitoring=$(curl -G --header "sessionid:$sessionid" --silent "$URL/rest/rm/monitoring/")
  nodeEvent=$(echo $monitoring | jq -r '.nodesEvents[0]')
  nodeState=$(echo $nodeEvent | jq -r '.nodeState')
done

#wait until the basic-exmaples are loaded, to submit a job for test
jobid=""
until [[ (! -z $jobid) && ($jobid != "null") ]]; do
  endpoint=$(curl -X POST -H "link:$URL/catalog/buckets/basic-examples/resources/Native_Task/raw" --silent -H "sessionid:$sessionid" "$URL/rest/scheduler/jobs")
  jobid=$(echo $endpoint | jq -r '.id')
done
message="$NC: ${PURPLE}(POST: scheduler/jobs)$NC SUBMIT A JOB"
check_endpoint 200 "$message"

#wait until the submitted job reaches the FINISHED state
status=""
until [[ $status == "FINISHED" ]]; do
  endpoint=$(curl -G --header "sessionid:$sessionid" --silent "$URL/rest/scheduler/jobs/$jobid/")
  status=$(echo $endpoint | jq -r '.jobInfo.status')
done

#start calling ProActive GET endpoints
endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/data/global/assets.txt")
message="$NC: ${PURPLE}(GET: data/dataspace/path-name:.*/)$NC RETRIEVES SINGLE OR MULTIPLE FILES FROM SPECIFIED LOCATION OF THE SERVER"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/common/connected/")
message="$NC: ${PURPLE}(GET: common/connected/)$NC TESTS WHETHER THE SESSION IS CONNECTED TO THE PROACTIVE SERVER"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/common/currentuser/")
message="$NC: ${PURPLE}(GET: common/currentuser/)$NC GET THE LOGIN STRING ASSOCIATED TO A SESSION"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/common/currentuserdata/")
message="$NC: ${PURPLE}(GET: common/currentuserdata/)$NC GET A USERDATA OBJECT ASSOCIATED TO A SESSION"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d 'name=hsqldb.db' --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/common/logger/")
message="$NC: ${PURPLE}(GET: common/logger/)$NC GET LOGGER LEVEL"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/common/logger/current/")
message="$NC: ${PURPLE}(GET: common/logger/current/)$NC GET THE STATE OF CURRENT LOGGERS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/common/permissions/cloud-automation-service/admin/")
message="$NC: ${PURPLE}(GET: common/permissions/cloud-automation-service/admin/)$NC CHECK IF A USER HAS ADMIN PRIVILEGE IN CLOUD AUTOMATION SERVICE"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/common/permissions/notification-service/admin/")
message="$NC: ${PURPLE}(GET: common/permissions/notification-service/admin/)$NC CHECK IF A USER HAS ADMIN PRIVILEGE IN NOTIFICATION SERVICE"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d 'portals=rm,studio' --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/common/permissions/portals/")
message="$NC: ${PURPLE}(GET: common/permissions/portals/)$NC CHECK MULTIPLE PORTALS ACCESSES"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/common/permissions/portals/rm/")
message="$NC: ${PURPLE}(GET: common/permissions/portals/portal/)$NC CHECK SINGLE PORTAL ACCESS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rm/")
message="$NC: ${PURPLE}(GET: rm/)$NC CHECK IF RM IS UP"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/isactive/")
message="$NC: ${PURPLE}(GET: rm/isactive/)$NC CHECK RESOURCE MANAGER AVAILABILITY"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/policies/")
message="$NC: ${PURPLE}(GET: rm/policies/)$NC RETURNS THE LIST OF SUPPORTED NODE SOURCE POLICIES DESCRIPTORS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/state/")
message="$NC: ${PURPLE}(GET: rm/state/)$NC MINIMAL STATE OF THE RESOURCE MANAGER"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "range=a&fucntion=MIN" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/stathistory/")
message="$NC: ${PURPLE}(GET: rm/stathistory/)$NC STATISTICS HISTORY"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/threaddump/")
message="$NC: ${PURPLE}(GET: rm/threaddump/)$NC RESOURCE MANAGER THREAD DUMP"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/topology/")
message="$NC: ${PURPLE}(GET: rm/topology/)$NC RM TOPOLOGY"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/url/")
message="$NC: ${PURPLE}(GET: rm/url/)$NC RM SERVER URL"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/version/")
message="$NC: ${PURPLE}(GET: rm/version/)$NC RETURNS THE VERSION OF THE REST API"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/infrastructures/")
message="$NC: ${PURPLE}(GET: rm/infrastructures/)$NC SUPPORTED INFRASTRUCTURES LIST"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/infrastructures/mapping/")
message="$NC: ${PURPLE}(GET: rm/infrastructures/mapping/)$NC SUPPORTED INFRASTRUCTURES MAPPING TO POLICIES"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/logins/sessionid/$sessionid")
message="$NC: ${PURPLE}(GET: rm/logins/sessionid/sessionId/)$NC GET LOGIN OF A SESSION"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/logins/sessionid/$sessionid/userdata/")
message="$NC: ${PURPLE}(GET: rm/logins/sessionid/sessionId/userdata/)$NC GET USER DATA OF A SESSION"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/model/hosts/")
message="$NC: ${PURPLE}(GET: rm/model/hosts/)$NC LIST OF REGISTERED NODE HOSTS AS VARIABLE MODEL"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/model/nodesources/")
message="$NC: ${PURPLE}(GET: rm/model/nodesources/)$NC LIST OF NODE SOURCES AS VARIABLE MODEL"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/model/tokens/")
message="$NC: ${PURPLE}(GET: rm/model/tokens/)$NC LIST OF REGISTERED TOKENS AS VARIABLE MODEL"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/monitoring/")
message="$NC: ${PURPLE}(GET: rm/monitoring/)$NC DELTA STATE OF RESOURCE MANAGER"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/monitoring/full/")
message="$NC: ${PURPLE}(GET: rm/monitoring/full/)$NC FULL STATE OF THE RESOURCE MANAGER"
check_endpoint "$endpoint" "$message"

monitoring=$(curl -G --header "sessionid:$sessionid" --silent "$URL/rest/rm/monitoring/")
nodeEvent=$(echo $monitoring | jq -r '.nodesEvents[0]')
nodeUrl=$(echo $nodeEvent | jq -r '.nodeUrl')

endpoint=$(curl -G -d "nodeurl=$nodeUrl" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/node/isavailable/")
message="$NC: ${PURPLE}(GET: rm/node/isavailable/)$NC CHECK NODE AVAILABILITY"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "nodeurl=$nodeUrl" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/node/threaddump/")
message="$NC: ${PURPLE}(GET: rm/node/threaddump/)$NC NODE THREAD DUMP"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "nodeurl=$nodeUrl" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/node/tags/search/")
message="$NC: ${PURPLE}(GET: rm/node/tags/search/)$NC GET THE TAGS OF A SPECIFIC NODE"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/node/tags/")
message="$NC: ${PURPLE}(GET: rm/node/tags/)$NC GET THE SET OF ALL TAGS PRESENT IN ALL NODES"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "windowStart:1631755921000" --header "windowEnd:1694827921000" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/nodes/history/")
message="$NC: ${PURPLE}(GET: rm/nodes/history/)$NC GET USAGE HISTORY FOR ALL NODES"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "all=false" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/nodes/search/")
message="$NC: ${PURPLE}(GET: rm/nodes/search/)$NC SEARCH THE NODES WITH SPECIFIC TAGS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/nodesource/")
message="$NC: ${PURPLE}(GET: rm/nodesource/)$NC LIST EXISTING NODE SOURCES"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "nodeSourceName=$nsName" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/rm/nodesource/configuration/")
message="$NC: ${PURPLE}(GET: rm/nodesource/configuration/)$NC GET NODE SOURCE CONFIGURATION"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/scheduler/")
message="$NC: ${PURPLE}(GET: scheduler/)$NC CHECK IF SCHEDULER IS UP"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/configuration/portal/")
message="$NC: ${PURPLE}(GET: scheduler/configuration/portal/)$NC GET PORTAL CONFIGURATION PROPERTIES"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/dataspace/global/assets.txt")
message="$NC: ${PURPLE}(GET: scheduler/dataspace/global/assets.txt)$NC THE CONTENT OF THE FILE WILL BE RETURNED AS AN INPUT STREAM"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/globalspace/")
message="$NC: ${PURPLE}(GET: scheduler/globalspace/)$NC DISPLAY THE GLOBAL SPACE CONTENT"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/isconnected/")
message="$NC: ${PURPLE}(GET: scheduler/isconnected/)$NC TESTS WHETHER OR NOT THE USER IS CONNECTED TO THE SERVER"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobsinfo/")
message="$NC: ${PURPLE}(GET: scheduler/jobsinfo/)$NC RETURNS A SUBSET OF THE SCHEDULER STATE"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "jobsid=$jobid" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobsinfolist/")
message="$NC: ${PURPLE}(GET: scheduler/jobsinfolist/)$NC RETURNS A LIST OF JOBS INFO CORRESPONDING TO THE GIVEN JOB IDS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/properties/")
message="$NC: ${PURPLE}(GET: scheduler/properties/)$NC RETURNS SCHEDULER PROPERTIES AND WEB PROPERTIES IN A SINGLE MAP"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "myjobs=true&finished=true" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/revisionjobsinfo/")
message="$NC: ${PURPLE}(GET: scheduler/revisionjobsinfo/)$NC RETURNS A MAP CONTAINING ONE ENTRY WITH THE REVISION ID AS KEY AND THE LIST OF USERJOBDATA AS VALUE"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/state/revision/")
message="$NC: ${PURPLE}(GET: scheduler/state/revision/)$NC RETURNS THE REVISION NUMBER OF THE SCHEDULER STATE"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "function=TOTAL" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/stathistory/")
message="$NC: ${PURPLE}(GET: scheduler/stathistory/)$NC GET THE STATISTICS HISTORY FOR THE LAST 24 HOURS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/status/")
message="$NC: ${PURPLE}(GET: scheduler/status/)$NC RETURNS THE STATUS OF THE SCHEDULER"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/url/")
message="$NC: ${PURPLE}(GET: scheduler/url/)$NC RETURNS THE URL OF THE SCHEDULER SERVER"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/users/")
message="$NC: ${PURPLE}(GET: scheduler/users/)$NC USERS CURRENTLY CONNECTED TO THE SCHEDULER"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/userspace/")
message="$NC: ${PURPLE}(GET: scheduler/userspace/)$NC DISPLAY THE USER SPACE CONTENT"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/userswithjobs/")
message="$NC: ${PURPLE}(GET: scheduler/userswithjobs/)$NC USERS HAVING JOBS IN THE SCHEDULER"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/version/")
message="$NC: ${PURPLE}(GET: scheduler/version/)$NC RETURNS THE VERSION OF THE REST API"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/credentials/")
message="$NC: ${PURPLE}(GET: scheduler/credentials/)$NC DISPLAY CREDENTIALS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/job/$jobid/permission/check/")
message="$NC: ${PURPLE}(GET: scheduler/job/jobid/permission/method/)$NC CHECK IF THE USER HAS THE PERMISSION TO EXECUTE THE METHOD"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/)$NC RETURNS THE IDS OF THE CURRENT JOBS UNDER A LIST OF STRING"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "jobsid=$jobid" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/result/precious/metadata/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/result/precious/metadata/)$NC LIST OF PRECIOUS TASKS OF THE JOB"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "jobsid=$jobid" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/resultmap/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/resultmap/)$NC LIST JOB RESULTMAPS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/)$NC RETURNS A JOBSTATE OF THE JOB IDENTIFIED BY THE ID JOBID"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/description/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/description/)$NC GET WORKFLOW DESCRIPTION FROM A SUBMITTED JOB"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/html/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/html/)$NC RETURNS A HTML VISUALIZATION OF THE JOB"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/info/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/info/)$NC RETURNS THE JOB INFO"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/resultmap/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/resultmap/)$NC RETURNS THE JOB RESULTS MAP ASSOCIATED TO THE JOB REFERENCED BY THE ID JOBID"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/xml/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/xml/)$NC RETURNS THE XML REPRESENTATION OF THE JOB"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "allLogs=true" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/livelog/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/livelog/)$NC STREAM THE OUTPUT OF JOB IDENTIFIED BY THE ID JOBID"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/livelog/available/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/livelog/available/)$NC NUMBER OF AVAILABLE BYTES IN THE STREAM OR -1 IF THE STREAM DOES NOT EXIST"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/log/full/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/log/full/)$NC RETURNS FULL LOGS GENERATED BY TASKS IN JOB"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/log/server/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/log/server/)$NC RETURNS JOB SERVER LOGS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/result/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/result/)$NC RETURNS THE JOB RESULT ASSOCIATED TO THE JOB REFERENCED BY THE ID JOBID"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/result/log/all/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/result/log/all/)$NC RETURNS ALL THE LOGS GENERATED BY THE JOB"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/result/value/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/result/value/)$NC RETURNS ALL THE TASK RESULTS OF THIS JOB AS A MAP"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/)$NC RETURNS A LIST OF THE NAME OF THE TASKS BELONGING TO JOB JOBID"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/paginated/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/paginated/)$NC RETURNS A LIST OF THE NAME OF THE TASKS BELONGING TO JOB WITH PAGINATION"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/results/precious/metadata/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/results/precious/metadata/)$NC RETURNS THE NAME OF THE TASKS, WHICH HAS PRECIOUS RESULT"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/tag/tasktag")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/tag/tasktag/)$NC RETURNS A LIST OF THE NAME OF THE TASKS BELONGING TO JOB JOBID"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/tag/tasktag/log/server/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/tag/tasktag/log/server/)$NC RETURNS SERVER LOGS FOR A SET OF TASKS FILTERED BY A GIVEN TAG"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/tag/tasktag/paginated/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/tag/tasktag/paginated/)$NC RETURNS A LIST OF THE NAME OF THE TASKS BELONGING TO JOB JOBID"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/tag/tasktag/result/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/tag/tasktag/result/)$NC RETURNS THE TASK RESULTS OF THE SET OF TASK FILTERED"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/tag/tasktag/result/metadata/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/tag/tasktag/result/metadata/)$NC RETURNS THE METADATA OF THE TASK RESULT"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/tag/tasktag/result/serializedvalue/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/tag/tasktag/result/serializedvalue/)$NC RETURNS THE VALUES OF A SET OF TASKS OF THE JOB JOBID FILTERED"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/tag/tasktag/result/value/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/tag/tasktag/result/value/)$NC RETURNS THE VALUES OF A SET OF TASKS FILTERED BY A GIVEN TAG"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/tag/tasktag/result/log/all/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/tag/tasktag/result/log/all/)$NC RETURNS ALL THE LOGS GENERATED"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/tag/tasktag/result/log/err/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/tag/tasktag/result/log/err/)$NC RETURNS THE LIST OF STANDARD ERROR OUTPUTS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/tag/tasktag/result/log/out/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/tag/tasktag/result/log/out/)$NC RETURNS THE STANDARD OUTPUT"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/tags/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/tags/)$NC RETURNS A LIST OF THE TAGS OF THE TASKS BELONGING TO JOB JOBID"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/tags/startsWith/prefix/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/tags/startsWith/prefix/)$NC RETURNS A LIST OF THE TAGS OF THE TASKS FILTERED"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/native_task/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/taskname/)$NC RETURN THE TASK STATE OF THE TASK TASKNAME OF THE JOB JOBID"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/native_task/log/server/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/taskname/log/server/)$NC RETURNS TASK SERVER LOGS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/native_task/result/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/taskname/result/)$NC RETURNS THE TASK RESULT OF THE TASK TASKNAME OF THE JOB JOBID"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/native_task/result/download/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/taskname/result/download/)$NC RETURNS THE VALUE OF THE TASK RESULT"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/native_task/result/metadata/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/taskname/result/metadata/)$NC RETURNS THE METADATA OF THE TASK RESULT"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/native_task/result/serializedvalue/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/taskname/result/serializedvalue/)$NC RETURNS THE VALUE OF THE TASK RESULT AS BYTE ARRAY"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/native_task/result/value/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/taskname/result/value/)$NC RETURNS THE VALUE OF THE TASK RESULT DESERIALIZED"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/native_task/result/log/all/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/taskname/result/log/all/)$NC RETURNS ALL THE LOGS GENERATED BY THE TASK"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/native_task/result/log/err/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/taskname/result/log/err/)$NC RETURNS THE STANDARD ERROR OUTPUT"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/native_task/result/log/full/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/taskname/result/log/full/)$NC RETURNS FULL LOGS GENERATED BY THE TASK"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/tasks/native_task/result/log/out/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/tasks/taskname/result/log/out/)$NC RETURNS THE STANDARD OUTPUT"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/taskstates/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/taskstates/)$NC RETURNS A LIST OF TASKSTATE"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/taskstates/filtered/paginated/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/taskstates/filtered/paginated/)$NC RETURNS A LIST OF TASKSTATE FILTERED"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/taskstates/paginated/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/taskstates/paginated/)$NC RETURNS A LIST OF TASKSTATE WITH PAGINATION"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/taskstates/visualization/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/taskstates/visualization/)$NC RETURNS A LIST OF TASKSTATES, ONLY TASKS WITH VISUALIZATION ACTIVATED"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/taskstates/tasktag/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/taskstates/tasktag/)$NC RETURNS A LIST OF TASKSTATE OF THE TASKS FILTERED BY A GIVEN TAG"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/taskstates/tasktag")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/taskstates/tasktag/paginated/)$NC RETURNS A LIST OF TASKSTATES FILTERED AND PAGINATED"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/jobs/$jobid/taskstates/tasktag/statusFilter/paginated/")
message="$NC: ${PURPLE}(GET: scheduler/jobs/jobid/taskstates/tasktag/statusFilter/paginated/)$NC TASKSTATES BASED ON TAG AND STATUS AND PAGINATED"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/logins/sessionid/$sessionid/")
message="$NC: ${PURPLE}(GET: scheduler/logins/sessionid/sessionId/)$NC GET LOGIN FROM SESSION ID"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/logins/sessionid/$sessionid/userdata/")
message="$NC: ${PURPLE}(GET: scheduler/logins/sessionid/sessionId/userdata/)$NC GET USERDATA FROM SESSION ID"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/stats/")
message="$NC: ${PURPLE}(GET: scheduler/stats/)$NC RETURNS STATISTICS ABOUT THE SCHEDULER"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/stats/myaccount/")
message="$NC: ${PURPLE}(GET: scheduler/stats/myaccount/)$NC RETURNS A STRING CONTAINING SOME DATA REGARDING THE USER'S ACCOUNT"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "mytasks=true&statusFilter=Past" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/tasks/")
message="$NC: ${PURPLE}(GET: scheduler/tasks/)$NC RETURNS ALL TASKS NAME REGARDING THE GIVEN PARAMETERS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "mytasks=true&statusFilter=Past" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/tasks/tag/tasktag/")
message="$NC: ${PURPLE}(GET: scheduler/tasks/tag/tasktag/)$NC RETURNS ALL TASKS NAME REGARDING THE GIVEN TAGS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "mytasks=true&statusFilter=Past" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/taskstates/")
message="$NC: ${PURPLE}(GET: scheduler/taskstates/)$NC RETURNS A PAGINATED LIST OF TASKSTATEDATA REGARDING THE GIVEN PARAMETERS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G -d "mytasks=true&statusFilter=Past" --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/scheduler/taskstates/tag/tasktag/")
message="$NC: ${PURPLE}(GET: scheduler/taskstates/tag/tasktag/)$NC RETURNS A PAGINATED LIST OF TASKSTATEDATA REGARDING THE GIVEN PARAMETERS AND TAGS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/studio/classes/")
message="$NC: ${PURPLE}(GET: studio/classes/)$NC GET STUDIO CLASSES"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/studio/connected/")
message="$NC: ${PURPLE}(GET: studio/connected/)$NC CHECK IF THE USER IS CONNECTED TO STUDIO"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/studio/currentuser/")
message="$NC: ${PURPLE}(GET: studio/currentuser/)$NC GET NAME OF CURRENT USER"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/studio/currentuserdata/")
message="$NC: ${PURPLE}(GET: studio/currentuserdata/)$NC GET ALL DATA OF CURRENT USER"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/studio/visualizations/$jobid/")
message="$NC: ${PURPLE}(GET: studio/visualizations/id/)$NC GET WORKFLOW VISUALIZATION"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/studio/scripts/")
message="$NC: ${PURPLE}(GET: studio/scripts/)$NC GET ALL SCRIPTS DETAILS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -G --header "sessionid:$sessionid" --write-out "%{http_code}\n" --silent --output /dev/null "$URL/rest/studio/workflows/")
message="$NC: ${PURPLE}(GET: studio/workflows/)$NC GET ALL WORKFLOWS DETAILS"
check_endpoint "$endpoint" "$message"

endpoint=$(curl -X DELETE "$URL/rest/scheduler/jobs?jobsid=$jobid" --header "sessionid:$sessionid" --silent --output /dev/null --write-out '%{http_code}\n')
message="$NC: ${PURPLE}(DELETE: scheduler/jobs/)$NC DELETE ONE OR MORE JOBS BY IDS"
check_endpoint "$endpoint" "$message"

echo "--------------------------------------------------------------"
echo "Total tests: $(($SUCCESS + $FAIL))"
echo -e "${GREEN}Passed tests: "$SUCCESS $NC
echo -e "${RED}Failed tests: "$FAIL $NC

