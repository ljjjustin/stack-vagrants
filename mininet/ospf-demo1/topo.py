#!/usr/bin/python

from mininet.topo import Topo
from mininet.net import Mininet
from mininet.node import Node
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

        defaultIP1 = '10.0.3.10/24'	# IP address for r1-eth1
        defaultIP2 = '10.0.3.20/24'
        router1 = self.addNode( 'r1', cls=LinuxRouter, ip=defaultIP1 )	# cls = class
	router2 = self.addNode( 'r2', cls=LinuxRouter, ip=defaultIP2 )

        h1 = self.addHost( 'h1', ip='10.0.1.100/24', defaultRoute='via 10.0.1.10')	# define gateway
        h2 = self.addHost( 'h2', ip='10.0.2.100/24', defaultRoute='via 10.0.2.20')
        # r1-eth1 <-> r2-eth1
        self.addLink(router1,router2,intfName1='r1-eth1',intfName2='r2-eth1')
        # h1-eth0 <-> r1-eth2, r1-eth2 = 10.0.1.10/24
        self.addLink(h1,router1,intfName2='r1-eth2',params2={ 'ip': '10.0.1.10/24' })
        # h2-eth0 <-> r2-eth2, r2-eth2 = 10.0.2.20/24
        self.addLink(h2,router2,intfName2='r2-eth2',params2={ 'ip': '10.0.2.20/24' })


def run():
    "Test linux router"
    topo = NetworkTopo()
    net = Mininet(controller = None, topo=topo )	# no controller
    net.start()
    info( '*** Routing Table on Router:\n' )

    r1=net.getNodeByName('r1')
    r2=net.getNodeByName('r2')
    info('starting zebra and ospfd service:\n')

    dirs = {"workdir": workdir}
    r1.cmd('/usr/lib/quagga/zebra -f %(workdir)s/r1zebra.conf -d -z %(workdir)s/r1zebra.api -i %(workdir)s/r1zebra.pid' % dirs)
    time.sleep(2)	# time for zebra to create api socket
    r2.cmd('/usr/lib/quagga/zebra -f %(workdir)s/r2zebra.conf -d -z %(workdir)s/r2zebra.api -i %(workdir)s/r2zebra.pid' % dirs)
    time.sleep(2)	# time for zebra to create api socket
    r1.cmd('/usr/lib/quagga/ospfd -f %(workdir)s/r1ospfd.conf -d -z %(workdir)s/r1zebra.api -i %(workdir)s/r1ospfd.pid' % dirs)
    r2.cmd('/usr/lib/quagga/ospfd -f %(workdir)s/r2ospfd.conf -d -z %(workdir)s/r2zebra.api -i %(workdir)s/r2ospfd.pid' % dirs)

    CLI( net )
    net.stop()
    os.system("killall -9 ospfd zebra")
    os.system("rm -f *api*")
    os.system("rm -f *pid*")

if __name__ == '__main__':
    setLogLevel( 'info' )
    run()
