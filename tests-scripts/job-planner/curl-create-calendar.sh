curl -s -o /dev/null -w "%{http_code}" -X POST "$1/catalog/buckets/calendars/resources?name=cron_$2&kind=Calendar&commitMessage=v1&objectContentType=application.json" -H 'Content-Type: multipart/form-data; boundary=---------------------------9894566763566299639655444697' -H 'Accept: */*' -H "sessionID: $4" --data-binary @- <<EOF
-----------------------------9894566763566299639655444697
Content-Disposition: form-data; name="file"; filename="every_monday.json"
Content-Type: application/json

{"description":"Calendar for cron $3","cron":"$3","exclusion_calendars":[{"url":"https://www.officeholidays.com/ics/ics_country_code.php?iso=US","action":"CANCEL_NEXT_EXECUTION"},{"url":"https://www.officeholidays.com/ics/ics_country_code.php?iso=FR","action":"CANCEL_NEXT_EXECUTION"},{"url":"https://www.officeholidays.com/ics/ics_country_code.php?iso=GB","action":"CANCEL_NEXT_EXECUTION"}],"inclusion_calendars":[]}
-----------------------------9894566763566299639655444697--
EOF
