#pragma once

#define MAXCHAR 256

typedef struct BMH {
	int m;
	const unsigned char* patt;
	int d[MAXCHAR];
} bmh_t;

void BMHInit(struct BMH *bmh, const unsigned char* patt, int nlen);
unsigned char * BMHChr(struct BMH *bmh, unsigned char* buf, int nlen);

