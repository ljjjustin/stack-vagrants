#!/bin/bash

cd $(dirname $0)

for p in $(seq 80 84)
do
    ./sock.py $p 5 &
done
