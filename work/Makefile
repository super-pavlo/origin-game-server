#自动区分平台
OS := $(shell uname)
ifeq ($(OS), $(filter $(OS), Darwin))
	PLAT=macosx
else 
	PLAT=linux
endif

.PHONY: all skynet clean install

SHARED := -fPIC --shared
LUA_CLIB_PATH ?= common/luaclib
REDIS_PATH ?= etc/redis
PREFIX ?= bin
LUA_INC_PATH ?= 3rd/skynet/3rd/lua
ZLIB_INC_PATH ?= 3rd/zlib
CURL_INC_PATH ?= common/luaclib_src
CFLAGS = -g -O2 -Wall -std=gnu99 -lrt
CXXFLAGS = -g -O2 -Wall -lrt -std=c++11
BINEXE = co
TAR ?= CO-Server.tar.gz
DETOURLIB ?= 3rd/navgation/Detour/build
DETOURINCLUDE ?= 3rd/navgation/Detour/Include
DETOURTILECACHELIB ?= 3rd/navgation/DetourTileCache/build
DETOURTILECACHEINCLUDE ?= 3rd/navgation/DetourTileCache/Include
RECASTLIB ?= 3rd/navgation/Recast/build
RECASTINCLUDE ?= 3rd/navgation/Recast/Include
PUBLISH_NAME ?= gitlab+deploy-token-13
PUBLISH_PASSWD ?= oJGZgzzTurpN1rX54ju2

BIN = $(LUA_CLIB_PATH)/lfs.so $(LUA_CLIB_PATH)/aoi.so $(LUA_CLIB_PATH)/reg.so \
		$(LUA_CLIB_PATH)/log.so $(LUA_CLIB_PATH)/cjson.so $(LUA_CLIB_PATH)/timer.so \
		$(LUA_CLIB_PATH)/LuaXML_lib.so $(LUA_CLIB_PATH)/clientcore.so \
		$(LUA_CLIB_PATH)/skiplist.so\
		$(LUA_CLIB_PATH)/libDetour.a $(LUA_CLIB_PATH)/libDetourTileCache.a \
		$(LUA_CLIB_PATH)/libDetourNavMesh.a $(LUA_CLIB_PATH)/detour.so \
		$(LUA_CLIB_PATH)/libRecast.a $(LUA_CLIB_PATH)/libRecastNavMesh.a \
		$(LUA_CLIB_PATH)/recast.so $(LUA_CLIB_PATH)/astar.so $(LUA_CLIB_PATH)/hmacmd5.so\
		$(LUA_CLIB_PATH)/zlib.so $(LUA_CLIB_PATH)/curl.so \
		start tool/script/client/StressTest skynet

all : skynet

skynet :
	cd 3rd/skynet && git checkout skynet-src/skynet_timer.c && cd -
	cd 3rd/skynet/3rd/lua && git checkout lvm.c llimits.h && cd -
	cd 3rd/skynet && git checkout lualib/snax/interface.lua && cd -
	cd 3rd/skynet && git checkout service-src/service_snlua.c && cd -
	sed -i "s/skynet_error(ctx, \"Set memory limit to %.2f M\"/\/\/skynet_error(ctx, \"Set memory limit to %.2f M\"/g" 3rd/skynet/service-src/service_snlua.c
	sed -i "s/local errlist = {}/local errlist = {}\n\tname = string.gsub(name, \"%d\", \"\")/g" 3rd/skynet/lualib/snax/interface.lua
	echo -e "lua_Number luai_numdiv(lua_State *L, lua_Number a, lua_Number b) { if(b != cast_num(0)) return (a)/(b); else luaG_runerror(L,\"division by zero\"); }" >> 3rd/skynet/3rd/lua/lvm.c
	sed -i "/#if !defined(luai_numdiv)/,+2d" 3rd/skynet/3rd/lua/llimits.h
	sed -i "s/\/\* float division \*\//LUA_API lua_Number luai_numdiv(lua_State *L, lua_Number a, lua_Number b);/g" 3rd/skynet/3rd/lua/llimits.h
	#open for time debug
	#sed -i "s/clock_gettime(CLOCK_MONOTONIC/clock_gettime(CLOCK_REALTIME/g" 3rd/skynet/skynet-src/skynet_timer.c
	cd 3rd/skynet && $(MAKE) $(PLAT) && cd - && cp 3rd/skynet/skynet $(BINEXE)

all : \
	$(foreach v, $(BIN), $(v))

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(REDIS_PATH) :
	mkdir $(REDIS_PATH)

$(LUA_CLIB_PATH)/log.so : common/luaclib_src/lua-log.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INC_PATH) $^ -o $@

$(LUA_CLIB_PATH)/LuaXML_lib.so : common/luaclib_src/LuaXML_lib.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INC_PATH) $^ -o $@

$(LUA_CLIB_PATH)/cjson.so : $(LUA_CLIB_PATH)
	cd 3rd/lua-cjson && $(MAKE) && cd - && cp 3rd/lua-cjson/cjson.so $@

$(LUA_CLIB_PATH)/lfs.so : $(LUA_CLIB_PATH)
	cd 3rd/luafilesystem && $(MAKE) && cd - && cp 3rd/luafilesystem/src/lfs.so $(LUA_CLIB_PATH)/lfs.so

$(LUA_CLIB_PATH)/aoi.so : common/luaclib_src/aoi/aoi.c common/luaclib_src/aoi/lua-aoi.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INC_PATH) $^ -o $@

$(LUA_CLIB_PATH)/clientcore.so : common/luaclib_src/lua-client.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INC_PATH) $^ -o $@ -lpthread

$(LUA_CLIB_PATH)/skiplist.so : $(LUA_CLIB_PATH)
	cd 3rd/lua-zset && $(MAKE) && cd - && cp 3rd/lua-zset/skiplist.so $@ && cp 3rd/lua-zset/zset.lua common/lualib

$(LUA_CLIB_PATH)/reg.so : common/luaclib_src/lua-reg.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INC_PATH) $^ -o $@

$(LUA_CLIB_PATH)/timer.so : common/luaclib_src/lua-timer.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INC_PATH) $^ -o $@

$(LUA_CLIB_PATH)/hmacmd5.so : common/luaclib_src/hmacmd5/lua-hmacmd5.c common/luaclib_src/hmacmd5/md5.c common/luaclib_src/hmacmd5/hmac-md5.c common/luaclib_src/hmacmd5/cmd5.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INC_PATH) $^ -o $@

$(LUA_CLIB_PATH)/libDetour.a : $(LUA_CLIB_PATH)
	cd 3rd/navgation/Detour && rm -rf build && mkdir build && cd build && cmake .. && make && cd ../../../../

$(LUA_CLIB_PATH)/libDetourTileCache.a : $(LUA_CLIB_PATH)
	cd 3rd/navgation/DetourTileCache && rm -rf build && mkdir build && cd build && cmake .. && make && cd ../../../../

$(LUA_CLIB_PATH)/libDetourNavMesh.a : common/luaclib_src/navgation/detour.cpp | $(LUA_CLIB_PATH)
	$(CXX) $(CXXFLAGS) $(SHARED) -I$(DETOURINCLUDE) -I$(DETOURTILECACHEINCLUDE) -L$(DETOURLIB) -L$(DETOURTILECACHELIB) $^ -o $@ -lDetourTileCache -lDetour

$(LUA_CLIB_PATH)/detour.so : common/luaclib_src/navgation/lua-detour.c common/luaclib_src/navgation/fastlz.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INC_PATH) -I$(DETOURINCLUDE) -L$(LUA_CLIB_PATH) $^ -o $@ -lDetourNavMesh

$(LUA_CLIB_PATH)/libRecast.a : $(LUA_CLIB_PATH)
	cd 3rd/navgation/Recast && rm -rf build && mkdir build && cd build && cmake .. && make && cd ../../../../

$(LUA_CLIB_PATH)/libRecastNavMesh.a : common/luaclib_src/navgation/recastnavmesh.cpp common/luaclib_src/navgation/MeshLoaderObj.cpp common/luaclib_src/navgation/ChunkyTriMesh.cpp common/luaclib_src/navgation/BuildContext.cpp | $(LUA_CLIB_PATH)
	$(CXX) $(CXXFLAGS) $(SHARED) -I$(LUA_INC_PATH) -I$(RECASTINCLUDE) -L$(RECASTLIB) -I$(DETOURINCLUDE) -I$(DETOURTILECACHEINCLUDE) -L$(DETOURTILECACHELIB) -L$(DETOURLIB) -L$(LUA_INC_PATH) $^ -o $@ -lRecast -lDetourTileCache -lDetour

$(LUA_CLIB_PATH)/recast.so : common/luaclib_src/navgation/lua-recast.c common/luaclib_src/navgation/fastlz.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INC_PATH) -I$(RECASTINCLUDE) -I$(DETOURINCLUDE) -L$(LUA_INC_PATH) -L$(LUA_CLIB_PATH) $^ -o $@ -lRecastNavMesh

$(LUA_CLIB_PATH)/astar.so : common/luaclib_src/astar/lua-astar.c common/luaclib_src/astar/AStar.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INC_PATH) $^ -o $@

$(LUA_CLIB_PATH)/zlib.so : common/luaclib_src/lua_zlib.c
	cd 3rd/zlib && rm -rf build && mkdir build && cd build && cmake .. && make && cp libz.a ../../../$(LUA_CLIB_PATH) && cp zconf.h ../ && cd ../../
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INC_PATH) -I$(ZLIB_INC_PATH) -L$(LUA_CLIB_PATH) $^ -o $@ -lz

$(LUA_CLIB_PATH)/curl.so :common/luaclib_src/lua_curl.c
	$(CC) $(CFLAGS) $(SHARED) -I$(LUA_INC_PATH) -I$(ZLIB_INC_PATH) -I$(CURL_INC_PATH) -L$(LUA_CLIB_PATH) $^ -o $@ -lcurl

start : common/luaclib_src/start.c
	$(CC) $(CFLAGS) $^ -o $@ 

tool/script/client/StressTest : common/luaclib_src/StressTest.c
	$(CC) $(CFLAGS) -Wl,-E -I$(LUA_INC_PATH) -L$(LUA_INC_PATH) $^ -o $@ -llua -lpthread -lm -ldl 

install : all | $(PREFIX)
	cp -r common/luaclib $(PREFIX)/common
	cp -r common/lualib $(PREFIX)/common
	cp -r common/service $(PREFIX)/common
	cp -r common/protocol/*.sproto $(PREFIX)/common/protocol
	cp -r common/errorcode/* $(PREFIX)/common/errorcode
	cp -r common/mapmesh/* $(PREFIX)/common/mapmesh
	cp -r common/config/gen/*.data $(PREFIX)/common/config/gen
	cp 3rd/skynet/skynet $(PREFIX)/$(BINEXE)
	cp -r 3rd/skynet/luaclib $(PREFIX)/3rd/skynet/
	cp -r 3rd/skynet/lualib $(PREFIX)/3rd/skynet/
	cp -r 3rd/skynet/service $(PREFIX)/3rd/skynet/
	cp -r 3rd/skynet/cservice $(PREFIX)/3rd/skynet/
	cp start $(PREFIX)/
	cp -r server $(PREFIX)
	rm -rf $(PREFIX)/server/monitor_server/html

update : install
	rm -rf $(TAR)
	cd $(PREFIX) && tar -zcvf $(TAR) * && cd - && cp $(PREFIX)/$(TAR) ./
	rm -rf $(PREFIX)

$(PREFIX) :
	rm -rf $(PREFIX)
	mkdir $(PREFIX)
	mkdir -p $(PREFIX)/common
	mkdir -p $(PREFIX)/common/config/gen
	mkdir -p $(PREFIX)/common/errorcode
	mkdir -p $(PREFIX)/common/protocol
	mkdir -p $(PREFIX)/common/mapmesh
	mkdir -p $(PREFIX)/server
	mkdir -p $(PREFIX)/3rd/skynet

publish : install
	mkdir -p Global/server/ocserver
	mv bin/* Global/server/ocserver
	mv Global bin/
	echo -e '- name: ocserver\n  contents: ocserver' > bin/makepkg.yaml
	chmod +x ./tool/publish/gamepkg-push
	./tool/publish/gamepkg-push --registry-password $(PUBLISH_PASSWD) --registry-username $(PUBLISH_NAME) \
	--source-dir bin --repo gamepkg/origin-of-conquerors --tag latest
	rm -rf bin

photfix :
	mkdir bin
	mkdir -p Global/server/ocserver
	cp -r hotfix Global/server/ocserver/
	cp -r server Global/server/ocserver/
	rm -rf Global/server/ocserver/server/monitor_server/html
	mkdir -p Global/server/ocserver/common
	cp -r common/lualib Global/server/ocserver/common/lualib
	cp -r common/service Global/server/ocserver/common/service
	mv Global bin/
	echo -e '- name: ocserver\n  contents: ocserver' > bin/makepkg.yaml
	chmod +x ./tool/publish/gamepkg-push
	./tool/publish/gamepkg-push --registry-password $(PUBLISH_PASSWD) --registry-username $(PUBLISH_NAME) \
	--source-dir bin --repo gamepkg/origin-of-conquerors --tag latest
	rm -rf bin
	rm -rf hotfix/allservice/*
	rm -rf hotfix/snax/*

config :
	mkdir bin
	mkdir -p Global/server/ocserver/common/config/gen
	cp common/config/gen/Configs.data Global/server/ocserver/common/config/gen/
	mv Global bin/
	echo -e '- name: ocserver\n  contents: ocserver' > bin/makepkg.yaml
	chmod +x ./tool/publish/gamepkg-push
	./tool/publish/gamepkg-push --registry-password $(PUBLISH_PASSWD) --registry-username $(PUBLISH_NAME) \
	--source-dir bin --repo gamepkg/origin-of-conquerors --tag latest
	rm -rf bin

sql :
	mkdir -p Global/dbsql
	cp tool/sql/oc.sql Global/dbsql/
	mv Global bin/
	chmod +x ./tool/publish/gamepkg-push
	./tool/publish/gamepkg-push --registry-password $(PUBLISH_PASSWD) --registry-username $(PUBLISH_NAME) \
	--source-dir bin --repo gamepkg/origin-of-conquerors --tag dbsql
	rm -rf bin

navmesh :
	./3rd/skynet/3rd/lua/lua common/mapmesh/buildNavMesh.lua pvp && ./3rd/skynet/3rd/lua/lua common/mapmesh/buildNavMesh.lua nobuild && ./3rd/skynet/3rd/lua/lua common/mapmesh/buildNavMesh.lua world

remake :
	make clean && make

debug :
	sed -i "s/MYCFLAGS=-I..\/..\/skynet-src -g/MYCFLAGS=-I..\/..\/skynet-src -g -DLUA_USE_APICHECK/g" 3rd/skynet/3rd/lua/Makefile
	sed -i "s/\/\/ #define MEMORY_CHECK/#define MEMORY_CHECK/g" 3rd/skynet/skynet-src/malloc_hook.c

release :
	cd 3rd/skynet && git checkout 3rd/lua/Makefile && git checkout skynet-src/malloc_hook.c && cd -

clean :
	rm -rf $(LUA_CLIB_PATH)/*
	rm -rf $(PREFIX)
	rm -f start
	rm -rf $(BINEXE)
	rm -rf $(TAR)
	rm -rf etc/*.lua
	rm -f tool/script/client/StressTest
	cd 3rd/luafilesystem && $(MAKE) clean && cd -
	cd 3rd/lua-cjson && $(MAKE) clean && cd -
	cd 3rd/skynet && $(MAKE) clean && cd -
	cd 3rd/skynet/3rd/lua && $(MAKE) clean && cd -