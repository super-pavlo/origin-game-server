FROM centos:centos7
USER root
#安装sshd
RUN yum -y install openssl openssh-server; systemctl enable sshd
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
RUN echo 'Asia/Shanghai' > /etc/timezone
#安装vim/git
RUN yum install vim -y
RUN yum install git -y

#修改root密码
RUN echo "root:root" | chpasswd
#安装mysql 5.7
RUN yum install wget -y
RUN wget https://repo.mysql.com/mysql57-community-release-el7-11.noarch.rpm
RUN yum localinstall mysql57-community-release-el7-11.noarch.rpm -y
RUN yum install mysql-community-server -y
RUN systemctl enable mysqld

#安装mongodb 4.0
COPY mongodb-org.repo /etc/yum.repos.d/
RUN yum install -y mongodb-org
RUN systemctl enable mongod
RUN sed -i 's/fork:/#fork:/g' /etc/mongod.conf
RUN sed -i 's/pidFilePath:/#pidFilePath:/g' /etc/mongod.conf
RUN sed -i 's/127.0.0.1/0.0.0.0/g' /etc/mongod.conf
RUN sed -i 's/Type=/#Type=/g' /usr/lib/systemd/system/mongod.service

#编译工具
RUN yum install cmake -y; yum install gcc -y; yum install gcc-c++ -y
RUN yum install autoconf -y; yum install readline-devel -y; yum install libcurl-devel -y
RUN yum install pcre-devel zlib-devel -y
RUN yum install telnet.x86_64 -y; yum install telnet-server.x86_64 -y

#core路径设置
RUN echo "kernel.core_pattern = /tmp/core.%e.%p.%t">/etc/sysctl.conf

#安装faketime
RUN yum install unzip -y
RUN git clone https://github.com/wolfcw/libfaketime \
    && cd libfaketime \
    && make \
    && make install