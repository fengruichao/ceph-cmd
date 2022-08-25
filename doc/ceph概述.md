
## ceph概述


*   1 什么是分布式文件系统
*   2 常用的分布式文件系统
*   3 什么是ceph
    *   3.1 ceph组件
        *   3.1.1 RADOS Components
    *   3.2 ceph实验的配置
        *   3.2.1 部署ceph集群
        *   3.2.2 开始部署
        *   3.2.3 验证
    *   3.3 Ceph块存储
        *   3.3.1 什么是块存储
        *   3.3.2 创建镜像
        *   3.3.3 动态调整大小
        *   3.3.4 集群内通过KRBD访问
        *   3.3.5 客户端通过KRBD访问
        *   3.3.6 创建镜像快照
        *   3.3.7 使用快照恢复数据
        *   3.3.8 快照克隆
        *   3.3.9 客户端撤销磁盘映射
        *   3.3.10 删除快照与镜像
        *   3.3.11 实战快存储
            *   3.3.11.1 创建磁盘镜像
    *   3.4 cephFS
        *   3.4.1 什么是元数据
        *   3.4.2 简单部署使用
    *   3.5 对象存储
        *   3.5.1 环境配置
        *   3.5.2 相关部署
        *   3.5.3 新建网关实例
        *   3.5.4 修改服务端口
        *   3.5.5 客户端测试
    *   3.6 Docker部署ceph集群
        *   3.6.1 创建ceph专用网络
        *   3.6.2 创建具体的容器
        *   3.6.3 创建用户

## 什么是分布式文件系统

*   分布式文件系统(Distributed File System)是指文件系统管理的物理存储资源不一定直接连接在本地节点上,而是通过计算机网络与节点相连

*   分布式文件系统的设计基于客户机/服务器模式

``存储设备``

*   DAS -> IDE SATA SCSI SAS USB

*   NAS(网络附加存储,提供文件存储系统接口) -> NFS/CIFS

*   SAN(存储区局域网络) -> SCSI FC SAN ISCSI

*   专业存储设备 -> EMC/NetAPP/IBM

*   分布式存储 – > 有状态的应用的

*   HDFS(Hadoop Distributed Filesystem) -> 山寨谷歌GFS

## 常用的分布式文件系统

*   Lustre

*   Hadoop

*   FastDFS

*   Ceph

*   GlusterFS

## 什么是ceph

> > Ceph是一个可大规模伸缩的、开放的、软件定义的存储平台，它将Ceph存储系统的最稳定版本与Ceph管理平台、部署实用程序和支持服务相结合。也称为分布式存储系统，其出现是为了解决分布式文件系统元数据成为存储的瓶颈问题的，常规情况下元数据存储服务会成为整个存储的中心节点，而ceph利用了一致性hash计算的方式将查询变成了取膜计算的方式，将查询变成了实时运算

*   Ceph是一个`对象（object）`式存储系统，它把每一个待管理的数据流（例如一个文件）切分为一到多个`固定大小`的对象数据，并以其为原子单元完成数据存取

*   > 对象数据的底层存储服务是由多个主机（host）组成的存储集群，该集群也被称之为`RADOS`（Reliable Automatic Distributed Object Store）存储集群，即可靠、自动化、分布式对象存储系统

*   > librados是RADOS存储集群的API，它支持C、C++、Java、Python、Ruby和PHP等编程语言

*   > ceph可以提供对象存储、块存储、文件系统存储,ceph可以提供PB级别的存储空间,软件定义存储(Software Defined Storage)作为存储,行业的一大发展趋势,已经越来越受到市场的认可

![](https://i.imgur.com/t0QnTET.png)

*   无论您希望向云平台提供Ceph对象存储和/或Ceph块设备服务、部署Ceph文件系统或将Ceph用于其他目的，所有Ceph存储集群部署都是从设置每个Ceph节点、您的网络和Ceph存储集群开始的。

*   > Ceph存储集群至少需要一个Ceph监视器、Ceph管理器和Ceph OSD(对象存储守护进程)。

*   > 在运行Ceph文件系统客户机时，还需要Ceph元数据服务器。

### ceph组件

*   > OSD

    *   存储设备:用于集群中所有的数据与对象的存储/复制平衡/恢复等
*   Monitors
    *   集群监控组件:维护cluster MAP表,保证集群的数据高一致性
*   MDSs
    *   存放文件系统的元数据(对象存储和块存储不需要该组件):保存文件系统服务的元数据(OBJ/Block不需要该服务)
*   GW
    *   提供与Amazon S3和Swift兼容的Restful API的Gateway服务
*   Client
    *   ceph客户端

### RADOS Components

``Ceph osd``

> Ceph OSD(对象存储守护进程，Ceph – OSD)存储数据，处理数据复制、恢复、再平衡，并通过检查其他Ceph OSD守护进程的心跳来为Ceph监视器和管理器提供一些监控信息。  
> 冗余和高可用性通常需要至少三个Ceph OSDs。

``MDSS``

*   Ceph元数据服务器(MDS, Ceph – MDS)代表CephFilesystem(即， Ceph块设备和Ceph对象存储不使用MDS)。

*   Ceph元数据服务器允许POSIX文件系统用户执行基本命令(如ls、find等)，而不会给Ceph存储集群带来巨大的负担。

*   简单说就是文件系统的守护进程如果不需要使用是不需要管理的。

``BlueStore``

> 是Ceph的一个新的存储后端。

*   具有更好的性能(写操作大约为2倍)、全数据校验和内置压缩。

*   夜光v12.2是Ceph OSDs新的默认存储后端。在为新的OSDs配置ceph-disk、ceph-deploy和/或ceph-ansible时，默认使用。

### ceph实验的配置

| 主机名 | IP | OS |
| --- | --- | --- |
| client | 192.168.4.51（client） | centos7.2 |
| ndoe1 | 192.168.4.52（node-1） | centos7.2 |
| node2 | 192.168.4.53（node-2） | centos7.2 |
| node3 | 192.168.4.54（ndoe-3） | centos7.3 |

### 部署ceph集群

> `1.配置YUM源`

```
mount rhcs0-rhosp9-20161113-x86_iso /ceph
vim /etc/yum.repos.d/ceph.repo
    [ceph]
    name=mon
    baseurl=http://11254/ceph/rhceph-0-rhel-7-x86_64/MON
    gpgcheck=0
    enabled=1
    [osd]
    name=osd
    baseurl=http://11254/ceph/rhceph-0-rhel-7-x86_64/OSD
    gpgcheck=0
    enabled=1
    [tools]
    name=tools
    baseurl=http://11254/ceph/rhceph-0-rhel-7-x86_64/Tools
    gpgcheck=0
    enabled=1
    [rhel]
    name=centos
    baseurl=http://11254/cc
    enabled=1
    gpgcheck=0
yum clean all;yum makecache
```

> `2.配置/etc/hosts`

```
1110  client
1111  node1 
1112  node2 
1113  node3
```

> `3.配置无密码登入`

> 非交互生成密钥对

```
[root@node1 ~]# ssh-keygen -f /root/.ssh/id_rsa -t rsa -N ''
```

> 分发给每一个节点

```
[root@node1 ~]# ssh-copy-id IP
```

> `4.NTP时间同步`

```
yum -y  install chrony      #安装所有的主机
[root@client    ~]# cat /etc/chrony.conf
    server  centos.pool.ntp.org   iburst
    allow   110/24
    local   stratum 10  
[root@client    ~]# systemctl restart chronyd
[root@node1 ~]# cat /etc/chrony.conf
    server  1110            iburst  
[root@node1 ~]# systemctl restart chronyd
```

> `物理机上为每个虚拟机创建3个磁盘`

`每一个磁盘大小20G分别3个`

### 开始部署

> `1.使用client作为部署主机`

```
yum -y install ceph-deploy
```

> `2.创建目录`

> > 为了部署工具创建目录，存放密钥与配置文件

```
mkdir /ceph-cluster
cd /ceph-cluster
```

> `3.创建ceph集群`

```
ceph-deploy new node1   node2   node3
```

> `4.给所有节点安装ceph软件包`

```
ceph-deploy install node1   node2   node3
```

> `5.初始化所有节点的mon服务(主机名解析必须对)`

```
ceph-deploy mon create-initial
#这里没有指定主机,是因为第一步创建的配置文件中已经有了,所以要求主机名解析必须对,否则连接不到对应的主机
```

> `6.创建OSD`

```
[root@node1 ~]# parted /dev/vdb mklabel gpt 
[root@node1 ~]# parted /dev/vdb mkpart primary 1M 50%
[root@node1 ~]# parted /dev/vdb mkpart primary 50% 100%
[root@node1 ~]#chown ceph.ceph /dev/vdb1
[root@node1 ~]#chown ceph.ceph /dev/vdb2

#简单版
[root@node1 ~]# for i in {.3};do ssh node$i parted /dev/vdb mklabel gpt;ssh node$i parted /dev/vdb mkpart primary 1M 50%;ssh node$i parted /dev/vdb mkpart primary 50% 100%;done
[root@node1 ~]# for i in {.3};do ssh node$i chown ceph.ceph /dev/vdb1;done
[root@node1 ~]# for i in {.3};do ssh node$i chown ceph.ceph /dev/vdb2;done
```

> `初始化清空磁盘数据(仅node1操作即可)`

```
[root@node1 ~]# ceph-deploy disk zap node1:vdc node1:vdd
[root@node1 ~]# ceph-deploy disk zap node2:vdc node2:vdd
[root@node1 ~]# ceph-deploy disk zap node3:vdc node3:vdd

#简单版
for i in {.3}; do ceph-deploy disk zap node$i:vdc node$i:vdd;done
```

> `创建OSD存储空间(仅node1操作即可)`

```
[root@node1 ~]# ceph-deploy osd create node1:vdc:/dev/vdb1 node1:vdd:/ dev/vdb2
#创建osd存储设备,vdc为集群提供存储空间,vdb1提供JOURNAL日志,一个存储设备对应一个日志设备,日志需要SSD,不需要很大
[root@node1 ~]# ceph-deploy osd create node2:vdc:/dev/vdb1 node2:vdd:/dev/vdb2
[root@node1 ~]# ceph-deploy osd create node3:vdc:/dev/vdb1 node3:vdd:/dev/vdb2  验证
•  查看集群状态
[root@node1 ~]# ceph -s 
•  可能出现的错误
–  osd create创建OSD存储空间,如提示run

#简单版
for i in {.3};do ceph-deploy osd create node$i:vdc:/dev/vdb1 node$i:vdd:/dev/vdb2;done
```

### 验证

> `• 查看集群状态`

```
[root@node1 ~]# ceph -s
```

> `• 可能出现的错误`

```
osd create创建OSD存储空间,如提示run 'gatherkeys’
[root@node1 ~]# ceph-deploy gatherkeys node1 node2 node3
```

> `– ceph -s查看状态,如果失败`

```
[root@node1 ~]#systemctl restart ceph\\*.service ceph\\*.target   #在所有节点,或仅在失败的节点重启服务
```

### Ceph块存储

### 什么是块存储

*   单机块设备
    *   光盘
    *   磁盘
*   分布式块存储
    *   Ceph
    *   Cinder
*   Ceph块设备也叫做RADOS块设备

*   RADOS block device:RBD

*   RBD驱动已经很好的集成在了Linux内核中

*   RBD提供了企业功能,如快照、COW克隆等等

*   RBD还支持内存缓存,从而能够大大提高性能

*   • Linux内核可用直接访问Ceph块存储

*   • KVM可用借助于librbd访问

![](http://bk.poph163.com/wp-content/uploads/2018/05/2018-05-21-19-10-55%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE.png)

### 创建镜像

`查看存储池(默认有一个rbd池)`

```
[root@node1 ~]# ceph osd lspools
```

`创建镜像、查看镜像`

```
[root@node1 ~]# rbd create demo-image --image-feature layering --size 10G
[root@node1 ~]# rbd create rbd/image --image-feature layering --size 10G
[root@node1 ~]# rbd list
[root@node1 ~]# rbd info demo-image
```

![](http://bk.poph163.com/wp-content/uploads/2018/05/2018-05-21-19-18-06%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE.png)

### 动态调整大小

> `缩小容量`

```
[root@node1 ~]# rbd resize --size 7G image --allow-shrink
[root@node1 ~]# rbd info image
```

> `扩容容量`

```
[root@node1 ~]# rbd resize --size 15G image
[root@node1 ~]# rbd info image
```

### 集群内通过KRBD访问

> `将镜像映射为本地磁盘`

```
[root@node1 ~]# rbd map demo-image
    /dev/rbd0
[root@node1 ~]# lsblk
    ... ... 
    rbd0    251:0   0   10G     0   disk
接下来,格式化了!
[root@node1 ~]# mkfs.xfs /dev/rbd0
[root@node1 ~]# mount /dev/rbd0 /mnt
```

### 客户端通过KRBD访问

*   客户端需要安装ceph-common软件包

*   拷贝配置文件(否则不知道集群在哪)

*   拷贝连接密钥(否则无连接权限)

```
[root@client    ~]# yum -y install ceph-common
[root@client    ~]# scp 1151:/etc/ceph/ceph.conf /etc/ceph/
[root@client    ~]# scp 1151:/etc/ceph/ceph.client.admin.keyring
            /etc/ceph/
```

*   映射镜像到本地磁盘

```
[root@client    ~]# rbd map image
[root@client    ~]# lsblk
[root@client    ~]# rbd showmapped
id  pool    image   snap    device
0   rbd image   -/dev/rbd0
```

*   客户端格式化、挂载分区

```
[root@client    ~]# mkfs.xfs /dev/rbd0  
[root@client    ~]# mount /dev/rbd0 /mnt/   
[root@client    ~]# echo "test" > /mnt/test.txt
```

### 创建镜像快照

> `查看镜像快照`

```
[root@node1 ~]# rbd snap ls image
```

> `创建镜像快照`

```
[root@node1 ~]# rbd snap create image --snap image-snap1
[root@node1 ~]# rbd snap ls image
    SNAPID NAME SIZE 4 image-snap1 15360 MB
```

*   注意:快照使用COW技术,对大数据快照速度会很快!

### 使用快照恢复数据

> `删除客户端写入的测试文件`

```
[root@client    ~]# rm -rf /mnt/test.txt
```

> `还原快照`

```
[root@node1 ~]# rbd snap rollback image --snap image-snap1
```

> `客户端重新挂载分区`

```
[root@client    ~]# umount /mnt 
[root@client    ~]# mount /dev/rbd0 /mnt/   
[root@client    ~]# ls /mnt
```

### 快照克隆

*   如果想从快照恢复出来一个新的镜像,则可以使用克隆

*   注意,克隆前,需要对快照进行<保护>操作

*   被保护的快照无法删除,取消保护(unprotect)

```
[root@node1 ~]# rbd snap protect image --snap image-snap1   
[root@node1 ~]# rbd snap rm image --snap image-snap1    ##会失败
[root@node1 ~]# rbd clone image --snap image-snap1 image-clone --image-feature layering
#使用image的快照image-snap1克隆一个新的image-clone镜像
```

> `看克隆镜像与父镜像快照的关系`

```
[root@node1 ~]# rbd info image-clone    
[root@node1 ~]# rbd image 'image-clone':    
    size    15360   MB  in  3840    objects 
    order   22  (4096 kB objects)   
    block_name_prefix:  rbd_data.d3f53d1b58ba   
    format: 2   
    features:   layering    
    flags:      
    parent: rbd/image@image-snap1   
#注意,父快照信息没了!
```

### 客户端撤销磁盘映射

`umount挂载点`

```
[root@client    ~]# umount /mnt
```

`取消RBD磁盘映射`

```
[root@client    ~]# rbd showmapped  
    id  pool    image   snap    device
    0   rbd     image   -   /dev/rbd0
```

`语法格式`

```
[root@client    ~]# rbd unmap /dev/rbd/{poolname}/{imagename}   
[root@client    ~]# rbd unmap /dev/rbd/rbd/image
```

### 删除快照与镜像

`删除快照(确保快照未被保护)`

```
[root@node1 ~]# rbd snap rm image --snap image-snap
```

`删除镜像`

```
[root@node1 ~]# rbd list    
[root@node1 ~]# rbd rm image
```

### 实战快存储

#### 创建磁盘镜像

```
[root@node1 ~]# rbd create vm1-image --image-feature layering --size 10G
[root@node1 ~]# rbd create vm2-image --image-feature layering --size 10G
```

`查看镜像`

```
[root@node1 ~]# rbd list
[root@node1 ~]# rbd info vm1-image
[root@node1 ~]# qemu-img info rbd:rbd/vm1-image
```

 ![](http://bk.poph163.com/wp-content/uploads/2018/05/2018-05-22-11-15-42%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE.png)

`注意事项`

> 当我们重起过配置ceph的机器后会无法启动，镜像的创建，原因是无法/dev/下的磁盘的属主和所属组改变了，需要修改回来

```
vim /etc/udev/rules.d/chowndisk.rules
        ACTION=="add",KERNEL=="vdb[12]",OWNER="ceph",GROUP="ceph"       #开机自动设别修改属组
#或手动去修改
chown ceph.ceph /dev/vdb1 /vdb2
```

> `通过KVM虚拟机快速创建并强制关闭生成secret.xml文件`

```
virsh dumpxml vm1 >/tmp/vmxml
```

> `配置libvirt secret`

```
[root@room9pc01 ~]# vim secret.xml
```

### cephFS

*   分布式文件系统(Distributed File System)是指文件系统管理的物理存储资源不一定直接连接在本地节点上,而是通过计算机网络与节点相连

*   CephFS使用Ceph集群提供与POSIX兼容的文件系统

*   允许Linux直接将Ceph存储mount到本地

### 什么是元数据

*   元数据(Metadata)

    *   任何文件系统中的数据分为数据和元数据。

    *   数据是指普通文件中的实际数据

    *   而元数据指用来描述一个文件的特征的系统数据

    *   比如:访问权限、文件拥有者以及文件数据块的分布信息(inode…)等

*    所以CephFS必须有MDSs节点

### 简单部署使用

> ![](http://bk.poph163.com/wp-content/uploads/2018/05/2018-05-22-14-12-15%E5%B1%8F%E5%B9%95%E6%88%AA%E5%9B%BE.png)

> `1.部署mds服务器`

```
配置主机名、NTP、名称解析、node1免密登入mds节点
```

> `2.创建元数据服务器`

```
ceph-deploy mds create node4
```

> `3.不同配置文件和key`

```
ceph-deploy admin node4
```

> `4.为cephFS创建数据池和元数据池，指定每一个OSD有128个pg`

### 对象存储

*   也就是键值存储,通其接口指令,也就是简单的GET、PUT、DEL和其他扩展,向存储服务上传下载数据

*   对象存储中所有数据都被认为是一个对象,所以,任何数据都可以存入对象存储服务器,如图片、视频、音频等

*   RGW全称是Rados Gateway

*   RGW是Ceph对象存储网关,用于向客户端应用呈现存储界面,提供RESTful API访问接口

 ![](http://bk.poph163.com/wp-content/uploads/2018/05/f7c1295e5856fe3df967f7e6ec4a2936.png)

### 环境配置

> `准备一台新的虚拟机,作为元数据服务器`

| 主机名 | IP地址 | 环境要求 | key要求 |
| :-: | :-: | :-: | :-: |
| node5 | 192.168.4.56 | 配置yum源，与Manager同步，免密node1 | 修改node1的/etc/hosts,并同步到所有node主机 |

### 相关部署

*   `用户需要通过RGW访问存储集群`
    *   通过node1安装ceph-radosgw软件包

```
[root@node1 ~]# ceph-deploy install --rgw node5
```

> `同步配置文件与密钥到node5`

```
[root@node1 ~]# cd /root/ceph-cluster
[root@node1 ~]# ceph-deploy admin node5
```

### 新建网关实例

`启动一个rgw服务`

```
[root@node1 ~]# ceph-deploy rgw create node5
```

`登陆node5验证服务是否启动`

```
[root@node5 ~]# ps aux |grep radosgw
ceph    4109    2 4 2289196 14972   ?   Ssl 22:53   0:00    /usr/bin/
radosgw -f  --cluster   ceph    --name  client.rgw.node4    --setuser   ceph    --
setgroup    ceph    
[root@node5 ~]# systemctl status ceph-radosgw@\\*
```

### 修改服务端口

*   登陆node5,RGW默认服务端口为7480,修改为8081或80更方便客户端使用

```
[root@node5 ~]# vim /etc/ceph/ceph.conf 
        [client.rgw.node5]
        host = node5
        rgw_frontends = "civetweb port=8081“
# node5为主机名
# civetweb是RGW内置的一个web服务
```

```
[root@node5 ~]# systemctl   restart ceph-radosgw@\\*
```

### 客户端测试

*   这里仅测试RGW是否正常工作
    *   上传、下载数据还需要调用API接口

```
[root@client    ~]# curl 1115:8081
```

### Docker部署ceph集群

*   单机多节点方式Ubuntu-18版本下

*   mon 3个节点/osd 3个节点/wgnode 1个

``基础部署``

```
apt-get install docker.io   #默认最新版本的docker09
mkdir -p /etc/docker/   #配置容器加速
vim /etc/docker/deamon.json #具体登入阿里云容器镜像管理即可
systemctl restart docker    #重启重载配置文件
docker info #可以查看具体项目
```

### 创建ceph专用网络

```
docker network create --driver bridge --subnet 10/16 ceph-network
docker network inspect ceph-network #查看网络详情
```

![](https://i.imgur.com/wuHJRn3.png)

### 创建具体的容器

```
mkdir -p /www/ceph /var/lib/ceph/osd /www/osd   #持续化存储需要的目录
chown -R 64045:64045 /var/lib/ceph/osd/
chown -R 64045:64045 /www/osd/
docker run -itd --name monnode --network ceph-network --ip 110 -e MON_NAME=monnode -e MON_IP=110 -v /www/ceph:/etc/ceph ceph/mon
# 创建需要的osd-3个
docker exec monnode ceph osd create
docker exec monnode ceph osd create
docker exec monnode ceph osd create
# 创建osd容器
docker run -itd --name osdnode0 --network ceph-network -e CLUSTER=ceph -e WEIGHT=0 -e MON_NAME=monnode -e MON_IP=110 -v /www/ceph:/etc/ceph -v /www/osd/0:/var/lib/ceph/osd/ceph-0 ceph/osd
docker run -itd --name osdnode1 --network ceph-network -e CLUSTER=ceph -e WEIGHT=0 -e MON_NAME=monnode -e MON_IP=110 -v /www/ceph:/etc/ceph -v /www/osd/1:/var/lib/ceph/osd/ceph-1 ceph/osd
docker run -itd --name osdnode2 --network ceph-network -e CLUSTER=ceph -e WEIGHT=0 -e MON_NAME=monnode -e MON_IP=110 -v /www/ceph:/etc/ceph -v /www/osd/2:/var/lib/ceph/osd/ceph-2 ceph/osd
# 创健mon控制容器
docker run -itd --name monnode_1 --network ceph-network --ip 111 -e MON_NAME=monnode_1 -e MON_IP=111 -v /www/ceph:/etc/ceph ceph/mon
docker run -itd --name monnode_2 --network ceph-network --ip 112 -e MON_NAME=monnode_2 -e MON_IP=112 -v /www/ceph:/etc/ceph ceph/mon
# 创建radosgw
docker run -itd --name gwnode --network ceph-network --ip 19 -p 9080:80 -e RGW_NAME=gwnode -v /www/ceph:/etc/ceph ceph/radosgw
# 查看容器状态检测集群信息
docker ps -a
docker exec monnode ceph -s
```

![](https://i.imgur.com/UrHKJwB.png)

### 创建用户

```
docker exec -it gwnode radosgw-admin user create --uid=user01 --display-name=user01
```

![](https://i.imgur.com/GHq5Hwx.png)

