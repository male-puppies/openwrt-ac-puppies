#include "mwm.h"

#define printf printk
#define malloc(m) kmalloc (m, GFP_ATOMIC)

#define MAX_PAT_LEN (32000)

extern void qsort ( void *base,
	unsigned num,
	unsigned width,
	int (*comp)(const void *, const void *));

static char mwmInstName[128];
static struct kmem_cache * hmwm_cache=NULL;

int mwmSysInit(const char * szInstName)
{
	int len;

	len = strlen( szInstName);
	if(len <=0||len>=24)
	{
		np_error("mwm: tedious man, the szInstName too long!\n");
		goto __err;
	}
	strcpy(mwmInstName, szInstName);

	hmwm_cache = kmem_cache_create(mwmInstName, \
		sizeof(mwm_t), 0, SLAB_HWCACHE_ALIGN, NULL);
	if (hmwm_cache == NULL)
	{
		np_error("kmem cache create failed.\n");
		goto __err;
	}

	return 0;

__err:
	if(hmwm_cache !=NULL)
	{
		kmem_cache_destroy(hmwm_cache);
		hmwm_cache = NULL;
	}
	return -1;
}


int mwmSysClean(const char * szInstName)
{
	if(strcmp(szInstName, mwmInstName)!=0)
	{
		np_error("inst name not match: %s-%s\n", szInstName, mwmInstName);
		goto __err;
	}

	if(hmwm_cache!=NULL)
	{
		kmem_cache_destroy(hmwm_cache);
		hmwm_cache =NULL;
	}
	return 0;

__err:
	return -1;
}

static inline mwm_patt_t* mwmPatsAlloc(int m)
{
	mwm_patt_t* p ;
	p = kmalloc(sizeof(mwm_patt_t), GFP_KERNEL);
	if(p ==NULL)
	{
		np_error("malloc failed.\n");
		goto __err;
	}
	memset(p,0,sizeof(mwm_patt_t));

	/* Allocate and store the Pattern 'P' with NO CASE info*/
	p->psPat = (unsigned char*) kmalloc (m+1, GFP_KERNEL) ;
	if( !p->psPat )
	{
		np_error("malloc failed.\n");
		goto __err;
	}
	memset(p->psPat, 0, m+1);

	return p;

__err:
	if(p!=NULL)
	{
		if(p->psPat)
		{
			kfree(p->psPat);
		}
		kfree(p);
	}
	return NULL;

}


static inline void mwmPatsFree(mwm_patt_t *p)
{

	if(p ==NULL)
	{
		np_error("nil pointer.\n");
		return ;
	}

	if(p->psPat)
	{
		kfree(p->psPat);
		p->psPat = NULL;
	}

	if (p->psBmh)
	{
		kfree(p->psBmh);
		p->psBmh = NULL;
	}

	kfree(p);
}

/*
** mwmAlloc:: Allocate and Init Big hash Table Verions
** maxpats - max number of patterns to support
*/
mwm_t * mwmNew()
{
	mwm_t * p = kmem_cache_alloc(hmwm_cache, GFP_ATOMIC);
	if( !p )
	{
		np_error("kmem create failed!\n");
		return 0;
	}
	memset(p,0,sizeof(mwm_t));

	p->msSmallest = MAX_PAT_LEN;

	return p;
}

/*
** Release a mwm
*/
void mwmFree(mwm_t *pv )
{
	mwm_t * p = pv;
	mwm_patt_t * list=0;
	mwm_patt_t * next=0;

	if(!p)
	{
		np_error("mwm_t is null!\n");
		return;
	}

	if( p->msPatArray )
	{
		if ((p->msNumPatterns * sizeof(mwm_patt_t)) < KMALLOC_MAX_SIZE)
		{
			kfree(p->msPatArray );
		}
		else
		{
			vfree(p->msPatArray);
		}
	}
	if( p->msNumArray )
	{

		if ((sizeof(HASH_TYPE)* p->msNumPatterns) < KMALLOC_MAX_SIZE)
		{
			kfree(p->msNumArray);
		}
		else
		{
			vfree(p->msNumArray);
		}
	}
	if( p->msHash )
	{
		vfree(p->msHash);
	}
	if( p->msShift2 )
	{
		vfree(p->msShift2 );
	}

	if(p->msLengths) vfree(p->msLengths);

	p->msPatArray = NULL;
	p->msNumArray = NULL;
	p->msHash = NULL;
	p->msShift2 = NULL;
	p->msLengths = NULL;

	np_info("free all patterns in list.\n");
	list = p->plist;
	while(list !=NULL)
	{
		next =list->next;
		mwmPatsFree(list);
		list =next;
	}
	p->plist = NULL;
	kmem_cache_free(hmwm_cache, p);

	np_info("free rest finished.\n");
}

/*
**
** returns -1: max patterns exceeded
** -----------offset(start)++**++**++**+deep(end)---------------
** 0: already present, uniqueness compiled in
** 1: added
*/
int mwmAddPattern( mwm_t *pv, unsigned char *patt, int len, int offset, int deep, void* user_data, int unique)
{
	mwm_t *ps = pv;
	mwm_patt_t *plist=0;
	mwm_patt_t *p = NULL;

	if ( !patt || len < 2 )
	{
		np_error("error patter empty or length < 2.\n ");
		return -2; /* Empty Pat String Or Length < Word*/
	}

	if (!(ps->msNumPatterns < HASH_TABLE_SIZE-1))
	{
		np_error("error max pattern number %d %d limited!\n", ps->msNumPatterns, HASH_TABLE_SIZE);
		return -1;
	}

	p = (mwm_patt_t*)mwmPatsAlloc(len);
	if(!p )
	{
		np_error("error alloc mem for pattern!\n");
		return -1;
	}

	/* de-repeat's */
	if(unique)
	{
		for( plist=ps->plist; plist!=NULL; plist=plist->next )
		{
			if( plist->psLen == len )
			{
				if( memcmp(patt, plist->psPat, len) == 0 )
				{
					// np_debug("unique but repeat: %s\n", patt);
					mwmPatsFree(p);
					return 0; /*already added */
				}
			}
		}
	}

	if( ps->plist )
	{
		for( plist=ps->plist; plist->next!=NULL; plist=plist->next)
			;
		plist->next = p;
	} else {
		ps->plist = p;
	}

	memcpy(p->psPat, patt, len);

	p->psLen = len;
	p->psOffset = offset;
	p->psDepth = deep ? deep : 32767;
	p->ps_data = user_data;

	ps->msNumPatterns++;

	if(p->psLen < (unsigned)ps->msSmallest)
		ps->msSmallest= p->psLen;
	if(p->psLen > (unsigned)ps->msLargest )
		ps->msLargest = p->psLen;

	ps->msTotal += p->psLen;
	ps->msAvg = ps->msTotal / ps->msNumPatterns;

	np_debug("add pattern len:%d, pt:%p, userd:%lx, '%s' finished.\n", p->psLen, p, (long)p->ps_data, p->psPat);
	return 1;
}


/*
**
** returns -1: max patterns exceeded
** -----------offset(start)++**++**++**+deep(end)---------------
** 0: already present, uniqueness compiled in
** 1: added
*/
int mwmAddPatternEx( mwm_t *pv, unsigned char *patt, int len, int offset, int deep, void* user_data)
{
	return mwmAddPattern(pv, patt, len, offset, deep, user_data, 0);
}

int mwmAddPatternUnique( mwm_t *pv, unsigned char *patt, int len, int offset, int deep, void* user_data)
{
	return mwmAddPattern(pv, patt, len, offset, deep, user_data, 1);
}

/*
** Calc some pattern length stats
*/
static void mwmAnalyzePattens( mwm_t * ps )
{
	int i;

	if( ps->msLengths )
	{
		memset( ps->msLengths, 0, sizeof(int) * (ps->msLargest+1) );
		for(i=0;i<ps->msNumPatterns;i++)
		{
			ps->msLengths[ ps->msPatArray[i].psLen ]++;
		}
	}
}


/*
** HASH ROUTINE - used during pattern setup, but inline during searches
*/
static unsigned HASH16( unsigned char * T )
{
	return (unsigned short) (((*T)<<8) | *(T+1));
}

#if HASH_CHAR
/*
** CHAR prefix hash.
** Build the hash table, and pattern groups
*/
static void mwmPrepHashedPatternGroupsC(mwm_t * ps)
{
	unsigned sindex = 0, hindex, ningroup;
	int i;

	/*
	** Mem has Allocated and here Init 1 byte pattern hash table (256)
	** Init Hash table to default value
	*/
	for(i=0;i<(int)ps->msNumHashEntries;i++)
	{
		ps->msHash1[i] = HASH_EMPTY; /* 0xFF */
	}

	/*
	** Add the patterns to the hash table
	** msNumArray['x'] = count('x.*');
	*/
	for(i=0; i<ps->msNumPatterns; i++)
	{
		/* first char only. */
		hindex = ps->msPatArray[i].psPat[0];
		sindex = ps->msHash1[hindex] = i;
		ningroup = 1;

		/* sort-ed patts. */
		while((++i < ps->msNumPatterns) && \
			(hindex == ps->msPatArray[i].psPat[0]))
			ningroup++;

		ps->msNumArray[ sindex ] = ningroup;
		i--;
	}
}
#else
/*
** SHORT prefix hash.
** Build the hash table, and pattern groups
*/
static void mwmPrepHashedPatternGroupsW(mwm_t * ps)
{
	unsigned sindex = 0, hindex, ningroup;
	int i;

	/*
	** Mem has Allocated and here Init 2+ byte pattern hash table (256 * 256)
	** Init Hash table to default value
	*/
	for(i=0;i<(int)ps->msNumHashEntries;i++)
	{
		ps->msHash[i] = HASH_EMPTY; /* 0xFFFF */
	}

	/*
	** Add the patterns to the hash table
	** msNumArray['a','b'] = count('ab.*');
	*/
	for(i=0;i<ps->msNumPatterns;i++)
	{
		hindex = HASH16(ps->msPatArray[i].psPat); /* H<<8 | L */
		sindex = ps->msHash[ hindex ] = i;
		ningroup = 1;

		while( (++i < ps->msNumPatterns) && \
			(hindex==HASH16(ps->msPatArray[i].psPat)) )
			ningroup++;

		ps->msNumArray[ sindex ] = ningroup; /* num of patts ['a,b'] */
		i--;
	}
}
#endif

#if SHIFT_CHAR
/*
** CHAR shift table.
** Standard Bad Character Multi-Pattern Skip Table
*/
static void mwmPrepBadCharTable(mwm_t * ps)
{
	unsigned short i, k, m, cindex, shift;
	unsigned small_value=MAX_PAT_LEN, large_value=0;

	/* Determine largest and smallest pattern sizes */
	for(i=0; i<ps->msNumPatterns; i++)
	{
		if( ps->msPatArray[i].psLen < small_value )
			small_value = ps->msPatArray[i].psLen;
		if( ps->msPatArray[i].psLen > large_value )
			large_value = ps->msPatArray[i].psLen;
	}

	m = (unsigned short) small_value;

	if( m > 255 ) m = 255;

	ps->msShiftLen = m;

	/* Initialze the default shift table. Max shift of 256 characters */
	for(i=0;i<256;i++)
	{
		ps->msShift[i] = m;
	}

	/* Multi-Pattern BAD CHARACTER SHIFT */
	for(i=0; i<ps->msNumPatterns; i++)
	{
		for(k=0; k<m; k++)
		{
			shift = (unsigned short)(m - 1 - k);

			if( shift > 255 ) shift = 255;

			cindex = ps->msPatArray[ i ].psPat[ k ];

			if( shift < ps->msShift[ cindex ] )
				ps->msShift[ cindex ] = shift;
		}
	}
}
#else
/*
** SHORT shift table.
** Prep and Build a Bad Word Shift table
*/
static void mwmPrepBadWordTable(mwm_t * ps)
{
	int i;
	unsigned short k, m, cindex;
	unsigned small_value=MAX_PAT_LEN, large_value=0;
	unsigned shift;

	/* Determine largest and smallest pattern sizes */
	for(i=0; i<ps->msNumPatterns; i++)
	{
		if( ps->msPatArray[i].psLen < small_value )
			small_value = ps->msPatArray[i].psLen;
		if( ps->msPatArray[i].psLen > large_value )
			large_value = ps->msPatArray[i].psLen;
	}

	m = (unsigned short) small_value; /* Maximum Boyer-Moore Shift */

	/* Limit the maximum size of the smallest pattern to 255 bytes */
	if( m > 255 ) m = 255;

	ps->msShiftLen = m;

	/* Initialze the default shift table. */
	for(i=0; i<BW_SHIFT_TABLE_SIZE; i++)
	{
		ps->msShift2[i] = (unsigned)(m-1);
	}

	/* Multi-Pattern Bad Word Shift Table Values */
	for(i=0; i<ps->msNumPatterns; i++)
	{
		for(k=0; k<m-1; k++)
		{
			shift = (unsigned short)(m - 2 - k);

			if( shift > 255 ) shift = 255;

			cindex = (HASH16(&ps->msPatArray[i].psPat[k]));

			if( shift < ps->msShift2[ cindex ] )
				ps->msShift2[ cindex ] = shift;
		}
	}
}
#endif

/*
*
* Finds matches within a groups of patterns, these patterns all have at least 2 characters
* This version walks thru all of the patterns in the group and applies a reverse string comparison
* to minimize the impact of sequences of patterns that keep repeating intital character strings
* with minimal differences at the end of the strings.
*
*/
static int mwmGroupMatch2( mwm_t * ps,
						  int index,
						  unsigned char * Tx,
						  unsigned char * T,
						  int Tleft,
						  void * in, void * out,
						  int (*match)(void *,void* in, void * out) )
{
	int k, sp, ep, st, len, nfound=0;
	mwm_patt_t * patrn;
	mwm_patt_t * patrnEnd;

	/* Process the Hash Group Patterns against the current Text Suffix */
	patrn = &ps->msPatArray[index];
	patrnEnd = patrn + ps->msNumArray[index];

	/* Match Loop - Test each pattern in the group against the Text */
	for( ;patrn < patrnEnd; patrn++ )
	{
		unsigned char *p, *q;

		/* Test if this Pattern is to big for Text, not a possible match */
		if( (unsigned)Tleft < patrn->psLen )continue;

		/* Test the offset && deepth */
		len = patrn->psLen;
		sp = patrn->psOffset; //pat's start
		ep = patrn->psOffset + patrn->psDepth; //pat's max end
		st = T - Tx;
		if (!((st >= sp) && (st + len <= ep)))
			continue;

		/* Setup the reverse string compare */
		k = patrn->psLen - HASH_BYTES - 1;
		q = patrn->psPat + HASH_BYTES;
		p = T + HASH_BYTES;

		/* Compare strings backward, unrolling does not help in perf tests. */
		while( k >=0 && (q[k] == p[k])) k--;

		/* We have a content match - call the match routine for further processing */
		if( k < 0 )
		{
			int cbr = 0;
			nfound++;
			if(!in) in = T;
			if(!out) out = T + len;
			//printf("mwm: matched %lx %lx, pat: %d '%s'\n", patrn, patrn->ps_data, patrn->psLen, patrn->psPat);
			cbr = match( (void *)patrn->ps_data, in, out);
			if( cbr == 0 ) {
				/* callback miss match. */
				return 0;
			} else if(cbr > 0) {
				/* callback matched & go-on. */
				return nfound;
			} else {
				/* callback matched & exit search. */
				return -nfound;
			}
		}
	}

	/* not found or not matched */
	return 0;
}


#if HASH_CHAR
/*
** [CHAR] hash, [CHAR] shifts.
*/
static int mwmSearchExCC( mwm_t *ps,
						 unsigned char * Tx, int n,
						 void *in, void *out,
						 int(*match)( void * par, void *in, void *out ))
{
	int Tleft, index, nfound, tshift;
	unsigned char *T, *Tend, *B;
	unsigned char *pshift = ps->msShift;
	HASH_TYPE *phash = ps->msHash1;
	/*mwm_patt_t *patrn, *patrnEnd;*/

	nfound = 0;

	Tleft = n;
	Tend = Tx + n;

	/* Test if text is shorter than the shortest pattern */
	if( (unsigned)n < ps->msShiftLen )
		return 0;

	/* Process each suffix of the Text, left to right, incrementing T so T = S[j] */
	for( T = Tx, B = Tx + ps->msShiftLen - 1; B < Tend; T++, B++, Tleft-- )
	{
		/* Multi-Pattern Bad Character Shift */
		while( (tshift = pshift[*B]) > 0 )
		{
			B += tshift; T += tshift; Tleft -= tshift;
			if( B >= Tend ) return nfound;

			tshift = pshift[*B];
			B += tshift; T += tshift; Tleft -= tshift;
			if( B >= Tend ) return nfound;
		}


		/* Test for last char in Text, one byte pattern test was done above, were done. */
		if( Tleft <= 1 )
			return nfound;

		/* Test if the 1 char prefix of this suffix shows up in the hash table */
		if( (index = phash[(*T)] ) == HASH_EMPTY)
			continue;

		/* Match this group against the current suffix */
		nfound = mwmGroupMatch2( ps, index, Tx, T, Tleft, in, out, match );
		if (nfound < 0) {
			/* found & exit. */
			return -nfound;
		}
	}

	return nfound;
}
#endif

#if SHIFT_CHAR
/*
** [CHAR] hash, [SHORT] shifts.
*/
static int mwmSearchExBC( mwm_t *ps,
						 unsigned char * Tx, int n,
						 void *in, void *out,
						 int(*match)( void * par, void *in, void *out ))
{
	int Tleft, index, nfound, tshift;
	unsigned char *T, *Tend, *B;
	unsigned char *pshift = ps->msShift;
	HASH_TYPE *phash = ps->msHash;
	/*mwm_patt_t *patrn, *patrnEnd;*/

	nfound = 0;

	Tleft = n;
	Tend = Tx + n;

	/* Test if text is shorter than the shortest pattern */
	if( (unsigned)n < ps->msShiftLen )
		return 0;

	/* Process each suffix of the Text, left to right, incrementing T so T = S[j] */
	for( T = Tx, B = Tx + ps->msShiftLen - 1; B < Tend; T++, B++, Tleft-- )
	{
		/* Multi-Pattern Bad Character Shift */
		while( (tshift = pshift[*B]) > 0 )
		{
			B += tshift; T += tshift; Tleft -= tshift;
			if( B >= Tend ) return nfound;

			tshift = pshift[*B];
			B += tshift; T += tshift; Tleft -= tshift;
			if( B >= Tend ) return nfound;
		}


		/* Test for last char in Text, one byte pattern test was done above, were done. */
		if( Tleft == 1 )
			return nfound;

		/* Test if the 2 char prefix of this suffix shows up in the hash table */
		if( (index = phash[HASH16(T)]) == HASH_EMPTY)
			continue;

		/* Match this group against the current suffix */
		nfound = mwmGroupMatch2( ps, index,Tx, T, Tleft, in, out, match );
		if( nfound < 0 ) {
			/* found & exit */
			return -nfound;
		}
	}

	return nfound;
}
#else
/*
** [SHORT] hash, [SHORT] shifts.
*/
static int mwmSearchExBW( mwm_t *ps,
						 unsigned char * Tx, int n,
						 void * in, void * out,
						 int(*match)( void * par, void * in, void * out ))
{
	int Tleft, index, nfound, tshift;
	unsigned char *T, *Tend, *B;
	unsigned char *pshift2 = ps->msShift2;
	HASH_TYPE *phash = ps->msHash;

	nfound = 0;

	Tleft = n;
	Tend = Tx + n;

	/* Test if text is shorter than the shortest pattern */
	if( (unsigned)n < ps->msShiftLen )
		return 0;

	/* Process each suffix of the Text, left to right, incrementing T so T = S[j] */
	for( T = Tx, B = Tx + ps->msShiftLen - 1; B < Tend; T++, B++, Tleft-- )
	{
		/* Multi-Pattern Bad Word Shift */
		tshift = pshift2[HASH16(B-1)];
		while( tshift )
		{
			B += tshift; T += tshift; Tleft -= tshift;
			if( B >= Tend )
				return nfound;
			tshift = pshift2[HASH16(B-1)];
		}

		/* Test for last char in Text, we are done, one byte pattern test was done above. */
		if( Tleft == 1 )
			return nfound;

		/* Test if the 2 char prefix of this suffix shows up in the hash table */
		if( (index = phash[HASH16(T)] ) == HASH_EMPTY ){
			continue;
		}

		/* Match this group against the current suffix */
		nfound = mwmGroupMatch2( ps, index, Tx, T, Tleft, in, out, match );
		if( nfound < 0 ) {
			/* found & exit */
			return -nfound;
		}
	}

	return nfound;
}
#endif

/*
* Boyer-Moore Horspool
* Does NOT use Sentinel Byte(s)
* Scan and Match Loops are unrolled and separated
* Optimized for 1 byte patterns as well
*/
static inline unsigned char * bmhSearch(hbm_t * px, unsigned char * text, int n)
{
	unsigned char *pat, *t, *et, *q;
	int m1, k;
	short *bcShift;

	if (!px)
		return 0;

	m1 = px->M-1;
	pat = px->P;
	bcShift= px->bcShift;

	t = text + m1;
	et = text + n;

	/* Handle 1 Byte patterns - it's a faster loop */
	if( !m1 )
	{
		for( ;t<et; t++ )
			if( *t == *pat ) return t;
		return 0;
	}

	/* Handle MultiByte Patterns */
	while( t < et )
	{
		/* Scan Loop - Bad Character Shift */
		do
		{
			t += bcShift[*t];
			if( t >= et )return 0;

			t += (k=bcShift[*t]);
			if( t >= et )return 0;

		} while( k );

		/* Unrolled Match Loop */
		k = m1;
		q = t - m1;
		while( k >= 4 )
		{
			if( pat[k] != q[k] )goto NoMatch; k--;
			if( pat[k] != q[k] )goto NoMatch; k--;
			if( pat[k] != q[k] )goto NoMatch; k--;
			if( pat[k] != q[k] )goto NoMatch; k--;
		}
		/* Finish Match Loop */
		while( k >= 0 )
		{
			if( pat[k] != q[k] )goto NoMatch; k--;
		}
		/* If matched - return 1st char of pattern in text */
		return q;

NoMatch:

		/* Shift by 1, this replaces the good suffix shift */
		t++;
	}

	return 0;
}


/*
** Search a body of text or data for paterns
*/
int mwmSearch(mwm_t *pv,
			  unsigned char * T, int n,
			  void *in, void *out,
			  int(*match)(void *par, void *in, void *out))
{
	int i,nfound=0;
	int pats, pate, plen;
	mwm_t * ps = pv;

	if (ps->msNumPatterns<1)
		return 0;//no found

	/* Boyer-Moore */
	if( ps->msMethod == MTH_BM )
	{
		unsigned char * Tx;

		for( i=0; i<ps->msNumPatterns; i++ )
		{
			mwm_patt_t *patt = &ps->msPatArray[i];
			Tx = bmhSearch( patt->psBmh, T, n );
			if( Tx )
			{
				int s;
				plen = patt->psLen;
				pats = patt->psOffset;
				pate = patt->psOffset + patt->psDepth;
				s = Tx - T;
				if(!( s >= pats && s + plen < pate ))
					continue;

				nfound++;
				if(match((void *)patt->ps_data, in, out))
					return nfound;
			}
		}
		return nfound;
	}
	else
		return ps->search( ps, T, n, in, out, match);

}

/*
** bcompare::
**
** Perform a Binary comparsion of 2 byte sequences of possibly
** differing lengths.
**
** returns -1 a < b
** +1 a > b
** 0 a = b
*/
static int bcompare( unsigned char *a, int alen, unsigned char * b, int blen )
{
	int stat;
	if( alen == blen )
	{
		return memcmp(a,b,alen);
	}
	else if( alen < blen )
	{
		if( (stat=memcmp(a,b,alen)) != 0 )
			return stat;
		return -1;
	}
	else
	{
		if( (stat=memcmp(a,b,blen)) != 0 )
			return stat;
		return +1;
	}
}


/*
** sortcmp:: qsort callback
*/
static int sortcmp( const void * e1, const void * e2 )
{
	mwm_patt_t *r1= (mwm_patt_t*)e1;
	mwm_patt_t *r2= (mwm_patt_t*)e2;
	return bcompare( r1->psPat, r1->psLen, r2->psPat, r2->psLen );
}

/*
return : 0 suc <0 error
*/

int mwmPrepMem(void * pv)
{
	mwm_t * ps = (mwm_t *) pv;

	/* Build an array of pointers to the list of Pattern nodes */
	if ((ps->msNumPatterns * sizeof(mwm_patt_t)) < KMALLOC_MAX_SIZE)
	{
		ps->msPatArray = (mwm_patt_t*)kmalloc( sizeof(mwm_patt_t)*ps->msNumPatterns, GFP_KERNEL);
	}
	else
	{
		ps->msPatArray = (mwm_patt_t*)vmalloc( sizeof(mwm_patt_t)*ps->msNumPatterns);
	}

	if( !ps->msPatArray )
	{
		np_error("kmalloc %d pattern nodes failed!\n", ps->msNumPatterns);
		goto __err;
	}
	memset(ps->msPatArray, 0, sizeof(mwm_patt_t) * ps->msNumPatterns);

	if ((sizeof(HASH_TYPE)* ps->msNumPatterns) < KMALLOC_MAX_SIZE)
	{
		ps->msNumArray = (HASH_TYPE *)kmalloc(sizeof(HASH_TYPE)* ps->msNumPatterns, GFP_KERNEL);
	}
	else
	{
		ps->msNumArray = (HASH_TYPE *)vmalloc(sizeof(HASH_TYPE)* ps->msNumPatterns);
	}
	if( !ps->msNumArray )
	{
		np_error("vmalloc %d pattern nodes failed\n", ps->msNumPatterns);
		goto __err;

	}
	memset(ps->msNumArray, 0, sizeof(HASH_TYPE) * ps->msNumPatterns);

	if (ps->msMethod == MTH_MWM)
	{
		ps->msNumHashEntries = HASH_TABLE_SIZE;

#if HASH_WORD
		ps->msHash = (HASH_TYPE*)vmalloc( sizeof(HASH_TYPE) * ps->msNumHashEntries);
		if( !ps->msHash )
		{
			np_error("kmalloc for hash failed! may be not enough memory\n");
			goto __err;
		}
		memset(ps->msHash, 0, sizeof(HASH_TYPE) * ps->msNumHashEntries );
#endif

		ps->msLengths = (int*)vmalloc( sizeof(int) * (ps->msLargest+1) );
		if(!ps->msLengths)
		{
			np_error("vmalloc for len-i %d info failed.\n", ps->msLargest);
			goto __err;
		}
		memset(ps->msLengths, 0, sizeof(int) * (ps->msLargest+1) );

#if SHIFT_WORD
		ps->msShift2 = (unsigned char *)vmalloc(BW_SHIFT_TABLE_SIZE*sizeof(char));
		if(!(ps->msShift2))
		{
			np_error("kmalloc for Shift2 failed! may be not enough memory.\n");
			goto __err;
		}
		memset(ps->msShift2, 0, BW_SHIFT_TABLE_SIZE*sizeof(char));
#endif

	}
	return 0;

__err:

	if( ps->msPatArray )
	{
		if ((ps->msNumPatterns * sizeof(mwm_patt_t)) < KMALLOC_MAX_SIZE)
		{
			kfree(ps->msPatArray );
		}
		else
		{
			vfree(ps->msPatArray);
		}
	}
	if( ps->msNumArray )
	{

		if ((sizeof(HASH_TYPE)* ps->msNumPatterns) < KMALLOC_MAX_SIZE)
		{
			kfree(ps->msNumArray);
		}
		else
		{
			vfree(ps->msNumArray);
		}
	}
	if( ps->msHash )
	{
		vfree(ps->msHash);
	}
	if( ps->msShift2 )
	{
		vfree(ps->msShift2 );
	}
	if(ps->msLengths) vfree(ps->msLengths);

	ps->msPatArray = NULL;
	ps->msNumArray = NULL;
	ps->msHash = NULL;
	ps->msShift2 = NULL;
	ps->msLengths = NULL;

	return -1;
}

hbm_t * bmhPrepBmh(hbm_t *p, unsigned char * pat, int m)
{
	int k;

	if( !m )
	{
		return 0;
	}
	p->P = pat;
	p->M = m;

	/* Compute normal Boyer-Moore Bad Character Shift */
	for(k = 0; k < 256; k++) p->bcShift[k] = m;
	for(k = 0; k < m; k++) p->bcShift[pat[k]] = m - k - 1;

	return p;
}

/*
* BMH for less patts.
*/
hbm_t *bmhPrepEx(unsigned char * pat, int m)
{
	hbm_t *p;

	p = (hbm_t*)kmalloc( sizeof(hbm_t), GFP_KERNEL);
	if( !p )
	{
		np_error("bmh malloc failed!\n");
		return 0;
	}

	return bmhPrepBmh( p, pat, m );
}


/*
**
** mwmPrepPatterns:: Prepare the pattern group for searching
**
*/
int mwmPrepPatterns( mwm_t * pv )
{

	int k;
	mwm_t * ps = pv;
	mwm_patt_t * plist;

	if (!pv)
	{
		np_error("mwm: MWM STRUCT is null !\n");
		return 1;
	}

	if (ps->msNumPatterns <= 0)
	{
		np_warn("mwm: Number of patterns is zero!\n ");
		return 0;
	}

	ps->msMethod = ps->msNumPatterns < 5 ? MTH_BM : MTH_MWM;
	if(mwmPrepMem( ps )<0)
	{
		np_error("mwm: mwmPrep_Mem failed\n");
		goto __err;
	}

	/* Calc Pats's Length info */
	mwmAnalyzePattens( ps );

	/* Copy the list node info into the Array */
	for( k=0, plist = ps->plist; plist!=NULL && k < ps->msNumPatterns; plist=plist->next )
	{
		memcpy( &ps->msPatArray[k++], plist, sizeof(mwm_patt_t) );
	}

	/* Initialize the MWM or Boyer-Moore Pattern data */
	if( ps->msMethod == MTH_MWM )
	{
		/* Sort the patterns */
		qsort( ps->msPatArray, ps->msNumPatterns, sizeof(mwm_patt_t), sortcmp);

		/* Build the Hash table, and pattern groups, per Wu & Manber */
#if HASH_CHAR
		mwmPrepHashedPatternGroupsC(ps);
#else
		mwmPrepHashedPatternGroupsW(ps);
#endif

		/* Bad Word Shift Tables */
#if SHIFT_CHAR
		mwmPrepBadCharTable(ps);
#else
		mwmPrepBadWordTable(ps);
#endif

		/* setup the exactily search function */
#if HASH_CHAR
		ps->search = mwmSearchExCC;
#else

	#if SHIFT_CHAR
		ps->search = mwmSearchExBC;
	#else
		ps->search = mwmSearchExBW;
	#endif

#endif
	}
	else if( ps->msMethod == MTH_BM )
	{
		/* Allocate and initialize the BMH data for each pattern */
		for(k=0; k<ps->msNumPatterns;k++)
		{
			ps->msPatArray[k].psBmh = bmhPrepEx( ps->msPatArray[ k ].psPat, ps->msPatArray[k].psLen );
		}
	}
	smp_wmb();

	np_info("finished: %d patts.\n", ps->msNumPatterns);
	return 1;

__err:
	return -1;
}

/*
** mwmGetNpatterns::
*/
int mwmGetNumPatterns( void * pv )
{
	mwm_t *p = (mwm_t*)pv;
	return p->msNumPatterns;
}

/*
** Print some Pattern Stats
*/
void mwmShowStats( void * pv )
{
	mwm_t * ps = (mwm_t*)pv;

	int i;
	printf("Pattern Stats\n");
	printf("-------------\n");
	printf("Patterns : %d\n" , ps->msNumPatterns);
	printf("Average : %d chars\n", ps->msAvg);
	printf("Smallest : %d chars\n", ps->msSmallest);
	printf("Largest : %d chars\n", ps->msLargest);
	printf("Total chars: %d\n" , ps->msTotal);

	for(i=0;i<ps->msLargest+1;i++)
	{
		if( ps->msLengths[i] )
			printf("Len[%d] : %d patterns\n", i, ps->msLengths[i] );
	}
	printf("\n");
}


/* Display function for testing */
static void ShowBytes(unsigned n, unsigned char *p)
{
	int i;
	for(i=0;i<(int)n;i++)
	{
		if( p[i] >=32 && p[i]<=127 )
		{
			np_print("%c",p[i]);
		}
		else
			np_print("\\x%2.2X",p[i]);
	}

}

/*
** Display patterns in this group
*/
void mwmGroupDetails(mwm_t *pv)
{
	mwm_t * ps = pv;
	int index,i, m, gmax=0, total=0,gavg=0,subgroups;
	static int k=0;
	mwm_patt_t *patrn, *patrnEnd;
	if (!ps)
	{
		printf("mwm: null mwm struct for group info.\n");
		return;
	}
	if (ps->msMethod == MTH_BM)
	{
		np_print("mwm: bmh used.\n");
		return;
	}

	np_print("*** MWM-Pattern-STURCT: %d ***\n", k++);

	subgroups=0;
	for(i=0; i<HASH_TABLE_SIZE; i++)
	{
#if HASH_CHAR
		if((index = ps->msHash1[i]) == HASH_EMPTY)
			continue;
#else
		if((index = ps->msHash[i]) == HASH_EMPTY)
			continue;
#endif

		patrn = &ps->msPatArray[index]; /* 1st pattern of hash group is here */
		patrnEnd = patrn + ps->msNumArray[index];/* never go here... */

		np_print("  mwm: Sub-Pattern-Group: %d-%d:%d, patn:%d\n",\
			subgroups, i, index, ps->msNumArray[index]);

		subgroups++;

		for( m=0; patrn < patrnEnd; m++, patrn++ ) /* Test all patterns in the group */
		{
			np_print("\tmwm: Pattern[%d]: <",m);
			ShowBytes(patrn->psLen,patrn->psPat);
			np_print(">\n");
		}

		if(m > gmax )
			gmax = m;
		total+=m;
		gavg = total / subgroups;
	}

	np_print("Total Group Patterns: %d\n",total);
	np_print(" Number of Sub-Groups: %d\n",subgroups);
	np_print(" Sub-Group Max Patterns: %d\n",gmax);
	np_print(" Sub-Group Avg Patterns: %d\n",gavg);

}

/*
**
*/
void mwmFeatures(void)
{
	printf("[%s]: %s\n", mwmInstName, MWM_FEATURES);
}


