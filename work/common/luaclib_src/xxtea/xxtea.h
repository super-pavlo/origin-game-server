/**********************************************************\
|                                                          |
| xxtea.h                                                  |
|                                                          |
| XXTEA encryption algorithm library for C.                |
|                                                          |
| Encryption Algorithm Authors:                            |
|      David J. Wheeler                                    |
|      Roger M. Needham                                    |
|                                                          |
| Code Authors: Chen fei <cf850118@163.com>                |
|               Ma Bingyao <mabingyao@gmail.com>           |
| LastModified: Mar 3, 2015                                |
|                                                          |
\**********************************************************/

#ifndef XXTEA_INCLUDED
#define XXTEA_INCLUDED

#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Function: xxtea_encrypt
 * @data:    Data to be encrypted
 * @len:     Length of the data to be encrypted
 * @key:     Symmetric key
 * @out_len: Pointer to output length variable
 * Returns:  Encrypted data or %NULL on failure
 *
 * Caller is responsible for freeing the returned buffer.
 */
void * xxtea_encrypt(const void * data, size_t len, const void * key, size_t * out_len);

/**
 * Function: xxtea_decrypt
 * @data:    Data to be decrypted
 * @len:     Length of the data to be decrypted
 * @key:     Symmetric key
 * @out_len: Pointer to output length variable
 * Returns:  Decrypted data or %NULL on failure
 *
 * Caller is responsible for freeing the returned buffer.
 */
void * xxtea_decrypt(const void * data, size_t len, const void * key, size_t * out_len);

#define XXTEA_KEY "&*@jx12(*@!kd12x"
#define XXTEA_ENCRYPT                                                  \
    lua_unlock(D->L);                                                  \
    size_t out_len;                                                    \
    void *out = xxtea_encrypt(b, size, XXTEA_KEY, &out_len);           \
    D->status = (*D->writer)(D->L, &out_len, sizeof(size_t), D->data); \
    D->status = (*D->writer)(D->L, out, out_len, D->data);             \
    free(out);

#define XXTEA_DECRYPT                                              \
    size_t des_len;                                                \
    if (luaZ_read(S->Z, &des_len, sizeof(size_t)) != 0)            \
        error(S, "truncated");                                     \
    uint8_t *data = (uint8_t *)malloc(des_len);                    \
    if (luaZ_read(S->Z, data, des_len) != 0)                       \
    {                                                              \
        free(data);                                                \
        error(S, "truncated");                                     \
    }                                                              \
    size_t out_len; \
    void *out = xxtea_decrypt(data, des_len, XXTEA_KEY, &out_len); \
    if (out_len != size)                                           \
    {                                                              \
        free(out);                                                 \
        free(data);                                                \
        error(S, "truncated");                                     \
    }                                                              \
    memcpy(b, out, size);                                          \
    free(out);                                                     \
    free(data);

#ifdef XXTEA_INCLUDE_DUMP
#include "../../../3rd/skynet/3rd/lua/lundump.h"
#endif

#ifdef XXTEA_INCLUDE_UNDUMP
#include "../../../3rd/skynet/3rd/lua/lzio.h"
#endif

#ifdef __cplusplus
}
#endif

#endif
