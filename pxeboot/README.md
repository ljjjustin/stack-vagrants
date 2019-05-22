# pxeboot

这是一套快速构建PXE环境的脚本。

## 使用说明

下载CentOS系列ISO文件，将其保存到虚拟机的`/srv/`目录下，然后运行:

```bash
cd /var/lib/tftpboot; ./update.sh
```
即可更新pxe的启动菜单。装机时就可以选择不同的操作系统。

## 自定义配置

自定义配置需要修改`pxerc`，该文件所在的目录是`/var/lib/tftpboot/pxerc`。
该文件定义了四个参数：

* DHCP_INTERFACE: dhcp服务监听的地址；
* DHCP_RANGE: dhcp服务分配的IP地址的范围；
* DHCP_NETMASK: dhcp分配的IP地址的掩码;
* DHCP_GATEWAY: dhcp option，dhcp client会将本选项制定的IP地址设置为自己的网关;

修改完成之后，执行`update.sh`脚本。
```bash
cd /var/lib/tftpboot; ./update.sh
```
