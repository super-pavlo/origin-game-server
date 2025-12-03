/*
 * @file : lua-rsa.c
 * @type : C
 * @author : linfeng
 * @created : 2019-09-03 11:10:18
 * @Last Modified time: 2019-09-03 11:10:18
 * @department : Arabic Studio
 * @brief : rsa算法
 * Copyright(C) 2019 IGG, All rights reserved
*/

#include <lua.h>
#include <lauxlib.h>
#include <openssl/sha.h>
#include <openssl/rsa.h>
#include <openssl/pem.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>

static
RSA* read_private_key(const char* key)
{
    BIO* keybio = BIO_new_mem_buf(key, -1);
    if(keybio == NULL)
        return NULL;
    RSA* rsa = RSA_new();
    rsa = PEM_read_bio_RSAPrivateKey(keybio, NULL, NULL, NULL);
    BIO_free_all(keybio);
    return rsa;
}

static
RSA * read_public_key(const char* key)
{
    BIO *bio = NULL;
    RSA *rsa = NULL;
    //read public key from string
    if (NULL == (bio = BIO_new_mem_buf(key, -1)))
    {
        fprintf(stderr, "BIO_new_mem_buf failed!\n");
        return NULL;
    }
    //get rsa struct from bio
    rsa = PEM_read_bio_RSA_PUBKEY(bio, NULL, NULL, NULL);
    if (!rsa)
    {
        printf("Failed to load public key\n");

        BIO_free_all(bio);
        return NULL;
    }

    BIO_free_all(bio);

    return rsa;
}

static
void to_sha256(const char* message, size_t len, unsigned char *digest)
{
    SHA256_CTX c;
    SHA256_Init(&c);
    SHA256_Update(&c, message, len);
    SHA256_Final(digest, &c);
    OPENSSL_cleanse(&c, sizeof(c));
}

static
int lrsa_sha256_sign(lua_State *L)
{
    size_t srclen;
    const char* src = lua_tolstring(L, 1, &srclen);
    const char* key = lua_tolstring(L, 2, NULL);

    // create private key
    RSA* p_rsa = read_private_key(key);
    if(NULL == p_rsa)
        return 0;

    // init
    unsigned char dest[SHA256_DIGEST_LENGTH] = {0};
    to_sha256(src, srclen, dest);

    // malloc
    unsigned char* sig = NULL;
    unsigned sig_len = 0;
    int rsa_len = RSA_size(p_rsa);

    sig = (unsigned char*)malloc(rsa_len);
    memset(sig, 0, rsa_len);

    // sign
    int rc = RSA_sign( NID_sha256, dest, sizeof dest, sig , &sig_len , p_rsa );
    if(1 == rc)
        lua_pushlstring(L, (const char*)sig, sig_len);

    // free
    RSA_free(p_rsa);
    free(sig);

    return rc;
}

static
int lrsa_sha256_verify(lua_State *L)
{
    size_t sig_len = 0;
    size_t msg_len = 0;
    unsigned char* sig = (unsigned char*)lua_tolstring(L, 1, &sig_len);
    const char* message = lua_tolstring(L, 2, &msg_len);
    const char* key = lua_tolstring(L, 3, NULL);

    // create private key
    RSA* p_rsa = read_public_key(key);
    if(NULL == p_rsa)
        return 0;

    unsigned char dest[SHA256_DIGEST_LENGTH];
    to_sha256(message, msg_len, dest);

    int rc = RSA_verify(NID_sha256, dest, sizeof dest, sig, sig_len, p_rsa);
    if (1 != rc)
    {
        printf("Verification failed\n");
        lua_pushboolean(L, false);
        return 1;
    }

    // free
    RSA_free(p_rsa);
    free(sig);

    lua_pushboolean(L, true);
    return 1;
}

int luaopen_rsa_core(lua_State* L)
{
    luaL_checkversion(L);
    luaL_Reg l[] =
        {
            {"rsa_sha256_sign", lrsa_sha256_sign},
            {"rsa_sha256_verify", lrsa_sha256_verify},
            {NULL, NULL},
        };
    luaL_newlib(L, l);

    return 1;
}