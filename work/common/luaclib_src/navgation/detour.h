/*
 * @file : detour.h
 * @type : c
 * @author : linfeng
 * @created : 2019-12-16 13:48:48
 * @Last Modified time: 2019-12-16 13:48:48
 * @department : Arabic Studio
 * @brief : 寻路头文件
 * Copyright(C) 2019 IGG, All rights reserved
*/

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif
    // 寻路,只返回拐点
    float* findStraightPathImpl(void* navQuery, float* spos, float* epos, int* nstraightPathCount);
    
    // 初始化网格
    bool initMesh(void* navQuery, const char* path);

    // 初始化动态网格
    bool initObstraclesMesh(void* navQuery, void* tileCache, const char* path);

    // 根据坐标寻找Ploy
    bool findPloyByPos(void* navQuery, const float* p, unsigned int* ref);

    // 生成NavMeshQuery
    void* newNavMeshQuery();

    // 删除NavMeshQuery
    void freeNavMeshQuery(void* navMeshQuery);

    // 生成TileCache
    void* newTileCache();

    // 删除TileCache
    void freeTileCache(void* tileCache);

    // 添加障碍
    bool addObstraclesObject( void* navQuery, void* tileCache, const float* pos, const float radius, unsigned int* ref, bool delayUpate );

    // 移除障碍
    bool removeObsttaclesObject( void* navQuery, void* tileCache, unsigned int ref );

    // 更新
    bool tickUpdate( void* navQuery, void* tileCache );

    // 检查位置是否空闲
    bool checkPosIdle( void* navQuery, float* c, float* p );
#ifdef __cplusplus
}
#endif