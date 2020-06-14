#!/usr/bin/python

import sys
import socket
import thread
import random
import time

def get_pages(name, port):
    socks = []
    for i in xrange(10000):
        s = socket.socket()
        s.connect(('192.168.55.31', port))
        socks.append(s)

    time.sleep(random.randint(40,60))

    for s in socks:
        s.send("GET / HTTP/1.1\rHost: 192.168.55.31\rAccept: */*\r\r")
        s.recv(200)
        s.close()


if __name__ == '__main__':

    port = int(sys.argv[1])
    for i in range(int(sys.argv[2])):
        name = "worker-%3d" % i
        thread.start_new_thread(get_pages, (name, port))
    time.sleep(80)
