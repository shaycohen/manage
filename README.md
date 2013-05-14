manage
======

Manager of remote machines, based on django, puppet and git

General Architecture
DUG: Interface for 'infant' instances to retrieve configurations (puppet manifests over git) and a 'backDoor' interface
for running shell commands on 'infant' instances
INFANT: Cron / WD based agent that includes puppet standalone, git and a watchdod to allow 'backDoor' and limit 
resources usage 

MANAGE: Backend for objects managemet (where most of the fundementals classes reside)
