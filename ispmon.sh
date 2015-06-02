#!/bin/bash
#Author: Joey Whelan
#Desc:	Script for tracking connectivity outages.  Utilizes 'ping' to track connectivity.
# 		A config file (ispmon.conf) is used for all the user-settable parameters.  Script attempts to 'ping'
# 		a user-set TARGET at a user-set INTERVAL.  If the ping is successful, no action is taken.  
#		If not, the time is stored and log entry is added. 
#  
# 		When connectivity is restored, another log entry is made with the
# 		duration of the outage included.  Additionally, an email is sent to a user-set address with a
#		notification that an outage had occurred.
# 		

set -u
source ispmon.conf
failedTime=0
duration=0
h=0
m=0
s=0
t1=0;
t2=0;
internalError=0;
logRec=""
results=""
msg=""
trap "logger -t $(basename $0) \"Shutting down\"; exit" SIGHUP SIGINT SIGTERM SIGQUIT
logger -t $(basename $0) "Starting up"

while :
do
	results=`ping -qc $COUNT $TARGET`
	case "$?" in
		0)	if [ "$failedTime" -ne 0 ]
			then
				restoredTime=`date +%s`
				duration=$(( $restoredTime - $failedTime ))
				s=$(( duration%60 ))
				h=$(( duration/3600 ))
				(( duration/=60 ))
				m=$(( duration%60 ))
				
				logRec="Service Restored, Approx Outage Duration:"
				logRec+=`printf "%02d %s %02d %s %02d %s" "$h" "hrs" "$m" "min" "$s" "sec"`
				logger -t $(basename $0) "$logRec"
				t1=`date -d @$failedTime -I'seconds'`
				t2=`date -d @$restoredTime -I'seconds'`
				printf "%s %s\n%s %s" "$t1" "$msg" "$t2" "$logRec" | mail -s "Service Outage Occurred" $EMAIL
				failedTime=0
				internalError=0
			fi
			;;
		1)	if [ "$failedTime" -eq 0 ]
			then
				failedTime=`date +%s`
				logRec=`echo "Service Outage:" "$results" | tr '\n' ' '`
				msg=$logRec
				logger -t $(basename $0) "$logRec"
				internalError=0
			fi
			;;
		*)
			if [ "$internalError" -eq 0 ]
			then
				logger -t $(basename $0) "Internal Error"
				(( internalError+=1 ))
			fi
			;;
	esac
	
	sleep $INTERVAL
done
