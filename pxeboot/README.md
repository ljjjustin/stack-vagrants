# pxeboot

这是一套快速构建PXE环境的脚本，能够实现无人自动化安装CentOS系列的操作系统。

## 使用说明

下载CentOS系列ISO文件，将其保存到虚拟机的`/srv/`目录下，然后运行:

```bash
./setup.sh
```
即可更新pxe的启动菜单。装机时就可以选择不同的操作系统。

## 自定义配置

### 1. 修改网络配置
自定义配置需要修改`pxerc`，该文件所在的目录是`/var/lib/tftpboot/pxerc`。
该文件定义了四个参数：

* DHCP_INTERFACE: dhcp服务监听的地址；
* DHCP_RANGE: dhcp服务分配的IP地址的范围；
* DHCP_NETMASK: dhcp分配的IP地址的掩码;
* DHCP_GATEWAY: dhcp option，dhcp client会将本选项制定的IP地址设置为自己的网关;

### 2. 修改磁盘

默认`ks.template`中使用的磁盘是`vda`，这适用于虚拟化的环境，对于物理机，需要改为`sda`。
另外，如果需要修改磁盘分区的方案，也需要修改`ks.template`中如下的部分：

```
# Disk partitioning information
part /boot --fstype="xfs" --ondisk=vda --size=1024
part pv.60 --fstype="lvmpv" --ondisk=vda --size=35840 --grow
volgroup centos pv.60
logvol swap     --vgname=centos --fstype="swap" --size=2048 --name=swap
logvol /var/log --vgname=centos --fstype="xfs" --size=10240 --name=logs
logvol /        --vgname=centos --fstype="xfs" --size=20480 --name=root
```
结合实际磁盘大小，修改`size`参数即可。

### 3. 更新配置

修改完成之后，执行`setup.sh`脚本。
```bash
./setup.sh
```
## 限制

目前只测试了CentOS 7系列操作系统的安装，没有测试过Ubuntu/Debian系列的操作系统。
