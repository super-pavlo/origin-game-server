/*
 * @file : detour.c
 * @type : c
 * @author : linfeng
 * @created : 2019-12-16 13:52:00
 * @Last Modified time: 2019-12-16 13:52:00
 * @department : Arabic Studio
 * @brief : 寻路相关
 * Copyright(C) 2019 IGG, All rights reserved
*/

#include "detour.h"
#include "DetourCommon.h"
#include "DetourNavMeshQuery.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <float.h>
#include "DetourTileCache.h"
#include "DetourTileCacheBuilder.h"
#include "DetourNavMeshBuilder.h"
#include "fastlz.h"

static const int MAX_POLYS = 256;
static const int NAVMESHSET_MAGIC = 'M'<<24 | 'S'<<16 | 'E'<<8 | 'T'; //'MSET';
static const int NAVMESHSET_VERSION = 1;
static const int MAX_SMOOTH = 2048;
float m_straightPath[MAX_POLYS*3];
unsigned char m_straightPathFlags[MAX_POLYS];
dtPolyRef m_straightPathPolys[MAX_POLYS];
dtQueryFilter m_filter;

struct NavMeshSetHeader
{
    int magic;
    int version;
    int numTiles;
    dtNavMeshParams params;
};

struct NavMeshTileHeader
{
    dtTileRef tileRef;
    int dataSize;
};

/// These are just sample areas to use consistent values across the samples.
/// The use should specify these base on his needs.
enum SamplePolyAreas
{
	SAMPLE_POLYAREA_GROUND,
	SAMPLE_POLYAREA_WATER,
	SAMPLE_POLYAREA_ROAD,
	SAMPLE_POLYAREA_DOOR,
	SAMPLE_POLYAREA_GRASS,
	SAMPLE_POLYAREA_JUMP,
};
enum SamplePolyFlags
{
	SAMPLE_POLYFLAGS_WALK		= 0x01,		// Ability to walk (ground, grass, road)
	SAMPLE_POLYFLAGS_SWIM		= 0x02,		// Ability to swim (water).
	SAMPLE_POLYFLAGS_DOOR		= 0x04,		// Ability to move through doors.
	SAMPLE_POLYFLAGS_JUMP		= 0x08,		// Ability to jump.
	SAMPLE_POLYFLAGS_DISABLED	= 0x10,		// Disabled polygon
	SAMPLE_POLYFLAGS_ALL		= 0xffff	// All abilities.
};

struct TileCacheSetHeader
{
	int magic;
	int version;
	int numTiles;
	dtNavMeshParams meshParams;
	dtTileCacheParams cacheParams;
};

struct TileCacheTileHeader
{
	dtCompressedTileRef tileRef;
	int dataSize;
};

/// @name Off-Mesh connections.
///@{
static const int MAX_OFFMESH_CONNECTIONS = 256;
float m_offMeshConVerts[MAX_OFFMESH_CONNECTIONS*3*2];
float m_offMeshConRads[MAX_OFFMESH_CONNECTIONS];
unsigned char m_offMeshConDirs[MAX_OFFMESH_CONNECTIONS];
unsigned char m_offMeshConAreas[MAX_OFFMESH_CONNECTIONS];
unsigned short m_offMeshConFlags[MAX_OFFMESH_CONNECTIONS];
unsigned int m_offMeshConId[MAX_OFFMESH_CONNECTIONS];
int m_offMeshConCount;
///@}

static const int TILECACHESET_MAGIC = 'T'<<24 | 'S'<<16 | 'E'<<8 | 'T'; //'TSET';
static const int TILECACHESET_VERSION = 1;

struct LinearAllocator* m_talloc = nullptr;
struct FastLZCompressor* m_tcomp = nullptr;
struct MeshProcess* m_tmproc = nullptr;

static const int ALLOC_CAPATICY = 12800000;

struct LinearAllocator : public dtTileCacheAlloc
{
	unsigned char* buffer;
	size_t capacity;
	size_t top;
	size_t high;
	
	LinearAllocator(const size_t cap) : buffer(0), capacity(0), top(0), high(0)
	{
		resize(cap);
	}
	
	~LinearAllocator()
	{
		dtFree(buffer);
	}


	void resize(const size_t cap)
	{
		if (buffer)
			dtFree(buffer);
		buffer = (unsigned char*)dtAlloc(cap, DT_ALLOC_PERM);
		capacity = cap;
	}
	
	
	virtual void reset()
	{
		high = dtMax(high, top);
		top = 0;
	}
	
	virtual void* alloc(const size_t size)
	{
		if (!buffer)
			return 0;
		if (top+size > capacity)
			return 0;
		unsigned char* mem = &buffer[top];
		top += size;
		return mem;
	}
	
	virtual void free(void* ptr)
	{
		// Empty
	}

};

struct FastLZCompressor : public dtTileCacheCompressor
{
	virtual int maxCompressedSize(const int bufferSize)
	{
		return (int)(bufferSize* 1.05f);
	}
	
	virtual dtStatus compress(const unsigned char* buffer, const int bufferSize,
							  unsigned char* compressed, const int /*maxCompressedSize*/, int* compressedSize)
	{
		*compressedSize = fastlz_compress((const void *const)buffer, bufferSize, compressed);
		return DT_SUCCESS;
	}
	
	virtual dtStatus decompress(const unsigned char* compressed, const int compressedSize,
								unsigned char* buffer, const int maxBufferSize, int* bufferSize)
	{
		*bufferSize = fastlz_decompress(compressed, compressedSize, buffer, maxBufferSize);
		return *bufferSize < 0 ? DT_FAILURE : DT_SUCCESS;
	}
};


struct MeshProcess : public dtTileCacheMeshProcess
{
	virtual void process(struct dtNavMeshCreateParams* params,
						 unsigned char* polyAreas, unsigned short* polyFlags)
	{
		// Update poly flags from areas.
		for (int i = 0; i < params->polyCount; ++i)
		{
			if (polyAreas[i] == DT_TILECACHE_WALKABLE_AREA)
				polyAreas[i] = SAMPLE_POLYAREA_GROUND;

			if (polyAreas[i] == SAMPLE_POLYAREA_GROUND ||
				polyAreas[i] == SAMPLE_POLYAREA_GRASS ||
				polyAreas[i] == SAMPLE_POLYAREA_ROAD)
			{
				polyFlags[i] = SAMPLE_POLYFLAGS_WALK;
			}
			else if (polyAreas[i] == SAMPLE_POLYAREA_WATER)
			{
				polyFlags[i] = SAMPLE_POLYFLAGS_SWIM;
			}
			else if (polyAreas[i] == SAMPLE_POLYAREA_DOOR)
			{
				polyFlags[i] = SAMPLE_POLYFLAGS_WALK | SAMPLE_POLYFLAGS_DOOR;
			}
		}

		// Pass in off-mesh connections.
		params->offMeshConVerts = m_offMeshConVerts;
		params->offMeshConRad = m_offMeshConRads;
		params->offMeshConDir = m_offMeshConDirs;
		params->offMeshConAreas = m_offMeshConAreas;
		params->offMeshConFlags = m_offMeshConFlags;
		params->offMeshConUserID = m_offMeshConId;
		params->offMeshConCount = m_offMeshConCount;	
	}
};

void* newNavMeshQuery()
{
	return dtAllocNavMeshQuery();
}

void freeNavMeshQuery(void* navMeshQuery)
{
	if(navMeshQuery != NULL)
		dtFreeNavMeshQuery((dtNavMeshQuery*)navMeshQuery);
}

void* newTileCache()
{
	return dtAllocTileCache();
}

void freeTileCache(void* tileCache)
{
	if(tileCache != NULL)
		dtFreeTileCache((dtTileCache*)tileCache);
}

dtNavMesh* loadMeshFromBin(const char*path)
{
    FILE* fp = fopen(path, "rb");
	if (!fp)
        return 0;

	// Read header.
	NavMeshSetHeader header;
	size_t readLen = fread(&header, sizeof(NavMeshSetHeader), 1, fp);
	if (readLen != 1)
	{
		fclose(fp);
		return 0;
	}
	if (header.magic != NAVMESHSET_MAGIC)
	{
		fclose(fp);
		return 0;
	}
	if (header.version != NAVMESHSET_VERSION)
	{
		fclose(fp);
		return 0;
	}

	dtNavMesh* mesh = dtAllocNavMesh();
	if (!mesh)
	{
		fclose(fp);
		return 0;
	}
	dtStatus status = mesh->init(&header.params);
	if (dtStatusFailed(status))
	{
		fclose(fp);
		return 0;
	}

	// Read tiles.
	for (int i = 0; i < header.numTiles; ++i)
	{
		NavMeshTileHeader tileHeader;
		readLen = fread(&tileHeader, sizeof(tileHeader), 1, fp);
		if (readLen != 1)
		{
			fclose(fp);
			return 0;
		}

		if (!tileHeader.tileRef || !tileHeader.dataSize)
			break;

		unsigned char* data = (unsigned char*)dtAlloc(tileHeader.dataSize, DT_ALLOC_PERM);
		if (!data) break;
		memset(data, 0, tileHeader.dataSize);
		readLen = fread(data, tileHeader.dataSize, 1, fp);
		if (readLen != 1)
		{
			dtFree(data);
			fclose(fp);
			return 0;
		}

		mesh->addTile(data, tileHeader.dataSize, DT_TILE_FREE_DATA, tileHeader.tileRef, 0);
	}

	fclose(fp);

	return mesh;
}

bool initMesh(void* navQuery, const char* path)
{
	dtNavMesh* navMesh = loadMeshFromBin(path);
    if(navMesh == nullptr)
        return false;
    dtStatus status = ((dtNavMeshQuery*)navQuery)->init(navMesh, 2048);
    if (!dtStatusSucceed(status)) 
    {
        dtFreeNavMesh(navMesh);
        return false;
    }

	// init filter
	m_filter.setIncludeFlags(SAMPLE_POLYFLAGS_ALL ^ SAMPLE_POLYFLAGS_DISABLED);
	m_filter.setExcludeFlags(0);
	// Change costs.
	m_filter.setAreaCost(SAMPLE_POLYAREA_GROUND, 1.0f);
	m_filter.setAreaCost(SAMPLE_POLYAREA_WATER, 10.0f);
	m_filter.setAreaCost(SAMPLE_POLYAREA_ROAD, 1.0f);
	m_filter.setAreaCost(SAMPLE_POLYAREA_DOOR, 1.0f);
	m_filter.setAreaCost(SAMPLE_POLYAREA_GRASS, 2.0f);
	m_filter.setAreaCost(SAMPLE_POLYAREA_JUMP, 1.5f);

    return true;
}

bool initObstraclesMesh(void* navQuery, void* tileCache, const char* path)
{
	FILE* fp = fopen(path, "rb");
	if (!fp)
		return false;
	
	// Read header.
	TileCacheSetHeader header;
	size_t headerReadReturnCode = fread(&header, sizeof(TileCacheSetHeader), 1, fp);
	if( headerReadReturnCode != 1)
	{
		// Error or early EOF
		fclose(fp);
		return false;
	}
	if (header.magic != TILECACHESET_MAGIC)
	{
		fclose(fp);
		return false;
	}
	if (header.version != TILECACHESET_VERSION)
	{
		fclose(fp);
		return false;
	}
	
	dtNavMesh* navMesh = dtAllocNavMesh();
	if (!navMesh)
	{
		fclose(fp);
		return false;
	}
	dtStatus status = navMesh->init(&header.meshParams);
	if (dtStatusFailed(status))
	{
		fclose(fp);
		return false;
	}

	m_talloc = new LinearAllocator(ALLOC_CAPATICY);
	m_tcomp = new FastLZCompressor;
	m_tmproc = new MeshProcess;
	status = ((dtTileCache*)tileCache)->init(&header.cacheParams, m_talloc, m_tcomp, m_tmproc);
	if (dtStatusFailed(status))
	{
		fclose(fp);
		return false;
	}
		
	// Read tiles.
	for (int i = 0; i < header.numTiles; ++i)
	{
		TileCacheTileHeader tileHeader;
		size_t tileHeaderReadReturnCode = fread(&tileHeader, sizeof(tileHeader), 1, fp);
		if( tileHeaderReadReturnCode != 1)
		{
			// Error or early EOF
			fclose(fp);
			return false;
		}
		if (!tileHeader.tileRef || !tileHeader.dataSize)
			break;

		unsigned char* data = (unsigned char*)dtAlloc(tileHeader.dataSize, DT_ALLOC_PERM);
		if (!data) break;
		memset(data, 0, tileHeader.dataSize);
		size_t tileDataReadReturnCode = fread(data, tileHeader.dataSize, 1, fp);
		if( tileDataReadReturnCode != 1)
		{
			// Error or early EOF
			dtFree(data);
			fclose(fp);
			return false;
		}
		
		dtCompressedTileRef tile = 0;
		dtStatus addTileStatus = ((dtTileCache*)tileCache)->addTile(data, tileHeader.dataSize, DT_COMPRESSEDTILE_FREE_DATA, &tile);
		if (dtStatusFailed(addTileStatus))
		{
			dtFree(data);
		}

		if (tile)
			((dtTileCache*)tileCache)->buildNavMeshTile(tile, navMesh);
	}
	
	fclose(fp);

    status = ((dtNavMeshQuery*)navQuery)->init(navMesh, 4096);
    if (!dtStatusSucceed(status)) 
    {
        dtFreeNavMesh(navMesh);
        return false;
    }

	// init filter
	m_filter.setIncludeFlags(SAMPLE_POLYFLAGS_ALL ^ SAMPLE_POLYFLAGS_DISABLED);
	m_filter.setExcludeFlags(0);
	// Change costs.
	m_filter.setAreaCost(SAMPLE_POLYAREA_GROUND, 1.0f);
	m_filter.setAreaCost(SAMPLE_POLYAREA_WATER, 10.0f);
	m_filter.setAreaCost(SAMPLE_POLYAREA_ROAD, 1.0f);
	m_filter.setAreaCost(SAMPLE_POLYAREA_DOOR, 1.0f);
	m_filter.setAreaCost(SAMPLE_POLYAREA_GRASS, 2.0f);
	m_filter.setAreaCost(SAMPLE_POLYAREA_JUMP, 1.5f);

    return true;
}

float* findStraightPathImpl(void* navQuery, float* spos, float* epos, int* nstraightPathCount)
{
    int npolys = 0;
    dtPolyRef polys[MAX_POLYS];
    dtQueryFilter filter;
	dtPolyRef startRef, endRef;
	if(!findPloyByPos(navQuery, spos, &startRef))
		return nullptr;
	if(!findPloyByPos(navQuery, epos, &endRef))
		return nullptr;

    ((dtNavMeshQuery*)navQuery)->findPath(startRef, endRef, spos, epos, &filter, polys, &npolys, MAX_POLYS);
    if (npolys > 0)
    {
        // In case of partial path, make sure the end point is clamped to the last polygon.
        float tepos[3];
        dtVcopy(tepos, epos);
        if (polys[npolys-1] != endRef)
			((dtNavMeshQuery*)navQuery)->closestPointOnPoly(polys[npolys-1], epos, tepos, 0);

        int straightPathOptions = 0;
        ((dtNavMeshQuery*)navQuery)->findStraightPath(spos, tepos, polys, npolys, m_straightPath, m_straightPathFlags,
                                        m_straightPathPolys, nstraightPathCount, MAX_POLYS, straightPathOptions);
    }

	return m_straightPath;
}

bool findPloyByPos(void* navQuery, const float* p, unsigned int* ref)
{
    const float halfExtents[3] = { 1, 1, 1 };
    return dtStatusSucceed(((dtNavMeshQuery*)navQuery)->findNearestPoly(p, halfExtents, &m_filter, ((dtPolyRef*)ref), 0));
}

bool checkPosIdle( void* navQuery, float* c, float* p )
{
	dtPolyRef startRef;
	if(!findPloyByPos(navQuery, c, &startRef))
		return false;

	float t;
	dtPolyRef path[MAX_POLYS];
	dtStatus status = ((dtNavMeshQuery*)navQuery)->raycast(startRef, c, p, &m_filter, &t, nullptr, (dtPolyRef*)path, nullptr, MAX_POLYS);
	if(dtStatusSucceed(status))
		return t == FLT_MAX;

	/*
	const float halfExtents[3] = { 1, 1, 1 };
	dtPolyRef ref;
	float nearPos[3] = {0, 0, 0};
    if(dtStatusSucceed(((dtNavMeshQuery*)navQuery)->findNearestPoly(p, halfExtents, &m_filter, &ref, nearPos)))
	{
		if(ref > 0)
		{
			p[1] = 0;
			nearPos[1] = 0;
			return dtVequal(p, nearPos);
		}
	}
	*/

	return false;
}

bool addObstraclesObject( void* navQuery, void* tileCache, const float* pos, const float radius, unsigned int* ref, bool delayUpate)
{
	if (!tileCache)
		return false;
		
	dtStatus status = ((dtTileCache*)tileCache)->addObstacle(pos, radius, 10.0f, (dtObstacleRef*)ref);
	bool success = dtStatusSucceed(status);
	if(delayUpate)
	{
		if(!success)
		{
			// buffer is full, trigger update
			if(dtStatusDetail(status, DT_BUFFER_TOO_SMALL))
			{
				if(tickUpdate(navQuery, tileCache))
				{
					status = ((dtTileCache*)tileCache)->addObstacle(pos, radius, 10.0f, (dtObstacleRef*)ref);
					success = dtStatusSucceed(status);
				}
			}
		}
	}
	else
	{
		if(success)
			return tickUpdate(navQuery, tileCache);
	}
	
	return success;
}

bool removeObsttaclesObject( void* navQuery, void* tileCache, unsigned int ref )
{
	if (!tileCache)
		return false;
	dtStatus status = ((dtTileCache*)tileCache)->removeObstacle((dtObstacleRef)ref);
	bool success = dtStatusSucceed(status);
	if(success)
		return tickUpdate(navQuery, tileCache);
		
	return success;
}

bool tickUpdate( void* navQuery, void* tileCache )
{
	bool upToDate = false;
	dtNavMesh* navMeshQuery = (dtNavMesh*)(((dtNavMeshQuery*)navQuery)->getAttachedNavMesh());
	while(!upToDate)
	{
		dtStatus status = ((dtTileCache*)tileCache)->update(0, navMeshQuery, &upToDate);
		if(!dtStatusSucceed(status))
		{
			printf("tickUpdate fail:%d\n", status);
			return false;
		}
	}
	return true;
}