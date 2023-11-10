# **Job-planner test**

## Purpose

This test is designed to set-up calendars and associations in order to test the responsiveness of the **Catalog** and **Job-Planner** portals by dynamically creating calendars and associations.
The load level is defined by users in a config file.

##Configuration:
- ```crons.json```: This JSON file defines the parameters to load the **Job-Planner**

  ### Structure:
  ```json
  {
      "crons": [...],
      "workflows": [...],
      "numberOfAssociationsPerWorkflow": 1,
      "associationStatus": "DEACTIVATED"
  }
  ```
  ### Parameters Explanation:
  - ```"crons"``` Holds the list of calendars. Each calendar is defined by a [Quartz Cron](https://www.quartz-scheduler.org/)
  with an important difference in syntax. Spaces ```" "``` are replaced by Underscores ```"_"```.
  Simply add or remove cron expression to create more or less Calendars.
  - ```"workflows"``` Holds the list of workflows that will be associated to each calendar. Ath the moment,
  all workflows must be in the basic-examples bucket.
  - ```"numberOfAssociationsPerWorkflow"``` Defines how many times each workflow should associated to each calendar.
  - ```"associationStatus"``` Defines the status for all created associations

 ```crons.json``` comes with default values.

## Usage

The script expects three parameters:

- The URL of the server to test
- The Login used to query the server
- The Password of the login

If one of these is missing, the script will fail.

## Example
- Execute on localhost (expect an IP address instead of localhost)

```./main.sh http://192.168.2.13:8080 login pwd```

- Execute on tryqa

```./main.sh https://tryqa.activeeon.com login pwd```

Where login and pwd are valid credentials

## Common issues

If the calendar creation request fail with a HTTP 500 error code, try updating the line
separator format of the ```curl-create-calendar.sh``` file using the [dos2unix](https://linux.die.net/man/1/dos2unix) tool