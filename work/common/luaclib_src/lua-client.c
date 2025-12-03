// simple lua socket library for client
// It's only for demo, limited feature. Don't use it in your project.
// Rewrite socket library by yourself .

#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <string.h>
#include <stdint.h>
#include <pthread.h>
#include <stdlib.h>

#include <netinet/in.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <netdb.h>

#define CACHE_SIZE 0x10000

static bool g_threadFlg = false;
static pthread_t g_pid = 0;

static int
lconnect(lua_State *L)
{
    const char *addr = luaL_checkstring(L, 1);
    int port = luaL_checkinteger(L, 2);
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in my_addr;

    struct hostent* hptr = gethostbyname(addr);
    if(hptr == NULL)
        return luaL_error(L, "gethostbyname %s %d failed", addr, port);

    char realAddr[20] = {0};
    inet_ntop(AF_INET, hptr->h_addr_list[0], realAddr, 20);

    my_addr.sin_addr.s_addr = inet_addr(realAddr);
    my_addr.sin_family = AF_INET;
    my_addr.sin_port = htons(port);

    int r = connect(fd, (struct sockaddr *)&my_addr, sizeof(struct sockaddr_in));

    if (r == -1)
    {
        return luaL_error(L, "Connect %s %d failed", addr, port);
    }

    // int flag = fcntl(fd, F_GETFL, 0);
    // fcntl(fd, F_SETFL, flag | O_NONBLOCK);

    lua_pushinteger(L, fd);

    return 1;
}

static int
lclose(lua_State *L)
{
    int fd = luaL_checkinteger(L, 1);
    close(fd);

    return 0;
}

static void
block_send(lua_State *L, int fd, const char *buffer, int sz)
{
    while (sz > 0)
    {
        int r = send(fd, buffer, sz, 0);
        if (r < 0)
        {
            if (errno == EAGAIN || errno == EINTR)
                continue;
            luaL_error(L, "socket error: %s", strerror(errno));
        }
        buffer += r;
        sz -= r;
    }
}

/*
	integer fd
	string message
 */
static int
lsend(lua_State *L)
{
    size_t sz = 0;
    int fd = luaL_checkinteger(L, 1);
    const char *msg = luaL_checklstring(L, 2, &sz);

    block_send(L, fd, msg, (int)sz);

    return 0;
}

/*
	intger fd
	string last
	table result

	return 
		boolean (true: data, false: block, nil: close)
		string last
 */

struct socket_buffer
{
    void *buffer;
    int sz;
};

bool recvblock(int fd, char* buffer, int size, size_t timeout)
{
    if(timeout > 0)
    {
        struct timeval fd_timeout = { timeout, 0 };
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, (char *)&fd_timeout, sizeof(struct timeval));
    }
    char tmp[CACHE_SIZE] = {0};

    while(true){
        int r = recv(fd, tmp, size, 0);
        if (r == 0)
        {
            // close
            return false;
        }
        if (r < 0)
        {
            if (errno == EAGAIN || errno == EINTR)
            {
                if(timeout > 0 && errno == EAGAIN)
                    return false; // time out
                else
                    continue;   // interrupte by system, not error, try again
            }
            else
                printf("recvblock error:%s\n", strerror(errno));
            return false;
        }

        size -= r;
        memcpy( buffer, tmp, r);
        if (size == 0)
            return true;
    }
}

static int
lrecvpack(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    char data[CACHE_SIZE] = {0};
    if(!recvblock(fd, data, 2, 0))
        return -1;
    short sz, *psz;
    psz = (short *)data;
    sz = ntohs(*psz);
    if(!recvblock(fd, data, sz, 0))
        return -1;
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_settop(L, 2);
    lua_pushlstring(L, data, sz);
    lua_pcall(L, 1, 0, 0); // 回调lua函数
    return 0;
}

static int
lrecvline(lua_State *L) {
    int fd = luaL_checkinteger(L, 1);
    while(true) {
        char buffer[CACHE_SIZE] = {0};
        int r = recv(fd, buffer, CACHE_SIZE, MSG_PEEK);
        if (r == 0)
        {
            lua_pushliteral(L, "");
            // close
            return 1;
        }
        if (r < 0)
        {
            if (errno == EAGAIN || errno == EINTR)
            {
                usleep(1);
                continue;
            }
            luaL_error(L, "socket error: %s", strerror(errno));
        }

        for (int i = 0; i < r; i++)
        {
            if (buffer[i] == '\n')
            {
                memset(buffer, 0, sizeof(buffer));
                r = recv(fd, buffer, i + 1, 0);
                if (r == i + 1)
                {
                    lua_pushlstring(L, buffer, r-1); // remove '\n'
                    return 1;
                }
            }
        }
    }
}

static int
lrecv(lua_State *L)
{
    int fd = luaL_checkinteger(L, 1);
    int timeout = 0;
    if(lua_isinteger(L,2))
        timeout = luaL_checkinteger(L, 2);
    char data[CACHE_SIZE] = {0};
    if (!recvblock(fd, data, 2, timeout))
        return 0;
    short sz, *psz;
    psz = (short *)data;
    sz = ntohs(*psz);
    if (!recvblock(fd, data, sz, timeout))
        return 0;
    lua_pushlstring(L, data, sz);
    return 1;
}

static int
lusleep(lua_State *L)
{
    int n = luaL_checknumber(L, 1);
    usleep(n);
    return 0;
}

void* loop_worker(void* arg) {
    int fd = *(int *)arg;
    char buffer[CACHE_SIZE] = {0};
    short sz, *psz;
    while(true){
        if(!recvblock(fd, buffer, 2, 0))
        {
            printf("recvblock head error! break recv loop!\n");
            free(arg);
            return NULL;
        }
        psz = (short *)buffer;
        sz = ntohs(*psz);
        if (!recvblock(fd, buffer, sz, 0))
        {
            printf("recvblock body error! break recv loop!\n");
            free(arg);
            return NULL;
        }
        usleep(10);
    }

    free(arg);
    return NULL;
}

static int
lloop(lua_State *L) {

    int fd = luaL_checkinteger(L, 1);
    pthread_t pid;
    int *threadFd = (int *)malloc(sizeof(fd));
    *threadFd = fd;
    pthread_create(&pid, NULL, loop_worker, threadFd);

    g_pid = pid;
    g_threadFlg = true;

    return 0;
}

static int lstoploop(lua_State *L)
{
    if( g_threadFlg )
    {
        pthread_cancel(g_pid);
        pthread_join(g_pid, NULL);

        g_threadFlg = false;
    }
    
    return 0;
}

LUAMOD_API int
luaopen_clientcore(lua_State *L)
{
    luaL_checkversion(L);
    luaL_Reg l[] = {
        {"connect", lconnect},
        {"recvpack", lrecvpack},
        {"recvline", lrecvline},
        {"recv", lrecv},
        {"send", lsend},
        {"close", lclose},
        {"usleep", lusleep},
        {"loop", lloop},
        {"stoploop", lstoploop},
        {NULL, NULL},
    };
    luaL_newlib(L, l);

    return 1;
}
