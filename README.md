# stack-vagrants

结合vagrant，实现相关技术栈的一键部署，可以快速的对相关的技术栈进行使用和体验。

**本项目只是技术验证，生产使用请谨慎参考。**

## ceph-aio

一键部署单机版的ceph。

## ceph-multisite-demo

部署两个单机版的ceph，然后将对象存储配置为一个zonegroup，实现对象存储的互备。

## ceph-ansible

通过ceph-ansible部署一个由三个ceph monitor和三个ceph osd组成的ceph集群。
经过测试的版本是： ceph octopus。

## redis-sentinel

三节点的redis哨兵集群，通过哨兵实现自动failover。

## mongodb

三节点的高可用的mongo集群。

## lvs

快速部署LVS集群，支持NAT/DR/TUN三种模式。

## tcptune

通过调整内核及nginx参数调优，实现单机百万TCP连接。
