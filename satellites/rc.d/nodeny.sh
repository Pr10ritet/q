#!/bin/sh
# PROVIDE: nodeny
# REQUIRE: LOGIN mysql

. /etc/rc.subr

name="nodeny"
rcvar=`set_rcvar`

: ${nodeny_enable="YES"}
: ${nodeny_dir="/usr/local/nodeny"}

cd $nodeny_dir
echo "Starting $name"
sh go.sh ${name} &
