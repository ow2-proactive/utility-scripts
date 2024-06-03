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

  ### Example:
    ```json
    {
      "crons": {
          "calendars": ["0_*_*_?_*_*","0_0/1_*_?_*_*","0_0/2_*_?_*_*","0_0/3_*_?_*_*","0_0/4_*_?_*_*","0_0/5_*_?_*_*","0_0/25_*_?_*_*","0_0/45_*_?_*_*"]
      },
      "workflows": {
          "basic-examples": ["Distributed_Computing_Pi","Variables_Propagation"]
      },
      "numberOfAssociationsPerWorkflow": 5,
      "associationStatus": "PLANNED"
    }
    ```

  ### Parameters Explanation:
  - ```"crons"``` Holds a map of **Buckets** with **Calendars**. Each calendar is defined by a [Quartz Cron](https://www.quartz-scheduler.org/)
    with an important difference in syntax. Spaces ```" "``` are replaced by Underscores ```"_"```.
    Calendars will be created in the specified buckets.
  - ```"workflows"``` Holds a map of **Buckets** with **Workflows** that will be associated to each calendar.
  - ```"numberOfAssociationsPerWorkflow"``` Defines how many times each workflow will be associated to each calendar.
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