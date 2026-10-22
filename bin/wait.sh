#!/bin/bash
 
action=$1
timeout=$2
 
COUNTER=0
until [  $COUNTER -gt $timeout ]; do

 str=$(cat /proc/mdstat)
 
 if `echo $str | grep $action 1>/dev/null 2>&1`
 then
  echo "Waiting for '$action' to be finished"
 else
  echo "'$action' finished"
  exit 0
 fi
 
 let COUNTER+=1
 sleep 1
 
done
 
exit 1


