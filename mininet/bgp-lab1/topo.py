#!/usr/bin/python

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.node import Node, OVSKernelSwitch
from mininet.log import setLogLevel, info
from mininet.cli import CLI
import time
import os

workdir = os.path.dirname(os.path.realpath(__file__))

class LinuxRouter( Node ):
    "A Node with IP forwarding enabled."

    def config( self, **params ):
        super( LinuxRouter, self).config( **params )
        # Enable forwarding on the router
        self.cmd( 'sysctl net.ipv4.ip_forward=1' )

    def terminate( self ):
        self.cmd( 'sysctl net.ipv4.ip_forward=0' )
        super( LinuxRouter, self ).terminate()


class NetworkTopo( Topo ):
    "A LinuxRouter connecting three IP subnets"

    def build( self, **_opts ):

        defaultIP1 = '192.168.12.1/30'	# IP address for r1-eth1
        defaultIP2 = '192.168.12.2/30'
        router1 = self.addNode( 'r1', cls=LinuxRouter, ip=defaultIP1 )	# cls = class
	router2 = self.addNode( 'r2', cls=LinuxRouter, ip=defaultIP2 )
        self.addLink(router1,router2,intfName1='r1-r2',intfName2='r2-r1')

	sw1 = self.addSwitch('s1', cls=OVSKernelSwitch)
	sw2 = self.addSwitch('s2', cls=OVSKernelSwitch)
	self.addLink(sw1, router1, intfName2='r1-s1', params2={'ip': '192.168.1.1/24'})
	self.addLink(sw2, router2, intfName2='r2-s2', params2={'ip': '192.168.2.1/24'})

        h1 = self.addHost('h1', ip='192.168.1.10/24', defaultRoute='via 192.168.1.1')	# define gateway
        h2 = self.addHost('h2', ip='192.168.2.10/24', defaultRoute='via 192.168.2.1')
        self.addLink(h1,sw1, intfName1='eth0')
        self.addLink(h2,sw2, intfName1='eth0')

def run():
    "Test linux router"
    topo = NetworkTopo()
    net = Mininet(controller = None, topo=topo )	# no controller
    net.start()
    info( '*** Routing Table on Router:\n' )

    r1=net.getNodeByName('r1')
    r2=net.getNodeByName('r2')
    info('starting zebra and bgpd service:\n')

    dirs = {"workdir": workdir}
    r1.cmd('/usr/sbin/zebra -f %(workdir)s/r1zebra.conf -d -z %(workdir)s/r1zebra.api -i %(workdir)s/r1zebra.pid' % dirs)
    time.sleep(2)	# time for zebra to create api socket
    r2.cmd('/usr/sbin/zebra -f %(workdir)s/r2zebra.conf -d -z %(workdir)s/r2zebra.api -i %(workdir)s/r2zebra.pid' % dirs)
    time.sleep(2)	# time for zebra to create api socket
    r1.cmd('/usr/sbin/bgpd -f %(workdir)s/r1bgpd.conf -d -z %(workdir)s/r1zebra.api -i %(workdir)s/r1bgpd.pid' % dirs)
    r2.cmd('/usr/sbin/bgpd -f %(workdir)s/r2bgpd.conf -d -z %(workdir)s/r2zebra.api -i %(workdir)s/r2bgpd.pid' % dirs)

    CLI( net )
    net.stop()
    os.system("killall -9 bgpd zebra")
    os.system("rm -f *api*")
    os.system("rm -f *pid*")

if __name__ == '__main__':
    setLogLevel( 'info' )
    run()
