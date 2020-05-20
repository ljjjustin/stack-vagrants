import redis
import time

from redis.sentinel import Sentinel

sentinel = Sentinel([('192.168.55.31', 26379),('192.168.55.32', 26379),('192.168.55.33', 26379)],socket_timeout=0.5)

master = sentinel.discover_master('sdemo')
print(master)
slave = sentinel.discover_slaves('sdemo')
print(slave)


for i in range(1, 1000):
    key = "k%d" % i
    value = "v%d" % i
    try:
        master = sentinel.master_for('sdemo', socket_timeout=0.5, password='c72ThAPVzx3N3O2R', db=0)
        slave = sentinel.slave_for('sdemo', socket_timeout=0.5, password='c72ThAPVzx3N3O2R', db=0)

        master.set(key, value)
        ret = slave.get(key)

        print(time.strftime("%Y-%m-%d %H:%M:%S", time.localtime((time.time()))), ret)
    except Exception as e:
        print(str(e))

    time.sleep(1)

