#!/bin/sh
#连接mysql，并修改密码
newmysqlpwd="TonServer123!@#"
mysqlpwd=`grep 'temporary password' /var/log/mysqld.log | cut -b 92-104`
cmd="grant all privileges on *.* TO root@'%' identified by '${newmysqlpwd}' with grant option; \
flush privileges; \
create database if not exists ton default charset utf8 collate utf8_general_ci; \
use ton; \
source ~/TON-Server/tool/sql/ton.sql;"
mysqladmin -u root -p${mysqlpwd} password ${newmysqlpwd}
mysql -hlocalhost -P 3306 -u root -p${newmysqlpwd} -e "${cmd}"
make