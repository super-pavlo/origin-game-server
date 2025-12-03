#include <sys/ioctl.h>
#include <net/if.h>
#include <unistd.h>
#include <netinet/in.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdbool.h> //bool type
#include <getopt.h> //getopt_long
#include <sys/types.h>
#include <dirent.h>

char* robotPushUrl = "curl -G --data-urlencode \"msg=%s\" http://10.0.3.117:8888";

#define FAIL(format,arg...) \
do \
{ \
	char fbuf[2048] = {0}; \
	snprintf(fbuf,sizeof(fbuf),"\033[31m[ERR]\033[0m  %s\n",format); \
	fprintf( stderr, fbuf ,##arg); \
	exit(EXIT_FAILURE); \
} \
while(0)

#define OK(format,arg...) \
do \
{ \
	char fbuf[2048] = {0}; \
	snprintf(fbuf,sizeof(fbuf),"\033[32m[MSG]\033[0m  %s\n",format); \
	fprintf( stderr, fbuf ,##arg); \
} \
while(0)

bool boot_daemon = false;
bool boot_login = false, boot_game = false, boot_battle = false, stop_server = false;
bool boot_monitor = false, boot_center = false, boot_db = false, boot_redis = false;
bool boot_push = false, boot_robot = false, boot_chat = false;
bool boot_all = false, boot_git = false, boot_nginx = false, boot_log = false;
int boot_delay = 0;

int checkMacInfo()
{
	struct ifconf ifc;
	char buf[2048] = {0};

	int sock = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
	if (sock == -1)
	{
		printf("socket error\n");
		return -1;
	}

	ifc.ifc_len = sizeof(buf);
	ifc.ifc_buf = buf;
	if (ioctl(sock, SIOCGIFCONF, &ifc) == -1)
	{
		printf("ioctl error\n");
		return -1;
	}

	struct ifreq *it = ifc.ifc_req;
	const struct ifreq *const end = it + (ifc.ifc_len / sizeof(struct ifreq));
	char mac[64] = "02:42:AC:11:00:04";
	char thisMac[64] = {0};
	for (; it != end; ++it)
	{
		if (ioctl(sock, SIOCGIFHWADDR, it) == 0)
		{
			unsigned char *ptr;
			ptr = (unsigned char *)&it->ifr_ifru.ifru_hwaddr.sa_data[0];
			snprintf(thisMac, sizeof(thisMac), "%02X:%02X:%02X:%02X:%02X:%02X",
				*ptr, *(ptr + 1), *(ptr + 2), *(ptr + 3), *(ptr + 4), *(ptr + 5));
			if(strncmp(mac, thisMac, sizeof(mac)) == 0)
				return 0;
		}
	}
	return -1;
}

void PushRobotMsg(char* msg)
{
	/*
	if (checkMacInfo() == 0) // 指定网卡的机器才发送
	{
		char cmd[1024] = {0};
		snprintf(cmd, sizeof(cmd), robotPushUrl, msg);
		system(cmd);
	}
	*/
}


void ShowUsage()
{
	FAIL("Usage: \n-h,--help\t\tthis help\n"
					"-f,--force\t\tforce run in daemon\n"
					"-l,--login\t\tstart login server,default use etc/start_login.sh\n"
					"-g,--game\t\tstart game server,default use etc/start_game.sh\n"
					"-b,--battle\t\tstart battle server,default use etc/start_battle.sh\n"
					"-m,--monitor\t\tstart monitor server,default use etc/start_monitor.sh\n"
					"-r,--redis\t\tstart redis server,default use etc/start_redis.sh\n"
					"-d,--db\t\t\tstart db server,default use etc/start_db.sh\n"
					"-c,--center\t\tstart center server,default use etc/start_center.sh\n"
					"-p,--push\t\tstart push server,default use etc/start_push.sh\n"
					"-t,--chat\t\tstart chat server,default use etc/start_chat.sh\n"
					"-q,--log\t\tstart log server,default use etc/start_log.sh\n"
					"-o,--robot\t\tstart Rocket.Chat+ robot\n"
					"-n,--nginx\t\tstart nginx\n"
					"-w,--whole\t\trestart all services, include redis-server\n"
					"-s,--stop\t\t[name]\tstop server by name, if name is 'all', then kill all service\n"
					"-y,--delay\t\tstart delay\n"
					"-i,--git_pull\t\t[branch]\tclean and git pull(inclue submodule) and make and restart\n");
}

char serverNames[][64] = {
	"battle", "center", "chat", "db", "game", "login", "monitor", "push", "log",
	"redis_16379", "redis_16380", "redis_16381", "redis_16382", "redis_16383",
	"redis_16384", "redis_16385", "redis_16386", "redis_16387", "redis_16388", 
};

void closeServer(char* name)
{
	FILE* f = NULL;
	int processid = 0;
	int webPort;
	char cmd[128] = {0};
	snprintf(cmd, sizeof(cmd), "cat etc/start_%s.sh | grep WEB_PORT | cut -b 17-30", name);
	if((f = popen(cmd,"r")) == NULL)
		return;
	if(fgets(cmd,sizeof(cmd),f) == NULL)
	{
		pclose(f);
		return;
	}
	else
		webPort = atoi(cmd);

	//get pid
	snprintf(cmd,sizeof(cmd),"ls logs/%s*.pid | xargs cat",name);
	if((f = popen(cmd,"r")) == NULL)
		FAIL("not found logs/%s.pid file,stop fail.",name);
	if(fgets(cmd,sizeof(cmd),f) == NULL)
	{
		pclose(f);
		return;
	}
	else
		processid = atoi(cmd);
	
	snprintf(cmd, sizeof(cmd), "curl -s -o /dev/null http://127.0.0.1:%d/closeSelf?type=3", webPort);
	if((f = popen(cmd,"r")) == NULL)
		FAIL("notify <%s> close fail!",name);
	OK("notify <%s> close after 2s",name);

	// 等待进程退出
	snprintf(cmd, sizeof(cmd), "ps -ef | grep %d | grep -v grep | wc -l", processid);
	while(true)
	{
		if((f = popen(cmd,"r")) == NULL)
			return;
		char ret[1024] = {0};
		if(fgets(ret,sizeof(ret),f) == NULL)
			return;
		else
		{
			printf("wait %s exit...\n", name);
			// 判断进程是否还存在
			if(atoi(ret) <= 0)
				return;
		}
		sleep(1);
	}
}

int kill_server(char* name)
{
	FILE* f = NULL;
	int processid = 0;
	int webPort;
	char cmd[128] = {0};
	if(strcmp(name,"all") == 0 )
	{
		// 先关闭gameserver
		closeServer("game");
		// 再关闭dbserver
		closeServer("db");

		for(int i = 0; i < sizeof(serverNames) / sizeof(serverNames[0]); i++)
		{
			if(strstr(serverNames[i], "redis") != NULL)
				snprintf(cmd,sizeof(cmd),"ls logs/%s.pid | xargs cat",serverNames[i]);
			else
				snprintf(cmd,sizeof(cmd),"ls logs/%s*.pid | xargs cat",serverNames[i]);
			if((f = popen(cmd,"r")) == NULL)
				continue;
			if(fgets(cmd,sizeof(cmd),f) == NULL)
			{
				pclose(f);
				continue;
			}
			else
				processid = atoi(cmd);

			snprintf(cmd,sizeof(cmd),"kill -9 %d",processid);
			if(system(cmd) == -1)
				FAIL("kill %s fail",serverNames[i]);
			else
				OK("kill <%s> server...ok!",serverNames[i]);
		}

		// stop nginx
		system("etc/nginx/nginx -s stop");
		OK("kill <nginx> server...ok!");
		
		return 0;
	}
	else
	{
		if(strcmp(name, "game") == 0)
		{
			snprintf(cmd, sizeof(cmd), "cat etc/start_game.sh | grep WEB_PORT | cut -b 17-30");
			if((f = popen(cmd,"r")) == NULL)
				return 0;
			if(fgets(cmd,sizeof(cmd),f) == NULL)
			{
				pclose(f);
				return 0;
			}
			else
				webPort = atoi(cmd);
			
			snprintf(cmd, sizeof(cmd), "curl -s -o /dev/null http://127.0.0.1:%d/closeSelf?type=3", webPort);
			if((f = popen(cmd,"r")) == NULL)
				FAIL("notify <%s> close fail!",name);
			OK("notify <%s> close after 2s",name);
		}
		else
		{
			//get pid
			snprintf(cmd,sizeof(cmd),"ls logs/%s*.pid | xargs cat",name);
			if((f = popen(cmd,"r")) == NULL)
				FAIL("not found logs/%s.pid file,stop fail.",name);
			if(fgets(cmd,sizeof(cmd),f) == NULL)
			{
				pclose(f);
				FAIL("get pid error,stop fail.");
			}
			else
				processid = atoi(cmd);

			snprintf(cmd,sizeof(cmd),"kill -9 %d",processid);
			if(system(cmd) == -1)
				FAIL("kill %s fail",name);

			OK("kill <%s> (%d) ok",name,processid);
		}

		return 1;
	}
}

void boot_server(char* name,char* shell)
{
	if(boot_delay > 0)
	{
		OK("start %s server after %ds", name, boot_delay);
		pid_t fpid = fork();
		if(fpid != 0)
			return; // 父进程退出
		sleep(boot_delay);
	}
		
	OK("start %s server...", name);
	char cmd[128] = {0};
	int f_daemon = boot_daemon ? 0 : 1;
	int t_daemon = boot_daemon ? 1 : 0;
	//修改daemon参数
	snprintf(cmd,sizeof(cmd), "sed -i \"s/export DAEMON=%d/export DAEMON=%d/g\" %s", f_daemon, t_daemon, shell);
	if(system(cmd) == -1)
		FAIL("config to daemon = 1 error!");

	//启动程序
	snprintf(cmd,sizeof(cmd),"bash %s",shell);
	if(system(cmd) == -1)
		FAIL("start %s fail,shell:%s",name,shell);

	OK("boot <%s> ok",name);
}

struct option long_options[] = {
	{"help", 0, NULL, 'h'},
	{"login", 0, NULL, 'l'},
	{"game", 0, NULL, 'g'},
	{"battle", 0, NULL, 'b'},
	{"monitor", 0, NULL, 'm'},
	{"stop", 1, NULL, 's'},
	{"center", 0, NULL, 'c'},
	{"db", 0, NULL, 'd'},
	{"whole", 0, NULL, 'w'},
	{"redis", 0, NULL, 'r'},
	{"force", 0, NULL, 'f'},
	{"push", 0, NULL, 'p'},
	{"robot", 0, NULL, 'o'},
	{"git_pull", 1, NULL, 'i'},
	{"chat", 0, NULL, 't'},
	{"log", 0, NULL, 'q'},
	{"nginx", 0, NULL, 'n'},
	{"delay", 1, NULL, 'y'},
	{0, 0, 0, 0},
};

char *const shrot_options = "lgbms:cdwhrfpoi:tnqy:";

void closeAllFd()
{
	// 获取进程ID
	pid_t pid = getpid();

	char path[128] = {0};
	snprintf(path, sizeof(path), "/proc/%d/fd", pid);
	DIR *pDir = opendir(path);
	if(pDir == NULL) return;

	struct dirent *ent;
	while((ent = readdir(pDir)) != NULL)
	{
		int fd = atoi(ent->d_name);
		if(fd > 2)
			close(fd);
	}
}

int main(int argc, char *argv[])
{
	closeAllFd();
	if (argc < 2)
		ShowUsage();

	char process_name[128] = {"all"};
	char branch_name[218] = {0}; int opt;
	while ((opt = getopt_long(argc, argv, shrot_options, long_options, NULL)) != -1)
	{
		switch(opt)
		{
			case 'h':
				ShowUsage();
				break;
			case 'l':
				boot_login = true;
				break;
			case 'g':
				boot_game = true;
				break;
			case 'b':
				boot_battle = true;
				break;
			case 'm':
				boot_monitor = true;
				break;
			case 'c':
				boot_center = true;
				break;
			case 'd':
				boot_db = true;
				break;
			case 'p':
				boot_push = true;
				break;
			case 's':
				stop_server = true;
				strncpy(process_name,optarg,sizeof(process_name));
				break;
			case 'r':
				boot_redis = true;
				break;
			case 'f':
				boot_daemon = true;
				break;
			case 'w':
				boot_all = true;
				break;
			case 'o':
				boot_robot = true;
				break;
			case 'i':
				boot_git = true;
				strncpy(branch_name, optarg, sizeof(branch_name));
				break;
			case 't':
				boot_chat = true;
				break;
			case 'n' :
				boot_nginx = true;
				break;
			case 'q' :
				boot_log = true;
				break;
			case 'y' :
				boot_delay = atoi(optarg);
				break;
			default: /* '?',':' */
				ShowUsage();
				break;
		}
	}

	if (boot_git)
	{
		sleep(1);
		strncpy(process_name, "all", sizeof(process_name));
		char cmd[2048] = {0};
		snprintf(cmd, sizeof(cmd), "git pull && git checkout %s && git pull && git remote prune origin", branch_name);
		if(system(cmd) == -1)
			FAIL("git pull ALD-Server %s fail", branch_name);

		snprintf(cmd, sizeof(cmd), "cd common/protocol && git pull && git checkout %s \
									&& git pull && git remote prune origin && cd -", branch_name);
		if(system(cmd) == -1)
			FAIL("git pull common/protocol %s fail", branch_name);

		snprintf(cmd, sizeof(cmd), "cd common/errorcode && git pull && git checkout %s  \
									&& git pull && git remote prune origin && cd -", branch_name);
		if(system(cmd) == -1)
			FAIL("git pull common/errorcode %s fail", branch_name);

		snprintf(cmd, sizeof(cmd), "cd common/mapmesh && git pull && git checkout %s  \
									&& git pull && git remote prune origin && cd -", branch_name);
		if(system(cmd) == -1)
			FAIL("git pull common/mapmesh %s fail", branch_name);

		snprintf(cmd, sizeof(cmd), "cd common/config && git pull && git checkout %s  \
									&& git pull && git remote prune origin && cd -", branch_name);
		if(system(cmd) == -1)
			FAIL("git pull common/config %s fail", branch_name);

		snprintf(cmd, sizeof(cmd), "make clean && make && make install");
		if(system(cmd) == -1)
			FAIL("make fail!");

		boot_all = true;
	}

	if(boot_all)
	{
		boot_daemon = true;
		stop_server = true;
		boot_login = true;
		boot_game = true;
		boot_battle = true;
		boot_push = true;
		boot_monitor = true;
		boot_center = true;
		boot_db = true;
		boot_redis = true;
		boot_chat = true;
		boot_nginx = true;
		boot_log = true;
	}

	if(stop_server)
		kill_server(process_name);
	if(boot_nginx)
		boot_server("nginx", "etc/start_nginx.sh");
	if(boot_redis)
		boot_server("redis", "etc/start_redis.sh");
	if(boot_monitor)
		boot_server("monitor", "etc/start_monitor.sh");
	if(boot_battle)
		boot_server("battle", "etc/start_battle.sh");
	if(boot_center)
		boot_server("center", "etc/start_center.sh");
	if(boot_db)
		boot_server("db", "etc/start_db.sh");
	if(boot_login)
		boot_server("login", "etc/start_login.sh");
	if(boot_push)
		boot_server("push", "etc/start_push.sh");
	if(boot_game)
		boot_server("game", "etc/start_game.sh");
	if (boot_chat)
		boot_server("chat", "etc/start_chat.sh");
	if (boot_robot)
		boot_server("robot", "etc/start_robot.sh");
	if (boot_log)
		boot_server("log", "etc/start_log.sh");

	return 0;
}