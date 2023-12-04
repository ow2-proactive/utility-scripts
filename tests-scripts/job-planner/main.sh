#!/bin/bash

# set -x

confirmation_prompt() {
  read -p "You are about to execute the script on the platform $platform, continue? (Y/N): " answer
  if [[ "$answer" != "Y" && "$answer" != "y" ]]; then
    echo "Script execution aborted."
    exit 1
  fi
}

echo "Executing script $0"

# Check if all three arguments are provided
if [[ "$#" -eq 3 ]]; then
  platform="$1"
  login="$2"
  pwd="$3"
else
  echo "Missing parameter ..."
  echo "Usage: $0 <platform> <login> <pwd>"
  exit 2
fi

confirmation_prompt

start_time=$(date +%s)
current_dir=$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)

# Parse the JSON file using jq and extract data
crons=($(jq -r '.crons[]' $current_dir/crons.json))
workflows=($(jq -r '.workflows[]' $current_dir/crons.json))
numberOfAssociationsPerWorkflow=($(jq -r '.numberOfAssociationsPerWorkflow' $current_dir/crons.json))
associationStatus=($(jq -r '.associationStatus' $current_dir/crons.json))
# get a session ID
sessionid=$(curl -d "username=$login&password=$pwd" "$platform/rest/scheduler/login")

echo "Associations will be created with the status $associationStatus ..."

# Retrieve all calendars from the calendars bucket
all_calendars_names_from_server_array=()
get_all_calendars_response=$(curl -s -w "%{http_code}" -X GET "$platform/catalog/buckets/calendars/resources?pageNo=0&pageSize=2147483647" -H 'Accept: */*' -H "sessionID: $sessionid")
http_status="${get_all_calendars_response: -3}"
all_calendars=$(expr "$get_all_calendars_response" : '\(.*\)...')

if [[ "$http_status" -eq 200 ]]; then
  echo "Successfully retrieved all calendars ..."
  while IFS= read -r calendar; do
    all_calendars_names_from_server_array+=("$calendar")
  done < <(echo "$all_calendars" | jq -r '.[].name')
else
  echo "GET request to retrieve all calendars failed with HTTP status code: $http_status"
  exit 3
fi

# DELETE all associations
delete_associations=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE --header 'Accept: */*' --header "sessionid: $sessionid" "$platform/job-planner/planned_jobs")
if [[ $delete_associations -eq 200 ]]; then
  echo "Successfully deleted all associations ..."
else
  echo "DELETE all associations failed with HTTP status code: $delete_associations"
  exit 4
fi

# DELETE all calendars
for calendar_name_from_server in "${all_calendars_names_from_server_array[@]}"; do
  echo "Deleting calendar $calendar_name_from_server"
  encoded_calendar_name=$(echo "$calendar_name_from_server" | sed -e 's/ /%20/g' -e 's/?/%3F/g')
  delete_calendar_http_code=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$platform/catalog/buckets/calendars/resources/$encoded_calendar_name" -H 'Accept: */*' -H "sessionID: $sessionid")
  if [[ $delete_calendar_http_code -ne 200 ]]; then
    echo "Deletion of calendar $encoded_calendar_name FAILED with HTTP code $delete_calendar_http_code"
  fi
done

# Loop through "crons" and "workflows"
for cron in "${crons[@]}"; do
  echo "======================= Creating calendar and association process for cron $cron  ======================="

  # Calendar object name encoded. SLASH instead of \", COMMA instead of "," and %20 instead of spaces
  catalog_friendly_cron_name_encoded=$(echo "$cron" | sed -e 's/\//SLASH/g' -e 's/_/%20/g' -e 's/,/COMMA/g')
  # Encoded calendar objet name. Replace %20 by spaces
  catalog_friendly_cron_name=$(echo "$catalog_friendly_cron_name_encoded" | sed 's/%20/ /g')
  # Format to the actual quartz cron expression
  actual_java_cron=$(echo "$cron" | sed 's/_/ /g')

  # Execute the curl to create the calendar
  create_calendar_http_code=$("/$current_dir/curl-create-calendar.sh" "$platform" "$catalog_friendly_cron_name_encoded" "$actual_java_cron" "$sessionid")
  if [[ $create_calendar_http_code -eq 201 ]]; then
    echo "Calendar $catalog_friendly_cron_name successfully created"
  else
    echo "Error when creating calendar $catalog_friendly_cron_name, HTTP response code $create_calendar_http_code"
  fi

  for workflow in "${workflows[@]}"; do
    counter=0
    while [ $counter -lt $numberOfAssociationsPerWorkflow ]; do
      rqbody="{\"calendar_bucket\": \"calendars\", \"calendar_name\": \"cron_"$catalog_friendly_cron_name"\", \"status\": \""$associationStatus"\", \"variables\": {}, \"workflow_bucket\": \"basic-examples\", \"workflow_name\": \"$workflow\"}"
      create_association_http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST --header 'Content-Type: application/json' --header 'Accept: application/json' --header "sessionid:$sessionid" -d "$rqbody" "$platform/job-planner/planned_jobs")
      if [[ $create_association_http_code -eq 201 ]]; then
        echo "Association of workflow $workflow to calendar $catalog_friendly_cron_name successful"
      else
        echo "Error when creating calendar $catalog_friendly_cron_name, HTTP response code $create_association_http_code"
      fi
      ((counter++))
    done
  done
done
end_time=$(date +%s)
echo "Script finished in: $((end_time - start_time)) seconds"
