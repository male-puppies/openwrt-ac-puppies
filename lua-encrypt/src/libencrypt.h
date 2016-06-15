#ifndef __LIB_ENCRYPT_H__
#define __LIB_ENCRYPT_H__

typedef unsigned int encrypt_header_t;

void encrypt_get_header(encrypt_header_t *h, int *type, int *len);

void encrypt_set_header(encrypt_header_t *h, int type, int len);

int encrypt_init();

char *encrypt_encode01(int type, const char *s, int slen, int *outlen);

char *encrypt_encode2(int type, const char *buf, int buflen, int *outlen);

char *encrypt_decode01(int type, const char *buf, int buflen, int *outlen);

char *encrypt_decode2(int type, const char *buf, int buflen, int *outlen);

#define BUG_ON(conn) do{if((conn)) {fprintf(stderr, "%s %d\n", __FILE__, __LINE__); exit(-1);}}while(0)

#endif
