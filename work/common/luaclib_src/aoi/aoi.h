#ifndef _AOI_H
#define _AOI_H

#include <stdint.h>
#include <stddef.h>
#include "../uthash/uthash.h"

typedef void *(*aoi_Alloc)(void *ud, void *ptr, size_t sz);
typedef void(aoi_Callback)(void *ud, uint32_t aoiMapId, uint32_t watcher, uint32_t marker,
                           const char *action, float pos[3], float tpos[3], uint32_t rtype);

struct object
{
    int ref;
    size_t id;
    int mode;
    float last[3];
    float position[3];
    float tposition[3];
    float last_tpos[3];
    int rtype;
    int aoiCount;
};

struct object_set
{
    int cap;
    int number;
    struct object **slot;
};

#define PAIR_KEY_LEN 65
struct pair_list
{
    //size_t key;
    char key[PAIR_KEY_LEN];
    struct pair_list *next;
    struct object *watcher;
    struct object *marker;
    UT_hash_handle hh;
};

struct map_slot
{
    size_t id;
    struct object *obj;
    int next;
};

struct map
{
    int size;
    int lastfree;
    struct map_slot *slot;
};

struct aoi_space
{
    aoi_Alloc alloc;
    void *alloc_ud;
    struct map *object;
    struct object_set *watcher_static;
    struct object_set *marker_static;
    struct object_set *watcher_move;
    struct object_set *marker_move;
    struct pair_list *hot;
    uint32_t aoiMapId;
    uint32_t maxAoiCount;
    struct pair_list *pair_hash;
    // AOI范围
    float aoi_radis2;
};

struct aoi_space *aoi_create(aoi_Alloc alloc, void *ud);
struct aoi_space *aoi_new(float radius);
void aoi_release(struct aoi_space *);

// w(atcher) m(arker) d(rop)
void aoi_update(struct aoi_space *space, uint32_t id, const char *modestring, uint32_t rtype,
                    float pos[3], float tpos[3], aoi_Callback cb, void *ud);
void aoi_message(struct aoi_space *space, aoi_Callback cb, void *ud);

#endif
