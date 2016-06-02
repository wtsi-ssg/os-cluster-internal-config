#!/bin/bash
. /opt/openlava-3.1/etc/openlava.sh 
lsaddhost  $1
sleep 5
badmin mbdrestart
