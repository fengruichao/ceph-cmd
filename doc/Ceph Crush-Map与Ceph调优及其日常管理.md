## Ceph Crush-Map与Ceph调优及其日常管理

*   1 Crush Map
    *   1.1 管理Monitor map
        *   1.1.1 Monitor选举机制
        *   1.1.2 Monitor租约
        *   1.1.3 常用的monitor管理
    *   1.2 管理OSD Map
        *   1.2.1 OSD map命令
        *   1.2.2 OSD的状态
        *   1.2.3 OSD容量
        *   1.2.4 OSD状态参数
    *   1.3 管理PG
        *   1.3.1 管理文件到PG映射
        *   1.3.2 struck状态操作
        *   1.3.3 手动控制PG的Primary OSD
    *   1.4 自定义Crush Map
        *   1.4.1 Crush的放置策略
        *   1.4.2 编译与翻译和更新
    *   1.5 集群调优
        *   1.5.1 系统层面调优
            *   1.5.1.1 系统调优工具
            *   1.5.1.2 I/O调度算法
            *   1.5.1.3 网络IO子系统调优
            *   1.5.1.4 虚拟内存调优
        *   1.5.2 Ceph本身调优
            *   1.5.2.1 OSD生产建议
            *   1.5.2.2 RBD生产建议
            *   1.5.2.3 对象网关生产建议
            *   1.5.2.4 CephFS生产建议
            *   1.5.2.5 Monitor生产建议
            *   1.5.2.6 将OSD日志迁移到SSD
            *   1.5.2.7 存储池中PG的计算方法
            *   1.5.2.8 PG与PGP
            *   1.5.2.9 Ceph生产网络建议
            *   1.5.2.10 OSD和数据一致性校验
            *   1.5.2.11 快照的生产建议
            *   1.5.2.12 保护数据和osd
            *   1.5.2.13 OSD数据存储后端
            *   1.5.2.14 关于性能测试
        *   1.5.3 设置集群的标志
    *   1.6 admin sockets管理守护进程
    *   1.7 一、集群监控管理
        *   1.7.1 PG状态
        *   1.7.2 Pool状态
        *   1.7.3 OSD状态
        *   1.7.4 Monitor状态和查看仲裁状态
        *   1.7.5 集群空间用量
    *   1.8 二、集群配置管理(临时和全局，服务平滑重启)
        *   1.8.1 1、查看运行配置
        *   1.8.2 2、tell子命令格式
        *   1.8.3 3、daemon子命令
    *   1.9 三、集群操作
    *   1.10 四、添加和删除OSD
        *   1.10.1 1、添加OSD
        *   1.10.2 2、删除OSD
    *   1.11 五、扩容PG
    *   1.12 六、Pool操作
        *   1.12.1 列出存储池
        *   1.12.2 创建存储池
        *   1.12.3 设置存储池配额
        *   1.12.4 删除存储池
        *   1.12.5 重命名存储池
        *   1.12.6 查看存储池统计信息
        *   1.12.7 给存储池做快照
        *   1.12.8 删除存储池的快照
        *   1.12.9 获取存储池选项值
        *   1.12.10 调整存储池选项值
        *   1.12.11 获取对象副本数
    *   1.13 七、用户管理
        *   1.13.1 1、查看用户信息
        *   1.13.2 2、添加用户
        *   1.13.3 3、修改用户权限
        *   1.13.4 4、删除用户
    *   1.14 八、增加和删除Monitor
        *   1.14.1 1、新增一个monitor
        *   1.14.2 2、删除Monitor

## Crush Map

>  crush是基于hash的数据分布式算法，是ceph中独有的一种数据分布机制，算法将object自身的标志符x，以及结合当前集群中的crush map运行图，以及对应至上的规制组规则placement rule作为hash函数的stdin，经过计算将对象落在哪些osd上的pv中

> ![](https://i.imgur.com/KVWXcPk.png)

*   redhat-ceph文档地址：https://access.redhat.com/documentation/en-us/red_hat_ceph_storage/4/

*   > ``Crush运行图``：crush运行图是一种树状的层级结构，这种层级结构主要是来反应设备间的关系，只有更好的明确设备间的关系运行图才能更好的去定义`故障域的概念`,故障域越高数据越不容易丢失,也可以定义识别不同的硬盘接口来，区分p-cie/ssd/hdd来将不同的数据量存放在不同的数据盘中加以使用`性能域`

*   > ceph完美的规避了查询表，或者查询，通过实时的crush运算将对象准确的落盘，从而大大提升存储的速率

*   > 客户端只需要提供对象标志位由crush运算后写入主osd中，后经过集群的网络主osd同步数据到辅助osd中完成本次数据存储操作

*   > `注意`：无论是使用纠删码池还是副本池根本上都是数据落盘到osd上一定要考虑`故障域`不能多副本或者多纠删码块都落盘到同一机柜或同一物理主机的虚拟机中，`严重的会导致数据的丢失`。

> ``简单的实现原理``

*   take：搜寻目标在分层树状图中的起始位置，`指定的选择入口`

*   > select：通过入口向下寻找符合标准的OSD集合，根据不同的副本池进行不同的算法计算

    *   副本池：firstn算法
    *   纠删码池：indep算法
    *   都叫深度优先遍历算法
*   emit：输出结果

### 管理Monitor map

> ``多Monitor同步机制``

> 在生产环境建议最少三节点monitor，以确保cluster map的高可用性和冗余性,monitor节点不应该过多甚至操作9节点的行为,会导致数据读写时间下降，影响系统集群的性能

![](https://i.imgur.com/ZxE1gO9.png)

*   monitor使用`paxos算法`作为集群状态上达成一致的机制。paxos是`一种分布式一致性算法`。每当monitor修改map时，它会通过paxos发送更新到其他monitor。Ceph只有在大多数monitor就更新达成一致时提交map的新版本

*   > cluster map的更新操作需要Paxos确认，但是读操作不经由Paxos，而是直接访问本地的`kv存储`

#### Monitor选举机制

*   > 多个monitor之间需要建立仲裁并选择出一个leader，其他节点则作为工作节点（peon）

*   > 在选举完成并确定leader之后，leader将从所有其他monitor请求最新的map epoc，以确保leader具有集群的最新视图

*   > 要维护monitor集群的正常工作，必须有超过半数的节点正常

#### Monitor租约

*   > 在Monitor建立仲裁后，leader开始分发短期的租约到所有的monitors。让它们能够分发cluster map到OSD和client

*   > Monitor租约默认每3s续期一次

*   > 当peon monitor没有确认它收到租约时，leader假定该monitor异常，它会召集新的选举以建立仲裁

*   > 如果peon monitor的租约到期后没有收到leader的续期，它会假定leader异常，并会召集新的选举

*   > 所以如果生产环境中存在多个monitor时候某个节点的超时会猝发节点的重新选举导致client无法第一时间拿到最新的crushmap图像也就无法去对应的osd上的pv写入数据了

#### 常用的monitor管理

```
#打印monitor map信息
ceph mon dump

#将monitor map导出为一个二进制文件
ceph mon getmap -o ./monmap

#打印导出的二进制文件的内容
monmaptool --print ./monmap

#修改二进制文件，从monmap删除某个monitor
monmaptool ./monmap --rm <id>

#修改二进制文件，往monmap中添加一个monitor
monmaptool ./monmap --add <id> <ip:port>

#导入一个二进制文件，在导入之前，需要先停止monitor
ceph-mon -i <id> --inject-monmap ./monmap
```

### 管理OSD Map

![](https://i.imgur.com/ozNsRbN.png)

*   每当OSD加入或离开集群时，Ceph都会更新OSD map

*   > OSD不使用leader来管理OSD map，它们会在自身之间传播同步map。OSD会利用`OSD map epoch`标记它们交换的每一条信息，当OSD检测到自己已落后时，它会使用其对等OSD执行map更新

*   > 在大型集群中OSD map更新会非常频繁，节点会执行递增map更新

*   > Ceph也会利用epoch来标记OSD和client之间的消息。当client连接到OSD时OSD会检查epoch。如果发现epoch不匹配，则OSD会以正确的epoch响应，以便客户端可以更新其OSD map

*   > OSD定期向monitor报告自己的状态，OSD之间会交换心跳，以便检测对等点的故障，并报告给monitor

*   > leader monitor发现OSD故障时，它会更新map，递增epoch，并使用Paxos更新协议来通知其他monitor，同时撤销租约，并发布新的租约，以使monitor以分发最新的OSD map

> ``OSD状态解读``

```
正常状态的OSD为up且in
当OSD故障时，守护进程offline，在5分钟内，集群仍会将其标记为up和in，这是为了防止网络抖动
如果5分钟内仍未恢复，则会标记为down和out。此时该OSD上的PG开始迁移。这个5分钟的时间间隔可以通过mon_osd_down_out_interval配置项修改
当故障的OSD重新上线以后，会触发新的数据再平衡
当集群有noout标志位时，则osd下线不会导致数据恢复
OSD每隔6s会互相验证状态。并每隔120s向mon报告一次状态。
```

#### OSD map命令

```
ceph osd dump
ceph osd getmap -o binfile
osdmaptool --print binfile
osdmaptool --export-crush crushbinfile binfile
osdmaptool --import-crush crushbinfile binfile
osdmaptool --test-map-pg pgid binfile
```

#### OSD的状态

*   OSD运行状态
    *   up
    *   down
    *   out
    *   in
*   OSD容量状态
    *   nearfull
    *   full
*   常用指令

```
#显示OSD状态
ceph osd stat

#报告osd使用量
ceph osd df

#查找指定osd位置
ceph osd find
```

> ``限制pool配置更改``

```
#禁止池被删除
osd_pool_default_flag_nodelete

#禁止池的pg_num和pgp_num被修改
osd_pool_default_flag_nopgchange

#禁止修改池的size和min_size
osd_pool_default_flag_nosizechange
```

#### OSD容量

*   当集群容量达到mon_osd_nearfull_ratio的值时，集群会进入HEALTH_WARN状态。这是为了在达到full_ratio之前，提醒添加OSD。默认设置为0.85，即85%

*   > 当集群容量达到mon_osd_full_ratio的值时，集群将停止写入，但允许读取。集群会进入到HEALTH_ERR状态。默认为0.95，即95%。这是为了防止当一个或多个OSD故障时仍留有余地能重平衡数据

```
#设置方法：
ceph osd set-full-ratio 95
ceph osd set-nearfull-ratio 85
ceph osd dump
```

#### OSD状态参数

```
# osd之间传递心跳的间隔时间
osd_heartbeat_interval

# 一个osd多久没心跳，就会被集群认为它down了
osd_heartbeat_grace

# 确定一个osd状态为down的最少报告来源osd数
mon_osd_min_down_reporters

# 一个OSD必须重复报告一个osd状态为down的次数
mon_osd_min_down_reports

# 当osd停止响应多长时间，将其标记为down和out
mon_osd_down_out_interval

# monitor宣布失败osd为down前的等待时间
mon_osd_report_timeout

# 一个新的osd加入集群时，等待多长时间，开始向monitor报告
osd_mon_report_interval_min

# monitor允许osd报告的最大间隔，超时就认为它down了
osd_mon_report_interval_max

# osd向monitor报告心跳的时间
osd_mon_heartbeat_interval
```

### 管理PG

#### 管理文件到PG映射

*   test对象所在pg id为10.35，存储在三个osd上，分别为osd.2、osd.1和osd.8，其中osd.2为primary osd

```
rados -p test put test /etc/ceph/ceph.conf
ceph osd map test test
    osdmap e201 pool 'test' (10) object 'test' -> pg 40e8aab5 (35) -> up ([2,1,8], p2) acting ([2,1,8], p2)

#处于up状态的osd会一直留在PG的up set和acting set中，一旦主osd down，它首先会从up set中移除
#然后从acting set中移除，之后从OSD将被升级为主。Ceph会将故障OSD上的PG恢复到一个新OSD上
#然后再将这个新OSD加入到up和acting set中来维持集群的高可用性
```

> ``管理struck状态的PG``

*   如果PG长时间（mon_pg_stuck_threshold，默认为300s）出现如下状态时，MON会将该PG标记为stuck：
    *   inactive：pg有peering问题
    *   unclean：pg在故障恢复时遇到问题
    *   stale：pg没有任何OSD报告，可能其所有的OSD都是down和out
    *   undersized：pg没有充足的osd来存储它应具有的副本数
*   默认情况下，Ceph会自动执行恢复，但如果未能自动恢复，则集群状态会一直处于HEALTH_WARN或者HEALTH_ERR

*   > 如果特定PG的所有osd都是down和out状态，则PG会被标记为stale。要解决这一情况，其中一个OSD必须要重生，且具有可用的PG副本，否则PG不可用

*   > Ceph可以声明osd或PG已丢失，这也就意味着数据丢失。需要说明的是，osd的运行离不开journal，如果journal丢失，则osd停止

#### struck状态操作

*   检查处于stuck状态的pg

`ceph pg dump_stuck`

*   检查导致pg一致阻塞在peering状态的osd

`ceph osd blocked-by`

*   检查某个pg的状态

```
ceph pg dump all|grep pgid
```

*   声明pg丢失

```
ceph pg pgid mark_unfound_lost revert|delete
```

*   声明osd丢失（需要osd状态为down且out）

```
ceph osd lost osdid --yes-i-really-mean-it
```

#### 手动控制PG的Primary OSD

*   > 可以通过手动修改osd的权重以提升 特定OSD被选为PG Primary OSD的概率，避免将速度慢的磁盘用作primary osd

*   > 需要先在配置文件中配置如下参数：

```
mon_osd_allow_primary_affinity = true
```

> ``调整权重示例``

```
查看现在有多少PG的主OSD是osd.0
ceph pg dump |grep active+clean |egrep "\\[0," |wc -l

 修改osd.0的权重
ceph osd primary-affinity osd.0 0  # 权重范围从0到0

 再次查看现在有多少PG的主OSD是osd.0
ceph pg dump |grep active+clean |egrep "\\[0," |wc -l
```

### 自定义Crush Map

>  crush map决定了客户端数据最终写入的osd的位置，在某些情况下存在hdd和ssd两种盘想让某些数据写入到指定的osd中这个时候就是需要去人为的手动编译crush-map，编辑要修改的部分，再导入集群中达到我们特定的目的

#### Crush的放置策略

*   Ceph使用CRUSH算法（Controlled Replication Under Scalable Hashing 可扩展哈希下的受控复制）来计算哪些OSD存放哪些对象

*   > 对象分配到PG中，CRUSH决定这些PG使用哪些OSD来存储对象。理想情况下，CRUSH会将数据均匀的分布到存储中

*   > 当添加新OSD或者现有的OSD出现故障时，Ceph使用CRUSH在活跃的OSD上重平衡数据CRUSH map是CRUSH算法的中央配置机制，可通过调整CRUSHmap来优化数据存放位置默认情况下，CRUSH将一个对象的多个副本放置到不同主机上的0SD中。可以配置CRUSH map和CRUSH rules，使一个对象的多个副本放置到不同房间或者不同机柜的主机上的0SD中。

*   > 也可以将SSD磁盘分配给需要高速存储的池

#### 编译与翻译和更新

*   导出CRUSH map

```
ceph osd getcrushmap -o ./crushmap.bin
```

*   解译CRUSH map

```
crushtool -d ./crushmap.bin ./crushmap.txt
```

*   修改后的CRUSH map重新编译

```
crushtool -c ./crushmap.txt-o ./crushmap-new.bin
```

*   更新CRUSH map

```
ceph osd setcrushmap-i./crushmap-new.bin
```

*   查询crush map的内容（返回json）

`ceph osd crush dump`

> ``例子``

```
root default {
    id-1           # do not change unnecessarily 
    id-2 class hdd #do not change unnecessarily
    #weiqht 166
    alg straw2
    hash 0#rjenkins1
    item rackl weight 055
    item rack2 weiqht 055
    item rack3 weight 055
}

#rules
rule replicated rule{
    id 0
    type replicated
    min size 1
    max size 10
    step take default  #只要是应用这个rule的都把数据写入到defaults下
    step chooseleaf firstn 0 type host  #定义故障的故障域为物理集机器级别（rack为机柜级别）
    step emit #结尾符号
}
```

### 集群调优

### 系统层面调优

*   选择正确的CPU和内存。OSD、MON和MDS节点具有不同的CPU和内存需求
    *   mon的需求和osd的总个数有关需要的是`计算力`
    *   mds对CPU和内存要求很高，会将大量的`元数据缓存`到自己的内存中，存储元数据的尽量的使用`ssd`
    *   osd最低要求1H2G的配置例如：24块硬盘最少是`24H36G`,磁盘方面必须高I/O有多好上多好
*   尽可能关闭NUMA

*   > 规划好存储节点的数据以及各节点的磁盘要求（不考虑钱忽略）

*   > 磁盘的选择尽可能在成本、吞吐量和延迟之间找到良好的平衡

*   > journal日志应该使用SSD

*   > 如果交换机支持（MTU 9000），则启用`巨型帧`(减少数据的分片)，前提是ceph在一个单独的网络环境中切有独立交换机。

*   > 启用ntp。`Ceph对时间敏感`,集群网络至少10GB带宽

##### 系统调优工具

*   > 使用tuned-admin工具，它可帮助系统管理员针对不同的工作负载进行系统调优

*   > tuned-admin使用的profile默认存放在

    ```
    /usr/lib/tuned/<profile-name>
    ```

    目录中，可以参考其模板来自定义profile

*   > 对于ceph而言，`network-latency`可以改进全局系统延迟，`network-throughput`可以改进全局系统吞吐量,如果两个都开启可以使用`Custom`自定义模式

```
# 列出现有可用的profile
tuned-adm list

# 查看当前生效的profile
tuned-adm active

# 使用指定的profile
tuned-admin profile profile-name

# 禁用所有的profile
tuned-admin off
```

##### I/O调度算法

*   > noop：电梯算法，实现了一个简单的FIFO队列。基于SSD的磁盘，推荐使用这种调度方式

*   > Deadline：截止时间调度算法，尽力为请求提供有保障的延迟。对于Ceph，基于sata或者sas的驱动器，应该首选这种调度方式

*   > cfq：完全公平队列，适合有许多进程同时读取和写入大小不等的请求的磁盘，也是默认的通用调度算法

```
#查看当前系统支持的调度算法：
    dmesg|grep -I scheduler

#查看指定磁盘使用的调度算法：
    cat /sys/block/磁盘设备号/queue/scheduler

#修改调度算法
    echo "deadline" > /sys/block/vdb/queue/scheduler
    vim /etc/default/grub
        GRUB_CMDLINE_LINUX="elevator=deadline numa=off"
```

##### 网络IO子系统调优

*   用于集群的网络建议尽可能使用10Gb网络

> ``以下参数用于缓冲区内存管理``

```
#设置OS接收缓冲区的内存大小，第一个值告知内核一个TCP socket的最小缓冲区空间，第二值为默认缓冲区空间，第三个值是最大缓冲区空间
net.ipvtcp_wmem

#设置Os发送缓冲区的内存大小 
net.ipvtcp_rmem

#定义TCP stack如何反应内存使用情况
net.ipvtcp_mem
```

*   交换机启用大型帧

> 
 默认情况下，以太网最大传输数据包大小为1500字节。为提高吞吐量并减少处理开销，一种策略是将以太网网络配置为允许设备发送和接收更大的巨型帧。

*   在使用巨型帧的要谨慎，因为需要硬件支持，且全部以太网口配置为相同的巨型帧MTU大小。

##### 虚拟内存调优

*   设置较低的比率会导致高频但用时短的写操作，这适合Ceph等I/O密集型应用。设置较高的比率会导致低频但用时长的写操作，这会产生较小的系统开销，但可能会造成应用响应时间变长

```
#脏内存占总系统总内存的百分比，达到此比率时内核会开始在后台写出数据
vm.dirty_background_ratio

#脏内存占总系统总内存的百分比，达到此比率时写入进程停滞，而系统会将内存页清空到后端存储
vm.dirty_ratio

#控制交换分区的使用,生产中建议完全关闭，会拖慢系统运行速度
vm.swappiness

#系统尽力保持可用状态的RAM大小。在一个RAM大于48G的系统上，建议设置为4G
vm.min_free_kbytes
```

### Ceph本身调优

> ``最佳实践``

*   MON的性能对集群总体性能至关重要，应用部署于专用节点，为确保正确仲裁，数量应为奇数个

*   > 在OSD节点上，操作系统、OSD数据、OSD日志应当位于独立的磁盘上，以确保满意的吞吐量

*   > 在集群安装后，需要监控集群、排除故障并维护，尽管 Ceph具有自愈功能。如果发生性能问题，首先在磁盘、网络和硬件层面上调查。然后逐步转向RADOS块设备和Ceph对象网关

> ``影响I/O的6大操作``

*   业务数据写入
*   数据恢复
*   数据回填
*   数据重平衡
*   数据一致性校验
*   快照清理

##### OSD生产建议

*   更快的日志性能可以改进响应时间，建议将单独的低延迟`SSD`或者`NVMe`设备用于OSD日志。

*   > 多个日志可以共享同一SSD，以降低存储基础架构的成本。但是不能将过多OSD日志放在同一设备上。

*   > 建议每个SATA OSD设备不超过6个OSD日志，每个NVMe设备不超过12个OSD日志。

*   > 需要说明的是，当用于托管日志的SSD或者NVMe设备故障时，使用它托管其日志的所有OSD也都变得不可用

> ``硬件建议``

*   将一个raid1磁盘用于ceph操作系统

*   > 每个OSD一块硬盘，尽量将SSD或者NVMe用于日志

*   > 使用多个10Gb网卡，每个网络一个双链路绑定（建议生产环境2个网卡4个光模块，2个万兆口做为数据的交换，2个万兆口做业务流量）

*   > 每个OSD预留1个CPU,每个逻辑核心1GHz，分配16GB内存，外加每个OSD 2G内存

##### RBD生产建议

*   > 块设备上的工作负载通常是I/O密集型负载，例如在OpenStack中虚拟机上运行数据库。

*   > 对于RBD,OSD日志应当位于SSD或者NVMe设备上

*   > 对后端存储，可以使用不同的存储设备以提供不同级别的服务

##### 对象网关生产建议

*   > Ceph对象网关工作负载通常是吞吐密集型负载。但是其bucket索引池为I/O密集型工作负载模式。应当将这个池存储在SSD设备上

*   > Ceph对象网关为每个存储桶维护一个索引。Ceph将这一索引存储在RADOS对象中。当存储桶存储数量巨大的对象时（超过100000个），索引性能会降低，因为只有一个RADOS对象参与所有索引操作。

*   > Ceph可以在多个RADOS对象或分片中保存大型索引。可以在ceph.conf中设置rgw_override_bucket_index_max_shards配置参数来启用该功能。此参数的建议值是存储桶中预计对象数量除以10000

*   > 当索引变大，Ceph通常需要重新划分存储桶。rgw_dynamic_resharding配置控制该功能，默认为true

##### CephFS生产建议

*   > 存放目录结构和其他索引的元数据池可能会成为CephFS的瓶颈。因此，应该将SSD设备用于这个池

*   > 每个MDS维护一个内存中缓存 ，用于索引节点等不同类型的项目。Ceph使用

    ```
    mds_cache_memory_limit
    ```

    配置参数限制这一缓存的大小。其默认值为1GB，可以在需要时调整，得不得超过系统总内存数

##### Monitor生产建议

*   > 最好为每个MON一个独立的服务器/虚拟机

*   > 小型和中型集群，使用10000RPM的磁盘，大型集群使用SSD

*   > CPU使用方面：使用一个多核CPU，最少16G内存，最好不要和osd存放在同一个服务器上

##### 将OSD日志迁移到SSD

*   强烈建议生产中千万不要这么干，一定在集群初始化的时候就定制好

```
#集群中设置标志位停止指定的osd使用
ceph osd set noout

#停止osd的进程
systemctl stop ceph-osd@3

#将所有的日志做刷盘处理，刷盘到osd中
ceph-osd -i 3 --flush-journal

#删除该osd现有的日志
rm -f /var/lib/ceph/osd/ceph-3/journal

#/dev/sdc1为SSD盘创建一个软连接
ln -s /dev/sdc1 /var/lib/ceph/osd/ceph-3/journal

#刷出日志
ceph-osd -i 3 --mkjournal

#启动osd
systemctl start ceph-osd@3

#移除标志位
ceph osd unset noout
```

##### 存储池中PG的计算方法

*   > 通常，计算一个池中应该有多少个归置组的计算方法 = 100 * OSDs(个数) / size(副本数)

*   > 一种比较通用的取值规则：

    *   少于5个OSD时可把pg_num设置为128
    *   OSD数量在5到10个时，可把pg_num设置为512
    *   OSD数量在10到50个时，可把pg_num设置为4096
    *   OSD数量大于50时，建议自行计算
*   自行计算pg_num聚会时的工具
    *   pgcalc：https://ceph.com/pgcalc/
    *   cephpgc：https://access.redhat.com/labs/cephpgc/
*   注意：在实际的生产环境中我们很难去预估需要多少个pool，每个pool所占用的数据大小的百分百。所以正常情况下需要在特定的情况选择动态扩缩容pg的大小

##### PG与PGP

> > 通常而言，PG与PGP是相同的当我们为一个池增加PG时，PG会开始分裂，这个时候，OSD上的数据开始移动到新的PG，但总体而言，此时，数据还是在一个OSD的不同PG中迁移而我们一旦同时增加了PGP，则PG开始在多个OSD上重平衡，这时会出现跨OSD的数据迁移

 ![](https://i.imgur.com/sc81AvY.png)

*   ```
    ceph osd pool create poolName PgNum PgpNum
    ```

*   > 当变动pg数量只是针对当前的特定池中的osd发生变动影响范围只是一个池的pg平衡

*   > 正常情况下一个osd最多承载100个pg

*   > 当pgp发生大变动的时候会导致原本这个池中的pg变动导致池中osd，过载或者有很大剩余性能，ceph集群会将过大的性能均衡到各个性能使用小的osd上，这个时候就会发生数据的大规模迁移，大量的i/O写入会占有网络带宽会严重影响使用中的pg性能导致阻塞发生。

*   > 建议的做法是将pg_num直接设置为希望作为最终值的PG数量，而PGP的数量应当慢慢增加，以确保集群不会因为一段时间内的大量数据重平衡而导致的性能下降

##### Ceph生产网络建议

![](https://i.imgur.com/LCprEQO.png)

*   尽可能使用10Gb网络带宽以上的万兆带宽(内网)

*   尽可能使用不同的cluster网络和public网络

*   做好必要的网络设备监控防止网络过载

##### OSD和数据一致性校验

>  清理会影响ceph集群性能，但建议不要禁用此功能，因为它能提供完数据的完整性

*   清理：检查对象的存在性、校验和以及大小

*   深度清理：检查对象的存在性和大小，重新计算并验证对象的校验和。(最好不开严重影响性能)

```
#清理调优参数
osd_scrub_begin_hour =                    #取值范围0-24
osd_scrub_end_hour = end_hbegin_hour our  #取值范围0-24
osd_scrub_load_threshold                  #当系统负载低于多少的时候可以清理，默认为5
osd_scrub_min_interval                    #多久清理一次，默认是一天一次（前提是系统负载低于上一个参数的设定）
osd_scrub_interval_randomize_ratio        #在清理的时候，随机延迟的值，默认是5
osd_scrub_max_interval                    #清理的最大间隔时间，默认是一周（如果一周内没清理过，这次就必须清理，不管负载是多少）
osd_scrub_priority                        #清理的优先级，默认是5
osd_deep_scrub_interal                    #深度清理的时间间隔，默认是一周
osd_scrub_sleep                           #当有磁盘读取时，则暂停清理，增加此值可减缓清理的速度以降低对客户端的影响，默认为0,范围0-1
```

*   显示最近发生的清理和深度清理

```
ceph pg dump all  # 查看LAST_SCRUB和LAST_DEEP_SCRUB
```

* 将清理调度到特定的pg

``` 
ceph pg scrub pg-id
```

*   将深度清理调度到特定的pg

```
ceph pg deep-scrub pg-id
```

*   为设定的池设定清理参数

```
ceph osd pool set <pool-name> <parameter> <value>
    noscrub # 不清理，默认为false
    nodeep-scrub # 不深度清理，默认为false
    scrub_min_interval # 如果设置为0，则应用全局配置osd_scrub_min_interval
    scrub_max_interval # 如果设置为0，则应用全局配置osd_scrub_max_interval
    deep_scrub_interval # 如果设置为0，则应用全局配置osd_scrub_interval
```

##### 快照的生产建议

*   快照在池级别和RBD级别上提供。当快照被移除时，ceph会以异步操作的形式删除快照数据，称为快照修剪进程

*   为减轻快照修剪进程会影响集群总体性能。可以通过配置`osd_snap_trim_sleep`来在有客户端读写操作的时候暂停修剪，参数的值范围是`0到1`

*   快照修剪的优先级通过使用

    ```
    osd_snap_trim_priority  参数控制，默认为`5`
    ```

   

##### 保护数据和osd

*   需要控制回填和恢复操作，以限制这些操作的影响

*   回填发生于新的osd加入集群时，或者osd死机并且ceph将其pg分配到其他osd时。在这种场景中，ceph必须要在可用的osd之间复制对象副本

*   恢复发生于新的osd已有数据时，如出现短暂停机。在这种情形下，ceph会简单的重放pg日志

    *   管理回填和恢复操作的配置项

```
#用于限制每个osd上用于回填的并发操作数，默认为1
osd_max_backfills

#用于限制每个osd上用于恢复的并发操作数，默认为3
osd_recovery_max_active

#恢复操作的优先级，默认为3
osd_recovery_op_priority
```

##### OSD数据存储后端

>  BlueStore管理一个，两个或（在某些情况下）三个存储设备。在最简单的情况下，BlueStore使用单个（主）存储设备。存储设备通常作为一个整体使用，BlueStore直接占用完整设备。该主设备通常由数据目录中的块符号链接标识。数据目录挂载成一个tmpfs，它将填充（在启动时或ceph-volume激活它时）所有常用的OSD文件，其中包含有关OSD的信息，例如：其标识符，它所属的集群，以及它的私钥。还可以使用两个额外的设备部署BlueStore

*   WAL设备（在数据目录中标识为block.wal）可用于BlueStore的内部日志或预写日志。只有设备比主设备快（例如，当它在SSD上并且主设备是HDD时），使用WAL设备是有用的。

*   数据库设备（在数据目录中标识为block.db）可用于存储BlueStore的内部元数据。 BlueStore（或者更确切地说，嵌入式RocksDB）将在数据库设备上放置尽可能多的元数据以提高性能。如果数据库设备填满，元数据将写到主设备。同样，数据库设备要比主设备更快，则提供数据库设备是有帮助的。

*   如果只有少量快速存储可用（例如，小于1GB），我们建议将其用作WAL设备。如果还有更多，配置数据库设备会更有意义。 BlueStore日志将始终放在可用的最快设备上，因此使用数据库设备将提供与WAL设备相同的优势，同时还允许在其中存储其他元数据。

*   正常L版本推荐使用filestore，M版本可以考虑使用bluestore

*   推荐优化文章：https://www.cnblogs.com/luxiaodai/p/10006036.html#_lab2_1_9

##### 关于性能测试

*   > 推荐使用fio参考阿里云文档：https://help.aliyun.com/document_detail/95501.html?spm=a2c4g.11174283.6.659.38b44da2KZr2Sn

*   > dd

```
echo 3 > /proc/sys/vm/drop_caches
dd if=/dev/zero of=/var/lib/ceph/osd/ceph-0/test.img bs=4M count=1024 oflag=direct
dd if=/var/lib/ceph/osd/ceph-0/test.img of=/dev/null bs=4M count=1024 oflag=direct
```

*   rados bench性能测试

```
rados bench -p <pool_name> <seconds> <write|seq|rand> -b <block size> -t --no-cleanup
    pool_name 测试所针对的池
    seconds 测试所持续的时间，以秒为单位
    <write|seq|rand> 操作模式，分别是写、顺序读、随机读
    -b <block_size> 块大小，默认是4M
    -t 读/写的并行数，默认为16
    --no-cleanup 表示测试完成后不删除测试用的数据。在做读测试之前，需要使用该参数来运行一遍写测试来产生测试数据，在全部测试完成以后，可以行rados -p <pool_name> cleanup来清理所有测试数据

#示例：
rados bench -p rbd 10 write --no-cleanup
rados bench -p rbd 10 seq
```

*   rbd bench性能测试

```
rbd bench -p <pool_name> <image_name> --io-type <write|read> --io-size <size> --io-threads <num> --io-total <size> --io-pattern <seq|rand>
    --io-type 测试类型，读/写
    --io-size 字节数，默认4096
    --io-threads 线程数，默认16
    --io-total  读/写的总大小，默认1GB
    --io-pattern  读/写的方式，顺序还是随机

#示例：
https://edenmal.moe/post/2017/Ceph-rbd-bench-Commands/
```

### 设置集群的标志

> ``flag操作``

*   只能对整个集群操作，不能针对单个osd
    *   语法：
    *   ceph osd set
    *   ceph osd unset

```
#示例：
ceph osd set nodown
ceph osd unset nodown
ceph -s
```

| 标志名称 | 含义用法详解 |
| --- | --- |
| noup | OSD启动时，会将自己在MON上标识为UP状态，设置该标志位，则OSD不会被自动标识为up状态 |
| nodown | OSD停止时，MON会将OSD标识为down状态，设置该标志位，则MON不会将停止的OSD标识为down状态，设置noup和nodown可以防止网络抖动 |
| noout | 设置该标志位，则mon不会从crush映射中删除任何OSD。对OSD作维护时，可设置该标志位，以防止CRUSH在OSD停止时自动重平衡数据。OSD重新启动时，需要清除该flag |
| noin | 设置该标志位，可以防止数据被自动分配到OSD上 |
| norecover | 设置该flag，禁止任何集群恢复操作。在执行维护和停机时，可设置该flag |
| nobackfill | 禁止数据回填 |
| noscrub | 禁止清理操作。清理PG会在短期内影响OSD的操作。在低带宽集群中，清理期间如果OSD的速度过慢，则会被标记为down。可以该标记来防止这种情况发生 |
| nodeep-scrub | 禁止深度清理 |
| norebalance | 禁止重平衡数据。在执行集群维护或者停机时，可以使用该flag |
| pause | 设置该标志位，则集群停止读写，但不影响osd自检 |
| full | 标记集群已满，将拒绝任何数据写入，但可读 |

### admin sockets管理守护进程

*   通过admin sockets，管理员可以直接与守护进程交互。如查看和修改守护进程的配置参数。

*   守护进程的socket文件一般是/var/run/ceph/cluster-type.$id.asok

*   基于admin sockets的操作：

```
ceph daemon $type.$id command
#或者
ceph --admin-daemon /var/run/ceph/$cluster-$type.$id.asok command
#常用command如下：
help
config get parameter
config set parameter
config show 
perf dump
```

### 一、集群监控管理

>  集群整体运行状态

```
[root@cephnode01 ~]# ceph -s 
cluster:
    id:     8230a918-a0de-4784-9ab8-cd2a2b8671d0
    health: HEALTH_WARN
            application not enabled on 1 pool(s)

  services:
    mon: 3 daemons, quorum cephnode01,cephnode02,cephnode03 (age 27h)
    mgr: cephnode01(active, since 53m), standbys: cephnode03, cephnode02
    osd: 4 osds: 4 up (since 27h), 4 in (since 19h)
    rgw: 1 daemon active (cephnode01)

  data:
    pools:   6 pools, 96 pgs
    objects: 235 objects, 6 KiB
    usage:   0 GiB used, 56 GiB / 60 GiB avail
    pgs:     96 active+clean

    id：集群ID
    health：集群运行状态，这里有一个警告，说明是有问题，意思是pg数大于pgp数，通常此数值相等。
    mon：Monitors运行状态。
    osd：OSDs运行状态。
    mgr：Managers运行状态。
    mds：Metadatas运行状态。
    pools：存储池与PGs的数量。
    objects：存储对象的数量。
    usage：存储的理论用量。
    pgs：PGs的运行状态

~]$ ceph -w
~]$ ceph health detail
```

#### PG状态

>  查看pg状态查看通常使用下面两个命令即可，dump可以查看更详细信息

```
~]$ ceph pg dump
~]$ ceph pg stat
```

#### Pool状态

```
~]$ ceph osd pool stats
~]$ ceph osd pool stats
```

#### OSD状态

```
~]$ ceph osd stat
~]$ ceph osd dump
~]$ ceph osd tree
~]$ ceph osd df
```

#### Monitor状态和查看仲裁状态

```
~]$ ceph mon stat
~]$ ceph mon dump
~]$ ceph quorum_status
```

#### 集群空间用量

```
~]$ ceph df
~]$ ceph df detail
```

### 二、集群配置管理(临时和全局，服务平滑重启)

>  有时候需要更改服务的配置，但不想重启服务，或者是临时修改。这时候就可以使用tell和daemon子命令来完成此需求。

#### 1、查看运行配置

```
命令格式：
# ceph daemon {daemon-type}.{id} config show 

命令举例：
# ceph daemon osd.0 config show
```

#### 2、tell子命令格式

>  使用 tell 的方式适合对整个集群进行设置，使用 * 号进行匹配，就可以对整个集群的角色进行设置。而出现节点异常无法设置时候，只会在命令行当中进行报错，不太便于查找。

```
命令格式：
# ceph tell {daemon-type}.{daemon id or *} injectargs --{name}={value} [--{name}={value}]
命令举例：
# ceph tell osd.0 injectargs --debug-osd 20 --debug-ms 1
```

*   daemon-type：为要操作的对象类型如osd、mon、mds等。
*   daemon id：该对象的名称，osd通常为0、1等，mon为ceph -s显示的名称，这里可以输入*表示全部。
*   injectargs：表示参数注入，后面必须跟一个参数，也可以跟多个

#### 3、daemon子命令

*   使用 daemon 进行设置的方式就是一个个的去设置，这样可以比较好的反馈，此方法是需要在设置的角色所在的主机上进行设置。

```
命令格式：
# ceph daemon {daemon-type}.{id} config set {name}={value}
命令举例：
# ceph daemon mon.ceph-monitor-1 config set mon_allow_pool_delete false
```

### 三、集群操作

*   命令包含start、restart、status

```
#启动所有守护进程
systemctl start ceph.target

#按类型启动守护进程
systemctl start ceph-mgr.target
systemctl start ceph-osd@id
systemctl start ceph-mon.target
systemctl start ceph-mds.target
systemctl start ceph-radosgw.target
```

### 四、添加和删除OSD

#### 1、添加OSD

*   纵向扩容(会导致数据的重分布)

*   生产环境下最好的做法就是不要一次性添加大量的osd，最好逐步添加等待数据同步后再进行添加操作

    *   当影响生产数据时候临时可以停止同步：

        ```
        ceph osd set [nobackfill|norebalance] ,`unset`取消对应的参数
        ```

        

```
#格式化磁盘
ceph-volume lvm zap /dev/sd<id>

#进入到ceph-deploy执行目录/my-cluster，添加OSD
ceph-deploy osd create --data /dev/sd<id> $hostname
```

#### 2、删除OSD

*   点击跳转官方文档地址

*   如果机器有盘坏了可以使用`dmdsg`查看坏盘

*   存在一种情况就是某osd的写入延迟大盘有坏道很大可能会拖垮ceph集群：

    *   `ceph osd tree`: 查看当前集群的osd状态
    *   `ceph osd perf`: 查看当前的OSD的延迟
*   当某一快osd踢出集群时候立即做数据重分布(默认10分钟)

```
1、调整osd的crush weight为 0
ceph osd crush reweight osd.<ID> 0

2、将osd进程stop
systemctl stop ceph-osd@<ID>

3、将osd设置out(将会出发数据重分布)
ceph osd out <ID>

4、从crushmap中踢出osd
# 查看运行视图的osd状态
ceph osd crush dump|less
ceph osd crush rm <osd>.id

5、从tree树中删除osd
ceph osd rm <osd>.id

6、(选用)立即执行删除OSD中数据
ceph osd purge osd.<ID> --yes-i-really-mean-it

7、卸载磁盘
umount /var/lib/ceph/osd/ceph-？

从认证中删除磁盘对应的key
# 查看认证的列表
ceph auth list
ceph auth rm <osd>.id
```

### 五、扩容PG

*   1、扩容大小取跟它接近的2的N次方
*   2、在更改pool的PG数量时，需同时更改PGP的数量。PGP是为了管理placement而存在的专门的PG，它和PG的数量应该保持一致。如果你增加pool的pg_num，就需要同时增加pgp_num，保持它们大小一致，这样集群才能正常rebalancing。

```
ceph osd pool set {pool-name} pg_num 128
ceph osd pool set {pool-name} pgp_num 128
```

### 六、Pool操作

#### 列出存储池

`ceph osd lspools`

#### 创建存储池

```
命令格式：
# ceph osd pool create {pool-name} {pg-num} [{pgp-num}]
命令举例：
# ceph osd pool create rbd  32 32
```

#### 设置存储池配额

```
命令格式：
# ceph osd pool set-quota {pool-name} [max_objects {obj-count}] [max_bytes {bytes}]
命令举例：
# ceph osd pool set-quota rbd max_objects 10000
```

#### 删除存储池

```
ceph osd pool delete {pool-name} [{pool-name} --yes-i-really-really-mean-it]
```

#### 重命名存储池

```
ceph osd pool rename {current-pool-name} {new-pool-name}
```

#### 查看存储池统计信息

`rados df`

#### 给存储池做快照

```
ceph osd pool mksnap {pool-name} {snap-name}
```

### 删除存储池的快照

```
ceph osd pool rmsnap {pool-name} {snap-name}
```

#### 获取存储池选项值

```
ceph osd pool get {pool-name} {key}
```

#### 调整存储池选项值

```
ceph osd pool set {pool-name} {key} {value}
size：设置存储池中的对象副本数，详情参见设置对象副本数。仅适用于副本存储池。
min_size：设置 I/O 需要的最小副本数，详情参见设置对象副本数。仅适用于副本存储池。
pg_num：计算数据分布时的有效 PG 数。只能大于当前 PG 数。
pgp_num：计算数据分布时使用的有效 PGP 数量。小于等于存储池的 PG 数。
hashpspool：给指定存储池设置/取消 HASHPSPOOL 标志。
target_max_bytes：达到 max_bytes 阀值时会触发 Ceph 冲洗或驱逐对象。
target_max_objects：达到 max_objects 阀值时会触发 Ceph 冲洗或驱逐对象。
scrub_min_interval：在负载低时，洗刷存储池的最小间隔秒数。如果是 0 ，就按照配置文件里的 osd_scrub_min_interval 。
scrub_max_interval：不管集群负载如何，都要洗刷存储池的最大间隔秒数。如果是 0 ，就按照配置文件里的 osd_scrub_max_interval 。
deep_scrub_interval：“深度”洗刷存储池的间隔秒数。如果是 0 ，就按照配置文件里的 osd_deep_scrub_interval 。
```

#### 获取对象副本数

```
ceph osd dump | grep 'replicated size'
```

### 七、用户管理

>  Ceph 把数据以对象的形式存于各存储池中。Ceph 用户必须具有访问存储池的权限才能够读写数据。另外，Ceph 用户必须具有执行权限才能够使用 Ceph 的管理命令。

#### 1、查看用户信息

```
查看所有用户信息
# ceph auth list
获取所有用户的key与权限相关信息
# ceph auth get client.admin
如果只需要某个用户的key信息，可以使用pring-key子命令
# ceph auth print-key client.admin
```

#### 2、添加用户

```
# ceph auth add client.john mon 'allow r' osd 'allow rw pool=liverpool'
# ceph auth get-or-create client.paul mon 'allow r' osd 'allow rw pool=liverpool'
# ceph auth get-or-create client.george mon 'allow r' osd 'allow rw pool=liverpool' -o george.keyring
# ceph auth get-or-create-key client.ringo mon 'allow r' osd 'allow rw pool=liverpool' -o ringo.key
```

#### 3、修改用户权限

```
# ceph auth caps client.john mon 'allow r' osd 'allow rw pool=liverpool'
# ceph auth caps client.paul mon 'allow rw' osd 'allow rwx pool=liverpool'
# ceph auth caps client.brian-manager mon 'allow *' osd 'allow *'
# ceph auth caps client.ringo mon ' ' osd ' '
```

#### 4、删除用户

```
# ceph auth del {TYPE}.{ID}
其中， {TYPE} 是 client，osd，mon 或 mds 的其中一种。{ID} 是用户的名字或守护进程的 ID 。
```

### 八、增加和删除Monitor

>  一个集群可以只有一个 monitor，推荐生产环境至少部署 3 个。 Ceph 使用 Paxos 算法的一个变种对各种 map 、以及其它对集群来说至关重要的信息达成共识。建议（但不是强制）部署奇数个 monitor 。Ceph 需要 mon 中的大多数在运行并能够互相通信，比如单个 mon，或 2 个中的 2 个，3 个中的 2 个，4 个中的 3 个等。初始部署时，建议部署 3 个 monitor。后续如果要增加，请一次增加 2 个.

#### 1、新增一个monitor

```
# ceph-deploy mon create $hostname
注意：执行ceph-deploy之前要进入之前安装时候配置的目录。/my-cluster
```

#### 2、删除Monitor

```
# ceph-deploy mon destroy $hostname
注意： 确保你删除某个 Mon 后，其余 Mon 仍能达成一致。如果不可能，删除它之前可能需要先增加一个。
```
