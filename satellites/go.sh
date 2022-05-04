#!/bin/sh

prg="nice -n -15 perl $1.pl"

while true
do
 ${prg}
 rez=$?
 case $rez in
         0 )  sleep 2 ;;
         * )  break ;;
 esac
done

exit $rez
