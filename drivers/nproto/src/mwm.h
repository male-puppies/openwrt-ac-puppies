/*
** $Id: mwm.h,v 1.1 2003/10/20 15:03:42 chrisgreen Exp $
**
**  mwm.h
**
** Copyright (C) 2002 Sourcefire,Inc
** Marc Norton
**
** Modifed Wu-Manber style Multi-Pattern Matcher
**
** This program is free software; you can redistribute it and/or modify
** it under the terms of the GNU General Public License as published by
** the Free Software Foundation; either version 2 of the License, or
** (at your option) any later version.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
**
** You should have received a copy of the GNU General Public License
** along with this program; if not, write to the Free Software
** Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
**
**
*/

#ifndef __MWM_H__
#define __MWM_H__

#include <linux/stddef.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/timer.h>
#include <linux/module.h>
#include <linux/errno.h>
#include <linux/limits.h>
#include <linux/string.h>
#include <linux/spinlock.h>
#include <linux/sched.h>
#include <linux/slab.h>
#include <linux/vmalloc.h>

#include <ntrack_log.h>

//#define MWM_DEBUG
/*
*   This macro enables use of the bitop test.
*/

//#define COPY_PATTERNS

/*
** Enables display of pattern group stats
*/
//#define SHOW_STATS
#define dump_fucker(x) do{*(long*)(__LINE__)=(x);}while(0)

#define MWM_FEATURES "MWM:BC/BW-SHIFT + 2-BYTE-HASH"  

#define HASH_CHAR 0
#define SHIFT_CHAR 0

#if HASH_CHAR
#define HASH_WORD 0
#define HASH_BYTES    1
#define HASH_TYPE unsigned char
#define HASH_EMPTY (0xff)
#define HASH_TABLE_SIZE (256)
#else
#define HASH_WORD 1
#define HASH_BYTES    2
#define HASH_TYPE unsigned short 
#define HASH_EMPTY (0xffff)
#define HASH_TABLE_SIZE (256 * 256)
#endif

/* shift table size */
#if SHIFT_CHAR
#define SHIFT_WORD 0
#else
#define SHIFT_WORD 1
#endif


/* 
** Causes mbmAddPattern to check for and not allow duplicate patterns. 
** By default we allow multiple duplicate patterns, since the AND clause
** may case the whole signature to be different. We trigger each pattern
** to be processesed by default.
*/

#define REQUIRE_UNIQUE_PATTERNS 0

/*
*  Pattern Matching Methods - Boyer-Moore-Horspool or Modified Wu Manber
*/
enum {
  MTH_MWM = 0,
  MTH_BM,
};

#define BW_SHIFT_TABLE_SIZE (64*1024)

/*
*
*  Boyer-Moore-Horsepool for small pattern groups
*    
*/
typedef struct {
	short  bcShift[256];
	int M;
	unsigned char *P;
} hbm_t;

/*
**  This struct is used internally my mwm.c
*/
typedef struct __mwm_patt {

	unsigned int    psLen;   // length of pattern in bytes
	unsigned char   *psPat;   // pattern array, no case
	int    psOffset;  // pos where to start searching in data
	int    psDepth;   // number of bytes after offset to search
	long  ps_data;    //internal ID, used by the pattern matcher
	
	hbm_t     * psBmh;	
	struct __mwm_patt * next;
} mwm_patt_t;

/*
** Pattern GROUP Structure, this struct is is used publicly, but by reference only
*/
typedef struct __mwm_st {
  
  /* Bad Character Shift Table */
  HASH_TYPE msHash1[256];
  unsigned char msShift[256];
  unsigned msShiftLen;
  
  /* search function */
  int (*search)( struct __mwm_st * ps, 
                 unsigned char * T, int n, 
                 void  * in, void *out ,
                 int(*match)( void *  par, void * in, void * out ) );
  
  /* Array of Group Counts, # of patterns in each hash group */
  mwm_patt_t   *msPatArray;
  HASH_TYPE   *msNumArray;
  
  /* Number of Patterns loaded */
  int     msNumPatterns;

  /* Wu-Manber Hash Tables */
  int   msNumHashEntries;
  HASH_TYPE *msHash;           // 2+ character Pattern Big Hash Table  
  
  /* Bad Word Shift Table */
  unsigned char* msShift2; 
  int msLargeShifts;
  
  /* Print Group Details */
  int msDetails;
  
  /* Pattern Group Stats  */
  int   msSmallest;
  int   msLargest;
  int   msAvg;
  int   msTotal;
  int *msLengths;
  
  int    msMethod;  /* MTH_BM, MTH_MWM */
  int    is_ok;
  
  mwm_patt_t * plist;
  
} mwm_t;

/*
return value 
0: suc
-1:error
note:call exact once every driver
*/
int mwm_sysinit(const char * szInstName);

/*
if  mwm_sysinit suc, you must to call mwm_sysclean exact once when you 
unload your driver
ret:
0  suc
-1 error
*/
int  mwm_sysclean(const char * szInstName);

/*
** PROTOTYPES
*/
mwm_t * mwmNew( void );
void   mwmFree(mwm_t *pv );
#define MWM_INITED(pv) ((pv)->is_ok==1)

int mwmAddPatternEx( mwm_t *pv, unsigned char * P, int len, int off, int deep,  long ud );
int  mwmPrepPatterns  ( mwm_t *pv );

int  mwmSearch( mwm_t *pv,
			   unsigned char * T, int n, 
			   void *in, void *out,
			   int ( *action )(void *par, void * in, void *out)); 

/* Not so useful, but not ready to be dumped  */
int   mwmGetNumPatterns( void * pv );
void  mwmFeatures( void );
void  mwmShowStats( void * pv );
void  mwmGroupDetails( mwm_t *pv );

#endif

