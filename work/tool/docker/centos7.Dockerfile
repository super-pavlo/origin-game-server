FROM centos:latest
MAINTAINER linfeng
USER root
#安装sshd
RUN yum -y install openssl openssh-server; systemctl enable sshd
#安装vim
RUN yum install vim -y
#修改root密码
RUN echo "root:root" | chpasswd
#安装mysql 5.7
RUN yum install wget -y
RUN wget https://repo.mysql.com/mysql57-community-release-el7-11.noarch.rpm
RUN yum localinstall mysql57-community-release-el7-11.noarch.rpm -y
RUN yum install mysql-community-server -y
RUN systemctl enable mysqld
RUN yum install autoconf -y; yum install gcc -y; yum install readline-devel -y
RUN yum install pcre-devel zlib-devel -y
#安装git
RUN yum install git -y
#git记忆密码
RUN touch ~/.git-credentials; echo "http://fenglin05:tanker8201!@10.15.122.62" >> ~/.git-credentials
RUN git config --global credential.helper store
RUN cd ~; git clone http://10.15.122.62/root/TON-Server.git