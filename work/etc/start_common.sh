#开启core,修改最大文件描述符
ulimitcount=`cat /etc/profile | grep ulimit | wc -l`
if [ $ulimitcount -eq 0 ]; then
    echo "ulimit -c unlimited" >> /etc/profile
    echo "ulimit -n 65535" >> /etc/profile
    source /etc/profile
fi