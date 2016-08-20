/*
 * wumanber_impl.h -- data structures and API for wumanber_impl.c
 *
 * Copyright (C) 2010, Juergen Weigert, Novell inc.
 * Distribute,modify under GPLv2 or GPLv3, or perl license.
 */

#define N_SYMB     256		// characters per byte
#define SHIFT_SZ   4096		// sizeof shift_min
#define PAT_HASH_SZ 8192	// =(1<<13), must be a power of two

struct pat_list
{
	int index;
	struct pat_list *next;
};

typedef struct WuManber
{
	unsigned int n_pat;		// number of patterns;
	unsigned char **patt;		// list of patterns;
	unsigned int *pat_len;	// length array of patterns;

	unsigned char tr[N_SYMB];
	unsigned char tr1[N_SYMB];

	int use_bs3;
	int use_bs1;
	int p_size;
	unsigned char shift_min[SHIFT_SZ];
	struct pat_list *pat_hash[PAT_HASH_SZ];

	int n_matches;

	int nocase;
	int one_match_per_line;	// report all patterns that match in a line. (unlike agrep)
	int one_match_per_offset;	// report all patterns that would match at an offset. (unlike agrep)

	void (*cb)(unsigned int idx, unsigned long off, void *data);
	void *cb_data;
	char  *progname;
} wu_manber_t;

void wm_add_pats(struct WuManber *wm, int n_pat, unsigned char **pat_p, int nocase);
void wm_init(struct WuManber *wm, char *name);
unsigned int wm_search(struct WuManber *wm, unsigned char *text, int end);
