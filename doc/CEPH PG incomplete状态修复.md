
## PG检查
上面查看集群状态时，也可以发现pgs出现incomplete状态，执行health查看错误帮助。

ceph health detail  
HEALTH_WARN Reduced data availability: 12 pgs inactive, 12 pgs incomplete; 12 slow ops, oldest one blocked for 5672 sec, daemons [osd.0,osd.3] have slow ops.
PG_AVAILABILITY Reduced data availability: 12 pgs inactive, 12 pgs incomplete
    pg 1.1 is incomplete, acting [3,0]
    pg 1.b is incomplete, acting [3,0]
    pg 1.1b is incomplete, acting [3,0]
    pg 1.2f is incomplete, acting [0,3]
    pg 1.3a is incomplete, acting [3,0]
    pg 1.40 is incomplete, acting [0,3]
    pg 1.44 is incomplete, acting [0,3]
    pg 1.47 is incomplete, acting [0,3]
    pg 1.4d is incomplete, acting [0,3]
    pg 1.5d is incomplete, acting [3,0]
    pg 1.61 is incomplete, acting [0,3]
    pg 1.66 is incomplete, acting [0,3]



pg Incomplete状态出现的原因大多是因为ceph集群在peering过程中，频繁重启服务器或断电。

启动osd或创建某个pg的时候,需要同步该pg上所有osd中的pg状态，这个过程叫做peering过程


Peering过程中， 由于

a. 无非选出权威日志
b. 通过choose_acting选出的Acting Set后续不足以完成数据修复，导致Peering无非正常完成

incomplete状态系统是无法自动复原的，需要手动修复



pg repair
Ceph提供了使用ceph pg repair命令修复不一致的PG

# ceph pg deep-scrub 11.eeef
instructing pg 11.eeef on osd.106 to deep-scrub

# ceph pg repair 11.eeef
instructing pg 11.eeef on osd.106 to repair



尝试使用 ceph pg repaire {pgid} 进行修复pg，但是无效。有些情况不应该通过ceph pg repair进行修复 ，当多副本数据存在不一致或主副本损坏导致的不一致时，是无法通过这个命令来完成修复的。



ceph_objectstore_tool
ceph-objectstore-tool是ceph提供的一个操作pg及pg里面的对象的高级工具。它能够对底层pg以及对象相关数据进行获取、修改。并能够对一些问题pg和对象进行简单修复。ceph-objectstore-tool的操作是不可逆的，执行修改操作前需要备份数据。

一般通过导出备份pg和导入pg，用于解决incomplete状态pg状态不对。



### 1、查看incomplete pg所在osd节点

ceph pg dump_stuck 
ok
PG_STAT STATE      UP    UP_PRIMARY ACTING ACTING_PRIMARY 
1.4d    incomplete [0,3]          0  [0,3]              0 
1.1b    incomplete [3,0]          3  [3,0]              3 
1.66    incomplete [0,3]          0  [0,3]              0 
1.3a    incomplete [3,0]          3  [3,0]              3 
1.47    incomplete [0,3]          0  [0,3]              0 
1.61    incomplete [0,3]          0  [0,3]              0 
1.b     incomplete [3,0]          3  [3,0]              3 
1.40    incomplete [0,3]          0  [0,3]              0 
1.5d    incomplete [3,0]          3  [3,0]              3 
1.1     incomplete [3,0]          3  [3,0]              3 
1.2f    incomplete [0,3]          0  [0,3]              0 
1.44    incomplete [0,3]          0  [0,3]              0 

### 2、停止要操作的osd时，否则会得到报错：OSD has the store locked

 systemctl stop ceph-osd.target 

### 3、导出pg和导入pg

ceph-objectstore-tool --data-path /var/lib/ceph/osd/ceph-02/ --journal-path /var/log/ceph/ --pgid 1.4d --op export --file 0.3
ceph-objectstore-tool --data-path /var/lib/ceph/osd/ceph-02/ --journal-path /var/log/ceph/ --op import --file 0.3

### 4、将pg标记为complete


ceph-objectstore-tool --data-path /var/lib/ceph/osd/ceph-02/ --journal-path /var/log/ceph/ --type filestore --pgid 1.4d  --op mark-complete
WARNING: Ignoring type "filestore" - found data-path type "bluestore"
Marking complete 
Marking complete succeeded

### 5、启动osd，osd启动后，检查osd进程是否存在，一般要等几分钟才能看到UP

systemctl start ceph-osd.target   

ceph osd tree
ID CLASS WEIGHT  TYPE NAME              STATUS REWEIGHT PRI-AFF 
-1       0.02939 root default                                   
-3       0.00980     host ceph-node01                         
 0   hdd 0.00980         osd.0            down  1.00000 1.00000 
-5       0.00980     host ceph-node02                        
 2   hdd 0.00980         osd.2              up  1.00000 1.00000 
-7       0.00980     host ceph-node03                         
 3   hdd 0.00980         osd.3            down  1.00000 1.00000 



集群开始自己恢复，这个过程可以看到“pgs:215/6240 objects degraded (3.446%)”一直在变化，直到集群状态正常。

ceph -s 
  cluster:
    id:     3c09c565-7421-411d-b9e0-5a370967556f
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-node01,ceph-node02,ceph-node03
    mgr: mon_mgr(active)
    osd: 9 osds: 9 up, 9 in

  data:
    pools:   3 pools, 512 pgs
    objects: 64.26 k objects, 561 GiB
    usage:   3.17 TiB used, 5.61 TiB / 8.78 TiB avail
    pgs:     512 active+clean

  io:
    client:   341 B/s rd, 13 MiB/s wr, 0 op/s rd, 1.10 kop/s wr



## 优雅停止ceph
需要停机维护时，ceph一定要正常停止服务，尽量避免强制关机，拔电源等骚操作，物理机确认正常后再启动ceph，避免重复启动osd。



ceph osd set noout
ceph osd set nobackfill   
ceph osd set norecover 
systemctl stop ceph-mgr.target 
systemctl stop ceph-mds.target
systemctl stop ceph-mon.target
systemctl stop ceph-radosgw.target  
systemctl stop ceph-osd.target 
