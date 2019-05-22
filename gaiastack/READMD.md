## GaiaStack最小化安装步骤

### 创建并初始化虚拟机

```
vagrant up
```

### 配置mirror节点

```
vagrant ssh gaia1

sudo /vagrant/setup-yum-repo.sh
```

### 配置TBDS yum源

```
clush -g all --copy TBDS.repo --dest /etc/yum.repos.d/
```

### 安装部署tbds-portal

```
yum install -y tbds-portal

tbds-portal setup-gaiastack eth1

tbds-portal start

```
