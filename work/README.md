# coe-server

#### 编译说明
- 1. 环境配置
```c
    a. 安装gcc,gcc-c++,cmake,autoconf
        i.yum install gcc -y
        ii.yum install gcc-c++ -y
        iii.yum install cmake -y
        iv.yum install autoconf -y
    b. 安装readline-devel
        i.yum install readline-devel -y
    c. 初始化git submodule
        i.git submodule update --init
    d. 编译,make即可
```
- 2. 集群脚本配置
```c
    a. etc/xxxx.conf配置mysql相关的user和passwd
    b. etc/start_xxx.sh配置相关集群IP、端口、以及serverId
    c. 一般部署在同一台上的clusterIP填127.0.1即可
    d. tool/doc/coe.sql将表结构刷到mysql中
    e. etc/start_game.sh配置客户端连接的ip和port
    f. etc/start_chat.sh配置客户端连接的ip和port
```
- 3. 启动
```c
    a. ./start -w即可，其他相关参数指令可使用./start -h查看
    b. 相关日志均位于logs目录下
```
