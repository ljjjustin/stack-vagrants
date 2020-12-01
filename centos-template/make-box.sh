#!/bin/bash

vagrant up
vagrant halt
vagrant package
vagrant box add --name centos77 ./package.box
