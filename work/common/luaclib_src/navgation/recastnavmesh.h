/*
 * @file : recastnavmesh.h
 * @type : c
 * @author : linfeng
 * @created : 2020-04-26 15:20:23
 * @Last Modified time: 2020-04-26 15:20:23
 * @department : Arabic Studio
 * @brief : 寻路网格生成头文件
 * Copyright(C) 2019 IGG, All rights reserved
*/

#include <string.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif
    bool loadMeshObj( const char* filapath );
    void* buildMeshObj();
    bool saveNavMesh(const char* filapath);
    void* buildObstaclesNavMesh();
    bool saveObstaclesNavMesh(const char* filapath);
#ifdef __cplusplus
}
#endif