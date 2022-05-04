#!/bin/sh
# PROVIDE: noserver
# REQUIRE: LOGIN mysql

. /etc/rc.subr

name="noserver"
rcvar=`set_rcvar`

: ${noserver_enable="YES"}
: ${nodeny_dir="/usr/local/nodeny"}

start_cmd="${name}_start"
stop_cmd="${name}_stop"
restart_cmd="${name}_restart"
pidfile="/var/run/${name}.pid"

noserver_start()
{
    cd $nodeny_dir
    pid_old=`cat $pidfile 2>/dev/null`
    echo -n "Starting $name..."
    sh go.sh ${name} &
    sleep 2
    pid_new=`cat $pidfile 2>/dev/null`
    if [ $pid_old ] && [ $pid_old = $pid_new ];
    then
      echo "No. Already running"
    else
      echo "OK"
    fi
}

noserver_stop()
{
    cd $nodeny_dir
    echo -n "Stopping $name..."
    pid=`cat $pidfile 2>/dev/null`
    if [ $pid ];
    then
       kill -TERM $pid;
       echo -n "Waiting pid $pid"
       while true
       do
         echo -n "..."
         if [ ! -f "$pidfile" ]; then break; fi
         sleep 1
       done
       echo "OK"
    else
       echo "$name is not running (no $pidfile)"
    fi
    
}

noserver_restart()
{
    noserver_stop    
    noserver_start
}

load_rc_config $name
run_rc_command "$1"