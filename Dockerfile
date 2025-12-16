FROM centos:latest
MAINTAINER linfeng
USER root
RUN sed -i s/mirror.centos.org/vault.centos.org/g /etc/yum.repos.d/*.repo
RUN sed -i s/^#.*baseurl=http/baseurl=https/g /etc/yum.repos.d/*.repo
RUN sed -i s/^mirrorlist=http/#mirrorlist=https/g /etc/yum.repos.d/*.repo
RUN yum clean all
RUN yum makecache
#修改root密码
RUN echo "root:root" | chpasswd
RUN yum install autoconf -y; yum install gcc -y; yum install readline-devel pcre-devel zlib-devel -y
