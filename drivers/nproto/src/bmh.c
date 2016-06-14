
#include "bmh.h"

/*
 * the memory $patt point to should valid when BMHChr called later.
 */
void BMHInit(struct BMH *bmh, const unsigned char* patt, int nlen)
{
	int k;

	bmh->patt = patt;
	bmh->m = nlen;

	for (k = 0; k < MAXCHAR; k++)
		bmh->d[k] = bmh->m;

	for (k = 0; k < bmh->m - 1; k++)
		bmh->d[bmh->patt[k]] = bmh->m - k - 1;
}

unsigned char * BMHChr(struct BMH *bmh, unsigned char* buf, int nlen)
{
	int i, j, k = bmh->m - 1;
	if (bmh->m > nlen)
		return (void*)0;

	while (k < nlen) {
		j = bmh->m - 1;
		i = k;
		while (j >= 0 && buf[i] == bmh->patt[j]) {
			j--;
			i--;
		}
		if (j == -1)
			return (buf + i + 1);
		k += bmh->d[buf[k]];
	}

	return (void*)0;
}