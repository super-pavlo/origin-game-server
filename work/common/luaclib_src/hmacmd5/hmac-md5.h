#ifndef _HMAC_MD5_H
#define _HMAC_MD5_H

int hmac_md5_c (const void *key, size_t keylen, const void *in, size_t inlen, void *resbuf);

#endif /* _HMAC_MD5_H */