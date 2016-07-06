#pragma once

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/types.h>
#include <linux/string.h>
#include <linux/ctype.h>
#include <linux/stddef.h>

#include "pcre2/pcre2.h"

typedef struct regex_pcre {
	u8 *pattern;
	unsigned int patlen;
	PCRE2_UCHAR *pcre;
	PCRE2_UCHAR *op_str;
	pcre2_code *re;
	pcre2_match_data *match_data;
	pcre2_match_context *mcontext;
	pcre2_jit_stack *jit_stack;
	int opts;
} pcre_t;

int pcre_init(void);
void pcre_cleanup(void);
pcre_t *pcre_create(const void *pattern, unsigned int len);
void pcre_destroy(pcre_t *pcre);
int pcre_find(pcre_t *pcre, const u8 *text, unsigned int text_len);