#!/bin/bash

ip netns exec ns1 ip l del ipvlan1
ip netns exec ns2 ip l del ipvlan2
