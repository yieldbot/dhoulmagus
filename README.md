# Dhoulmagus

Detailed email script with erb templates for rich messages

## Notification Types

These can be thought of as the high-level category an email fits into.

### CLEAR
The signifies that an alert condition is no longer present on the affected device

### ALERT
Any non-ok condition that a device is presenting. The Warning or Critical status is not important at this point.
This could be one of several conditions:
- http status != 200
- a metric is over a given threshold
- a service is not running

### FLAPPING
This refers to a condition that is alerting and clearing rapidly.  It is most often seen when thresholds
are too tight.  If a threshold for a given metric is set to 90% and the baseline metric is 89%, the chances are high that the metric will enter a flapping state due to no fault of its own.  If this is the case you can either adjust the thresholds accordingly or discuss with monitoring how we can work to possibly redefine the check so that it presents more revalvent data.

### NOTICE
This is any informational messages that may not necessaryly warrant an alert but should still be logged and sent to the responsible group. Most often these will be one of the following:
- an alert has been silenced
- an alert is misconfigured
- there will be a scheduled downtime for the monitored condition(service, metric endpoint, device)

## Check States

### OK
No alert conditions are present

### WARNING
One of more warning conditions are present with the affected check or metric

### CRITICAL
One or more critical conditions are present with the affected check or metric

### UNKNOWN
One or more unknown conditions are present with he affected check or metric.  Generally these are caused by misconfigured checks or thresholds. You can also retrieve the specific error code several ways, either by executing the command from the commandline and using `echo $?` to get the exist status of the last command or by looking in the sensu-client logs device listed in the *sensu-client* field in the email.


### CONFIG ERROR
This is caused by several different error codes and generally refers to a misconfigured check command.
- the command is not found
- the check script is not executable

**NOTE**: This is usually an OS level error not a Sensu or Ruby error

### ERROR
This is a catch all state. If you find yourself hitting a specific exit status a lot then feel free to make a pull request to add it in.

## Sensu Env
This is the environment that the **Sensu-client** is running in, not the device being monitored. The following environments are currently supported.

- Production
- Staging
- Development
- KitchenCI
- Vagrant
- Test

The detection of the environment comes from a json configuration file located in `/etc/sensu/`

## Source
The application originating the application, in most cases this will be Sensu.

## Other fields

### monitored_instance
The device that the check is running against, this may not be the same device as the sensu-client.  Many checks are run from the Sensu server but against external machines.  A device with the Sensu client installed may be collecting metrics from an endpoint residing on another machine or SNMP traps from a router, PDU, or other hardware appliance. In the preceding case the router or PDU would be considered the monitored instance.

### sensu-client
The device executing the check or metric script.  This will be the device that hits the internal or external api, accepts an SNMP trap, or executes a *cpu-load* check and hands the collected output to rabbitMQ.

### notification_comment
When an alert is silenced in Sensu the user is given the ability to enter a message.  The message should be a brief explanation of why the alert is being silenced inside of the condition being corrected and should include your name for tracking purposes. When the condition is worked a more complete picture will be able to be given concerning previously taken steps or hypothesis concerning the alert triggers.

- production not affected by condition - matty
- non-crucial alarm will look at it in the morning - matty
- known issue related to FOO - matty

### notification_author
The person who silenced the alert.  If the above format if follow then the characters after the dash will be transmitted into this field.

## Environment Configuration

 `/etc/sensu/conf.d/client_info`

This file holds various environmental values, provided by Chef, that relate to the client machine.
