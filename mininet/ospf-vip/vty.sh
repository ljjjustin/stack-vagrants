#!/bin/bash

if [ $# -ne 2 ]; then
	echo "$0 <node> <process>"
	exit
fi

node=$1
process=$2

pid=$(cat "${node}${process}.pid")
mnexec -a  $pid telnet 127.0.0.1 ${process}
