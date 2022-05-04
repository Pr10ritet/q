#!/bin/sh -
THRESHOLD=50000
IPACCTCTL="/usr/local/sbin/ipacctctl"

ngctl mkpeer ipfw: ipacct 1 traf_in
ngctl name ipfw:1 nod1
ngctl connect ipfw: nod1: 2 traf_out

ngctl mkpeer ipfw: ipacct 3 traf_in
ngctl name ipfw:3 nod2
ngctl connect ipfw: nod2: 4 traf_out

$IPACCTCTL nod1:traf verbose 1
$IPACCTCTL nod1:traf threshold $THRESHOLD
$IPACCTCTL nod1:traf dlt RAW

$IPACCTCTL nod2:traf verbose 1
$IPACCTCTL nod2:traf threshold $THRESHOLD
$IPACCTCTL nod2:traf dlt RAW
