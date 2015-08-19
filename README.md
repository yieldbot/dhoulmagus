# Dhoulmagus

Templates, scrips, and handlers for all emails sent out via Yieldbot monitoring applications.

### Color Scheme

| Text | Color | Hex Code |
|---|---|---|
| ALERT, CRITICAL, CONFIG ERROR | Red | `#FF0000` |
| OK, CLEAR | Green | `#33CC33` |
| WARNING | Yellow | `#B2B200` |
| UNKNOWN, Catch-all | Orange | `#FF6600` |
| FLAPPING | Blue | `#0000FF`|
| NOTICE, std text | Black | `#000000`|

### Notification Types
- CLEAR
- ALERT
- FLAPPING
- NOTICE

### Check States
- OK
- WARNING
- CRITICAL
- UNKNOWN
- CONFIG ERROR
- ERROR

### Sensu Env
- Production
- Staging
- Development
- KitchenCI
- Vagrant
- Test

### Source
- Sensu

### Misc Variables
- monitored_instance == the device being checked
- sensu-client == the device executing the check

## Environment Configuration

`/etc/sensu/conf.d/client_info`
