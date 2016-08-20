#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <arpa/inet.h>

#include "libencrypt.h"

unsigned int seed1 = 0XBCEF3A7E;
unsigned int seed2 = 0X9CABBEBB;

static void xor(char *buff, int len, unsigned int se) {
	unsigned char *pos = (unsigned char *)buff, *end = (unsigned char *)buff + len;
	for (; end > pos && end - pos >= 4; pos += 4) {
		*(unsigned int *)pos ^= se;
	}
}

char *encrypt_encode01(int type, const char *s, int slen, int *outlen) {
	int total;
	char *n, *p;
	encrypt_header_t *h;

	total = sizeof(encrypt_header_t) + slen;
	n = (char *)malloc(total);						BUG_ON(!n);
	h = (encrypt_header_t *)n;
	p = n + sizeof(encrypt_header_t);

	memcpy(p, s, slen);
	encrypt_set_header(h, type, total);
	*outlen = total;

	*(unsigned int *)h = htonl(*(unsigned int *)h);

	switch(type) {
	case 0:
		return n;
	case 1:
		xor(p, slen, seed1);
		return n;
	default:
		BUG_ON(1);
	}
	return NULL;
}

char *encrypt_encode2(int type, const char *buf, int buflen, int *outlen) {
	BUG_ON(type != 2);

	char *ns, *p;
	encrypt_header_t *h;
	int max, total, ret, *orig, datalen;

	max = LZ4_compressBound(buflen) + sizeof(int);			BUG_ON(max > 10*1024*1024);
	total = max + sizeof(encrypt_header_t);

	ns = (char *)malloc(total);								BUG_ON(!ns);
	h = (encrypt_header_t *)ns;
	p = ns + sizeof(encrypt_header_t);

	orig = (int *)p;
	p += sizeof(int);

	ret = LZ4_compress_default(buf, p, buflen, max); 		BUG_ON(ret <= 0 || ret >= max);
	datalen = ret + sizeof(encrypt_header_t) + sizeof(int);
	encrypt_set_header(h, type, datalen);

	*outlen = datalen;
	*orig = htonl(buflen);
	*h = htonl(*h);

	return ns;
}

char *encrypt_decode2(int type, const char *buf, int buflen, int *outlen) {
	if (buflen <= sizeof(encrypt_header_t) + sizeof(int)) {
		return NULL;
	}

	BUG_ON(type != 2);

	char *n;
	const char *p;
	encrypt_header_t h;
	int orig, ret, datalen, htype, hlen, nsize;

	h = ntohl(*(encrypt_header_t *)buf);
	p = buf + sizeof(encrypt_header_t);

	orig = ntohl(*(unsigned int *)p);
	p += sizeof(int);

	encrypt_get_header(&h, &htype, &hlen);

	if (hlen != buflen) {
		fprintf(stderr, "%s %d invalid len %d %d\n", __FILE__, __LINE__, buflen, hlen);
		return NULL;
	}

	if (orig >= 10 * 1024*1024) {
		fprintf(stderr, "%s %d invalid len %d\n", __FILE__, __LINE__, orig);
		return NULL;
	}

	nsize = orig + 2;
	n = (char *)malloc(nsize);					BUG_ON(!n);
	datalen = buflen - sizeof(int) - sizeof(encrypt_header_t);
	ret = LZ4_decompress_safe(p, n, datalen, nsize);	BUG_ON(ret > orig);
	if (ret != orig) {
		fprintf(stderr, "%s %d LZ4_decompress_safe fail %d %d\n", __FILE__, __LINE__, ret, orig);
		free(n);
		return NULL;
	}

	*outlen = orig;
	return n;
}

char *encrypt_decode01(int type, const char *buf, int buflen, int *outlen) {
	char *n;
	int total, htype, hlen;
	const char*p;
	encrypt_header_t h;

	h = *(encrypt_header_t *)buf;
	h = ntohl(h);
	encrypt_get_header(&h, &htype, &hlen); 		BUG_ON(type != htype || buflen != hlen);

	p = buf + sizeof(encrypt_header_t);
	total = buflen - sizeof(encrypt_header_t);	BUG_ON(total <= 0 || total > 10*1024*1024);
	n = (char *)malloc(total);					BUG_ON(!n);
	memcpy(n, p, total);

	*outlen = total;
	switch(type) {
	case 0:
		return n;
	case 1:
		xor(n, total, seed1);
		return n;
	default:
		BUG_ON(1);
	}
	return NULL;
}

int encrypt_init() {
	BUG_ON(sizeof(encrypt_header_t) != 4);
	return 0;
}

void encrypt_get_header(encrypt_header_t *h, int *type, int *len) {
	*type = ((*h) & 0x0f);
	*len = ((*h) >> 4);
}

void encrypt_set_header(encrypt_header_t *h, int type, int len) {
	unsigned int nh = ((len << 4) | type);
	memcpy(h, &nh, sizeof(nh));
}

