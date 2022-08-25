## Ceph-RBD



*   1 RBD
    *   1.1 创建RBD对象并且管理
    *   1.2 RBD查询管理
    *   1.3 RBD的复制与修改
    *   1.4 RBD的删除与恢复
    *   1.5 启用RBD的特性
    *   1.6 RBD的映射
    *   1.7 Iamge的管理
        *   1.7.1 快照分层技术
        *   1.7.2 RBD的快照
        *   1.7.3 RBD的删除image
        *   1.7.4 基于快照的备份与恢复步骤
        *   1.7.5 挂载错误修复
    *   1.8 RBD的克隆
    *   1.9 RBD的镜像导入和导出
    *   1.10 RBD客户端说明
    *   1.11 RBD调优参数项

## RBD

>  RBD(Rados Block Devices)对Rados存储服务进行了一次抽象,将Rados的存储池的存储空间提供给对象式存储数据的一种机制,提交给RBD的任何数据都要被切分为对象数据并存储在Rados内部,向上则被聚合为一个磁盘设备提供application使用的

*   可以理解为一种构建在Rados存储集群之上的为客户端提供块设备接口的存储服务中间层

*   这类客户端包括虚拟化程序KVM结合Qemu和OpenStack

>  ```RBD的特性```

*   支持完整和增量的快照

*   自动精简配置

*   写时复制克隆

*   动态调整大小

*   内存内缓存

> ``RBD实现``

*   RBD基于Rados存储集群中的多个OSD进行条带化,支持存储空间的简单配置(thin-provisioning)和动态扩容等性质,并且能够借助于Rados集群实现快照/副本和一致性

*   RBD自身也是Rados存储集群的客户端,它通过将存储池提供的存储服务抽象为一个到多个image(块设备)不过V1格式因特性比较少的原因已经处于废弃状态,当前的默认使用V2版

> ``RBD挂载方式``

 ![](https://i.imgur.com/lWNAFtp.png)

> ``客户端访问``

*   通过内核模块rbd.ko将image映射为节点本地的块设备,相关的设备文件一般为/dev/rbd#
*   librbd提供API接口,它支持C++/C/Python等编程语言,qemu就是这类接口的客户端

> ``创建RBD``

```
#新建OSD
ceph osd pool create kube-osd-01 64 64
#新建RBD
rbd create --pool kube-osd-01 --image volume-01 --size 2G
#查看RBD
rbd ls --pool kube-osd-01
#展示更加详细的信息
rbd ls --pool kube-osd-01 -l
#格式化Json输出
rbd ls --pool kube-osd-01 -l --format json --pretty-format
#展示最详细的信息
rbd info --pool kube-osd-01 volume-01
#从J版本开始之后都是默认支持5个特性了
```

| 命令 | 描述 |
| --- | --- |
| size M GiB in N objects | image空间大小为M，共分割至N个对象（分割的数量由条带大小决定） |
| order 22 (4 MiB objects) | 块大小（条带）的标识序号，有效范围为12-25，分别对应着4K-32M之间的大小 |
| id | 当前image的标识符 |
| block_name_prefix | 当前image相关的object的名称前缀 |
| format | image的格式，其中的”2″表示”v2″ |
| features | 当前image启用的功能特性，其值是一个以逗号分隔的字符串列表，例如layering、 exclusive-lock等 |
| op_features | 可选的功能特性 |

 ![](https://i.imgur.com/OXQwV6K.png)

> ``客户端挂载测试``

*   配置好yum源

*   安装Ceph-common

*   授权用户使用RBD

*   内核级别的挂载方式

```
#客户端进行查询
ceph --user kube -s
#查询RBD设备
rbd --user kube map kube-osd-01/volume-01
#查看块设备信息
fdisk -l 
#块设备格式化
mkfs.xfs /dev/rdb0
#挂载到挂载点
mount /dev/rbd01 /point
#卸载挂载
rbd unmap /dev/rbd0
rbd showmapped
#动态扩展RBD的大小
rbd
```

### 创建RBD对象并且管理

*   格式化mount后会发现rbd的块大小已经有部分使用是因为盘初始化装载配置消耗的空间

```
#创建RBD池
ceph osd pool create rbd 50 50

#初始化RBD池
ceph osd pool application enable rbd rbd
#或者
rbd pool init rbd

#创建client.rbd用户
ceph auth get-or-create client.rbd mon 'allow r' osd 'allow rwx pool=rbd'

#创建RBD镜像(带上用户则 -id user)
rbd create --size 1G rbd/test

#在客户端映射镜像
rbd map rbd/test --name client.rbd

#格式化并访问
mkfs.xfs /dev/rbd0

#挂载镜像
mount /dev/rbd0 /mnt

#在管理员模式下查看rbd信息
rados -p rbd ls

#查看rbd中的对象(如果使用用户则加 -id user)
rbd ls

#查看rbd中的对象信息(如果使用用户则加 -id user,object为对象名称)
rbd info rbd/object
```

### RBD查询管理

```
#列出所有的rbd
rbd [-p pool-name] ls

#查询指定rbd的详细信息
rbd info [pool-name/]image-name

#查询指定rbd的状态信息
rbd status [pool-name/]image-name

#查询指定rbd镜像的大小
rbd du [pool-name/]image-name
```

### RBD的复制与修改

*   修改rbd镜像的大小

    *   rbd resize [pool-name]/image-name –size n M|G|T
    *   rbd resize rbd/test –size 2G
    *   xfs_growfs -d /mnt
*   复制rbd镜像（实际意义不大）
    *   rbd cp [pool-name]/src-image-name [pool-name]/tgt-image-name
*   移动rbd镜像
    *   rbd mv [pool-name]/src-image-name [pool-name]/new-image-name

### RBD的删除与恢复

```
#删除RBD需要先将其移动至回收站
rbd trash mv [pool-name/]image-name

#从回收站删除RBD
rbd trash rm [pool-name/]image-name

#从回收站恢复RBD
rbd trash restore image-id

#查看当前回收站中的RBD
rbd trash ls [pool-name]
```

### 启用RBD的特性

*   ceph为rbd提供了一些功能增强，但是都是需要内核的支持以下大多数参数 `内核3.0`都不支持，若需要则升级 `高版本的内核`

*   默认情况下如有配置文件或者命令行创建rbd的时候不指定 `feature`则会默认开启很多特性，如果客户端内核版本低则会导致无法挂载盘，这个时候就需要去指定具体的rbd关闭不支持的特性

*   当RBD启用了一些内核不支持的功能，需要关闭之后才能正常映射可通过 

    ```
    rbd feature enable/disable  来开启或禁用功能
    ```

   

*  rbd feature enable rbd/test object-map

 ![](https://i.imgur.com/VNIqaJy.png)

> ``rbd的特性``

| 特点 | 描述信息 | id号 |
| --- | --- | --- |
| layering | 是否支持克隆 | 1 |
| striping | 是否支持数据对象间的数据条带化，提升性能只支持librbd的客户端使用(内核态) | 2 |
| exclusive-lock | 是否支持分布式排他锁机制以限制同时仅能有一个客户端访问当前 image | 4 |
| object-map | 是否支持object位图，主要用于加速导入、导出及已用容量统计等操 作，依赖于exclusive-lock特性 | 8 |
| fast-diff | 是否支持快照间的快速比较操作，依赖于object-map特性 | 16 |
| deep-flatten | 是否支持克隆分离时解除在克隆image时创建的快照与其父image之间的关联关系 | 32 |
| journaling | 是否支持日志IO，即是否支持记录image的修改操作至日志对象；依赖于exclusive-lock特性 | 64 |
| data-pool | 是否支持将image的数据对象存储于纠删码存储池，主要用于将image的元数据与数据放置于不同的存储池 | 128 |

> ``配置文件中设置``

```
#在配置文件中正确的feature配置方法
vim /etc/ceph/ceph.conf

#这个值等于以上的ID号之和，如果你想开启(layering+striping)那值就=3(表示开启这两个)
#生产环境推荐开启的是=69
[client]
rbd_default_features = 69
```

> ``命令行界面的操作``

```
#命令模型
rbd create [poolname/iamgename] --size 大小 --image-format <1|2> --image-feature <xxx> --stripe-unit=1M --stripe-count=4

#具体例子
rbd create rbd/dataname --size 1G --image-format 2 --image-feature layering,exclusive,journaling
    --size: 指定块设备大小
    --image-format:指定块存储设备类型，默认为2，1已经废弃（1和2在底层的存储实现上不同）
    --stripe-unit:块存储中object大小，不得小于4k，不得大于32M，默认为4M
    --stripe-count:并发写入的对象个数
    --image-feature:指定的rbd块设备开启的特性
```

> ``关闭feature``

*   要注意关闭feature必须一个个的关闭，部分特性有关联性必先关闭前一个才能关闭后一个具体看报错信息判断

```
#查看当前拥有的块设备名称[-id idname]中的代表用户，如果是管理员权限则忽略
rbd ls [-id idname]

#查看具体的feature信息
rbd info rbd/rbdname [-id idname]

#关闭具体的特性
rbd [-id idname] feature disable rbd/rbdname [特性名称]

#查看你具体报错信息
dmesg |tail
```

### RBD的映射

*   所有映射操作都需要在客户端执行

```
#RBD映射
rbd map [pool-name/]image-name

#取消映射
rbd unmap /dev/rbd0

#查看映射
rbd showmapped
```

### Iamge的管理

>  Image的特性:从ceph-J版本开始,image默认的支持的特性有layering/exclusive-lock/object-map/fast-diff和deep-flatten五个, rbd create命令的feature选项支持创建时候自定义支持的特性,现在拥有的image特性可以使用rbd fearture enable或者rbd feature disable修改

```
#调整image的大小
rbd resize [--pool <pool>] [--image <image>] --size <size> [--allow-shrink] [--no-progress] <image-spec>
#增大image
rbd resize [--pool <pool>] [--image <image>] --size <size>
#减小image
rbd resize [--pool <pool>] [--image <image>] --size <size> [--allow-shrink]
```

> ``客户端image映射及断开``

>  在RBD客户端节点上以本地磁盘方式使用块设备之前，需要先将目标image映射至本地内核，而且若存储集群端启用了CephX认证，还需要指定用户名和keyring 文件

*   注意：节点重启后，使用rbd命令建立的image映射会丢失

```
rbd map [--pool <pool>] [--image <image>] [--id <user-name>] [--keyring </path/to/keyring>]
#查看已经映射的image
rbd showmapped
#断开
rbd unmap [--pool <pool>] [--image <image>] <image-or-device-spec>
```

### 快照分层技术

> Ceph支持在一个块设备快照的基础上创建一到多个COW或COR（Copy-On-Read）类型的克隆，这种中间快照层（snapshot layering）机制提了一种极速创建image的方式,用户可以创建一个基础image并为其创建一个只读快照层，而后可以在此快照层上创建任意个克隆进行读写操作，甚至能够进行多级克隆

*   例如：实践中可以为 `Qemu虚拟机`创建一个image并安装好基础操作系统环境作为模板，对其创建创建快照层后，便可按需创建任意多个克隆作为image提供给多个不同的VM（虚拟机）使用，或者每创建一个克隆后进行按需修改，而后对其再次创建下游的克隆

*   通过克隆生成的image在其功能上与直接创建的image几乎完全相同，它同样支持读、写、克隆、空间扩缩容等功能，惟一的不同之处是克隆引用了一个只读的上游快照，而且此快照必须要置于保护模式之下

    *   支持COW和COR两种类型
    *   COW是为默认的类型，仅在数据首次写入时才需要将它复制到克隆的image中
    *   COR则是在数据首次被读取时复制到当前克隆中，随后的读写操作都将直接基于此克隆中的对象进行
*   在RBD上使用分层克隆的方法非常简单：创建一个image，对image创建一个快照并将其置入保护模式，而克隆此快照即可
*   创建克隆的image时，需要指定引用的存储池、镜像和镜像快照，以及克隆的目标image的存储池和镜像名称，因此，克隆镜像支持跨存储池进行

### RBD的快照

> > RBD支持image快照技术,快照可以保留image的状态历史 ,RBD image 快照只需要保存少量的快照元数据信息，其底层数据 i/o 的实现完全依 赖于RADOS快照实现，数据对象克隆生成快照对象的COW过程对RBD客户端而言完全不感知，RADOS层根据RBD客户端发起的数据对象I/O所携带的SnapContext信息决定是否要进行COW操作。

*   RBD快照是创建于特定时间点的RBD镜像的只读副本,RBD快照使用写时复制（COW）技术来最大程度减少所需的存储空间所谓写时复制即快照并没有真正的复制原文件，而只是对原文件的一个引用（理解这一点，对理解clone有用）

*   Ceph还支持快照 `分层`机制，从而可实现快速克隆VM映像

*   rbd命令及许多高级接口（包括QEMU、libvirt、OpenStack等）都支持设备快照

> ``创建快照``

*   注意：在创建映像快照之前应停止image上的IO操作，且image上存在文件系统时，还要确保其处于一致状态

```
rbd snap create [--pool <pool>] --image <image> --snap <snap>
#或者使用
rbd snap create [<pool-name>/]<image-name>@<snapshot-name>
```

> ``限制某一个快照的个数``

```
#快照不能超过 --limit n个
rbd snap limit set --limit n [pool-name]/image-name
#清理快照（原则清理旧的保留新的）
rbd snap limit clear [pool-name]/image-name
#清理所有快照一个不留
rbd snap purge [pool-name]/image-name
```

> ``列出快照``

```
rbd snap ls [--pool <pool>] --image <image> [--format <format>] [--pretty-format] [--all]
```

> ``回滚快照``

*   注意：将映像回滚到快照意味着会使用快照中的数据重写当前版本的image，而且执行回滚所需的时间将随映像大小的增加而延长

*   回滚快照需要先在挂载的主机上 `umount`，然后需要 `rbd unmap rbd/name`,再进行回滚操作

*   在做快照的时候可以执行 

    ```
    fsfreeze --freeze /mnt/rbdName  可以冻结磁盘避免写入（ `--unfreeze`）解冻
    ```
```
rbd snap rollback [--pool <pool>] --image <image> --snap <snap> [--no-progress]
#或者
rbd snap rollback [pool-name]/image-name@snap-name
```

*   在RBD客户端节点上以本地磁盘方式使用块设备之前，需要先将目标image映射至本地内核，而且，若存储集群端启用了Cephx认证，还需要指定用户名和keyring文件

*   rbd map[–pool ][–image ][–id ][–keyring] </path/to/keyring>]

*   查看已经映射的image

    *   rbd showmapped断开
    *   rbd unmap[–pool ][-image 1
*   注意：节点重启后，使用rbd命令建立的image映射会丢失

> ``保护/取消保护快照``

*   保护的快照只能可读无法进行操作除非取消才能操作

```
rbd snap protect [pool-name]/image-name@snap-name
rbd snap unprotect [pool-name]/image-name@snap-name
```

### RBD的删除image

>  正常的rbd image一旦删除了就没了,但是rbd提供了回收站方式给你反悔的机会

```
#查看详细的指定的池中的image信息
rbd ls -p [pool名称] -l 
#删除image
rbd rm [pool名称]/image完整信息
#注意：删除image会导致数据丢失，且不可恢复；建议使用trash命令先将其移入trash，确定不再需要时再从trash中删除
```

 ![](https://i.imgur.com/vJMlCrY.png)

```
#打印回收站
rbd trash list -p [pool]
#放入回收站
rbd trash move [pool]/image-name
#清空回收站
rbd trash purge
#移出回收站
rbd trash restore -p [pool] --image [image-name]
```

![](https://i.imgur.com/Kg74Y5L.png)

``操作参考示例``

```
echo "Hello Ceph This is snapshot test" > /mnt/snapshot_test_file
rbd snap create rbd/test@snapshot1 --name client.rbd
rbd snap ls rbd/test --name client.rbd
echo "Hello Ceph This is snapshot test2" > /mnt/snapshot_test_file2
rm -f /mnt/snapshot_test_*
rbd snap rollback rbd/test@snapshot1 --name client.rbd
umount /mnt
mount /mnt
```

### 基于快照的备份与恢复步骤

```
创建rbd并挂载之
写入数据
创建快照
删除数据
卸载文件系统
取消映射
回退快照
重新映射
重新挂载
```

### 挂载错误修复

*   要挂载的rbd出现错误块时候要看提示进行修复

*   > ```sudo xfs repair /dev/rbd0 -L    进行修复```

```
[ ceph@ servera ~] sudo dmesg |tail
    [1173586] random: crng init done
    [22773071] XFS(rbd0): Unmounting Filesystem
    [ 22913921] XFS(rbd0): Mounting V5 Filesystem
    [ 22981539] XFS(rbd0): Corruption warning: Metadata has LSN(1:1600) ahead of current LSN(1:1408
    . Please unmount and run xfs repair (>=v3) to resolve.
    22982456] XFS(rbd0): log mount/recovery failed: error-22
    [ 22982858] XFS(rbd0): log mount failed
    [ 22377429] XFS(rbd0): Mounting V5 Filesystem
    [ 22440948] XFS(rbd0): Corruption warning: Metadata has ISN(1:1600) ahead of current LSN(1:1408
    . Please unmount and run xfs repair (>=v3) to resolve.
    [ 22441888] XFS(rbd0): log mount/recovery failed: error-22
    [ 22442402] XFS(rbd0): log mount failed
[ cepheservera ～]$ sudo xfs repair /dev/rbd0
    Phase 1-find and verify superblock...
    Phase 2-using internal log zero log...
    ERROR: The filesystem has valuable metadata changes in a log which needs to be replayed. Mount the filesystem to replay the log, and unmount it beforere-running xfs repair. If you are unable to mount the filesystem, then use the -I option to destroy the log and attempt a repair.
    Note that destroying the log may cause corruption--please attempt a mount of the filesystem before doing this.
```

### RBD的克隆

*   RBD克隆是RBD镜像副本，将RBD快照作基础，转换为彻底独立于原始来源的RBD镜像

```
创建快照：rbd snap create pool/image@snapshot
保护快照：rbd snap protect pool/image@snapshot
创建克隆：rbd clone pool/image@snapshot pool/clonename
```

*   合并父镜像，只有将父镜像信息合并到clone的子镜像，子镜像才能独立存在，不再依赖父镜像：rbd flatten pool/clonename

```
#查看指定快照的子镜像：
rbd children pool/image@snapshot
```

*   常规操作步骤

```
#磁盘上锁禁止写操作
fsfreeze --freeze
#创建快照
rbd snap create
#磁盘解锁
fsfreeze --unfreeze
#保护镜像
rbd snap protect
#克隆镜像
rbd clone
#镜像展平
rbd flaten
#保护解开镜像
rbd snap unprotect
```

### RBD的镜像导入和导出

>  ceph存储可以利用快照做数据恢复，但是快照依赖于底层的存储系统没有被破坏,可以利用rbd的导入导出功能将快照导出备份,RBD导出功能可以基于快照实现增量导出

*   导出

```
#常见的几种导出方式
导出从创建rbd到第一次快照导出从创建rbd到第二次快照
导出从第一次快照到第二次快照的差异
导出第二次快照到当前状态的差异
导出完整的

#创建快照
rbd snap create testimage@v1
rbd snap create testimage@v2

#导出创建image到快照v1时间点的差异数据
rbd export-diff rbd/testimage@v1 testimage_v1

#导出创建image到快照v2时间点的差异数据
rbd export-diff rbd/testimage@v2 testimage_v2

#导出v1快照时间点到v2快照时间点的差异数据
rbd export-diff  rbd/testimage@v2 --from-snap v1 testimage_v1_v2

#导出创建image到当前时间点的差异数据
rbd export rbd/testimage testimage_now
```

*   rbd导入

```
#常见导入方式
导入完整的rbd
导入从创建rbd到第一次快照，导入第一次快照到第二次快照，导入第二次快照到当前状态
导入第二次快照，导入第二次快照到当前状态的差异

#随便创建一个image，名称大小都不限制（恢复时会覆盖大小信息）
rbd create testbacknew --size 1

#恢复到v2时间点,直接基于v2的时间点快照做恢复
rbd import-diff testimage_v2 rbd/testbacknew

#基于v1的时间点数据，增量v1_v2的数据
rbd import-diff testimage_v1 rbd/testbacknew
rbd import-diff testimage_v1_v2 rbd/testbacknew
```

### RBD客户端说明

*   Ceph客户端可使用原生linux内核模块krbd挂载RBD镜像

*   对于OpenStack和libvirt等云和虚拟化解决方案使用librbd将RBD镜像作为设备提供给虚拟机实例librbd无法利用linux页面缓存，所以它包含了自己的内存内缓存 ，称为RBD缓存

*   RBD缓存是使用客户端上的内存

*   RBD缓存又分为两种模式：

    *   回写(write back)：数据先写入本地缓存，定时刷盘
    *   直写(derect back)：数据直接写入磁盘
    *   rbd性能不太好所以写优先写内存(BUFF)，读优先读缓存(cache)

### RBD调优参数项

*   RBD缓存参数必须添加到发起I/0请求的计算机上的配置文件的[client]部分中。

| 参数信息 | 参数描述 | Defaults values |
| --- | --- | --- |
| rbd_cache | 开启rbd的缓存 | true |
| rbd_cache_size | 为每一个rbd设置缓存大小 | 32MB |
| rbd_cache_max dirty | 最大内存中脏数据量，超出就不准写了 | 24MB |
| rbd_cache_target_dirty | 到什么程度开始刷盘(写入磁盘) | 16MB |
| rbd_cache_max_dirty_age | 间隔多少秒自动刷盘一次 | 1 |
| rbd_cache_writethrough_until_flush | 第一次写入数据先落盘然后再写到内存 | true |

