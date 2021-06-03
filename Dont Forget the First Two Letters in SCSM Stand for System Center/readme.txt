Active.Directory.Security.Events.xml is an unsealed Operations Manager management pack that contains:
1 Group
    - PROD - Domain Controllers
2 Rules that generate Alerts
    - Unauthorized User Creation
    - User Added to Domain Admins
1 Folder
    - Active Directory Security Events
2 Views within said Folder
    - Account Alerts (shows Alerts generated from "Unauthorized User Creation")
    - Group Alerts (shows Alerts generated from "User Added to Domain Admins")


This SCOM management pack provides the basis to build, modify, and create new SCOM Security Events to forward over to Service Manager as Incidents.