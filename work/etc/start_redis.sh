#增加执行权限
redisInstaceNum=10
prefix=`pwd`/etc/redis/
pidPrefix=`pwd`/logs/
chmod +x ${prefix}redis-server

#定义初始端口
initport=56379

#停止redis-server
for((i=1;i<=${redisInstaceNum};i++))
do
	cat ${pidPrefix}redis_${initport}.pid | xargs kill -9 > /dev/null
	let initport=${initport}+1
done


#重新初始化端口
initport=56379

# Detect OS for sed command
OS=$(uname)
if [ "$OS" = "Darwin" ]; then
	SED_INPLACE="sed -i ''"
else
	SED_INPLACE="sed -i"
fi

#启动redis-server
for((i=1;i<=${redisInstaceNum};i++))
do
	#修改redis/redis.conf中的port,启动实例,由16379开始,默认配置为6379端口
	$SED_INPLACE "s/port 6379/port ${initport}/g" ${prefix}redis.conf
	#修改log文件名称
	$SED_INPLACE "s#logfile \"\"#logfile ${prefix}redis-log-${i}#g" ${prefix}redis.conf
	#修改pid名称
	$SED_INPLACE "s#pidfile /var/run/redis_6379.pid#pidfile ${pidPrefix}redis_${initport}.pid#g" ${prefix}redis.conf

	#启动redis实例
	${prefix}redis-server ${prefix}redis.conf

	#启动完还原
	$SED_INPLACE "s/port ${initport}/port 6379/g" ${prefix}redis.conf
	$SED_INPLACE "s#logfile ${prefix}redis-log-${i}#logfile \"\"#g" ${prefix}redis.conf
	$SED_INPLACE "s#pidfile ${pidPrefix}redis_${initport}.pid#pidfile /var/run/redis_6379.pid#g" ${prefix}redis.conf

	echo "runing redis-server-${i} ok..."

	let initport=${initport}+1
done
