#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/types.h>
#include <linux/string.h>
#include <linux/ctype.h>
#include <linux/stddef.h>
#include <linux/slab.h>

#include "pcre2/libc.h"
#include "pcre2/pcre2.h"
#include "pcre.h"

#include "nproto_log.h"

/* valid the regex patt format. */
#define PARSE_REGEX         "(?<!\\\\)/(.*(?<!(?<!\\\\)\\\\))/([^\"]*)"

static pcre2_code *parse_regex = NULL;
static bool sysctl_jit_enable = true;
static int sysctl_jit_stack_start = 16; /* KB */
static int sysctl_jit_stack_max = 64; /* KB */

int pcre_find(pcre_t *pcre, const u8 *text, unsigned int text_len)
{
	PCRE2_SIZE *ovector;
	int rc;

	rc = pcre2_match(pcre->re, text, text_len, 0, 0,
			 pcre->match_data, pcre->mcontext);
	if (unlikely(rc >= 0)) {
		ovector = pcre2_get_ovector_pointer(pcre->match_data);
		if(ovector) {
			return ovector[0];
		}
	}
	return rc;
}
EXPORT_SYMBOL(pcre_find);

static inline int pattern_parse(const char *pattern, PCRE2_UCHAR ** pcre, PCRE2_UCHAR ** op_str)
{
	PCRE2_SIZE relen, oplen;
	pcre2_match_data *match_data;
	int res, rc;

	match_data = pcre2_match_data_create(4, NULL);
	if (IS_ERR_OR_NULL(match_data)) {
		return -ENOMEM;
	}

	res = pcre2_match(parse_regex, pattern, -1, 0, 0, match_data, NULL);
	if (res <= 0) {
		np_error("invalid pattern[%s] ec: %d\n", pattern, res);
		pcre2_match_data_free(match_data);
		return -EINVAL;
	}

	relen = 0;
	oplen = 0;

	rc = pcre2_substring_get_bynumber(match_data, 1, pcre, &relen);
	if (rc < 0) {
		np_error("/regexp/ign extra exp failed[%s]\n", pattern);
		return -EINVAL;
	}

	if (res > 2) {
		rc = pcre2_substring_get_bynumber(match_data, 2, op_str, &oplen);
		if (rc < 0) {
			np_error("/regexp/ign extra opts failed[%s]\n", pattern);
			return -EINVAL;
		}
	}

	if (relen > 0) {
		np_debug("\tpcre: %lu|%s|\n", (unsigned long)relen, *pcre);
	}

	if (oplen > 0) {
		np_debug("\topts: %lu|%s|\n", (unsigned long)oplen, *op_str);
	}

	pcre2_match_data_free(match_data);
	return 0;
}

static inline void opts_parse(char *op_str, int *_opts)
{
	char *op = NULL;
	int opts = 0;

	op = op_str;
	*_opts = 0;

	if (op != NULL) {
		while (*op) {
			switch (*op) {
			case 'A':
				opts |= PCRE2_ANCHORED;
				break;
			case 'E':
				opts |= PCRE2_DOLLAR_ENDONLY;
				break;
			case 'G':
				opts |= PCRE2_UNGREEDY;
				break;

			case 'i':
				opts |= PCRE2_CASELESS;
				break;
			case 'm':
				opts |= PCRE2_MULTILINE;
				break;
			case 's':
				opts |= PCRE2_DOTALL;
				break;
			case 'x':
				opts |= PCRE2_EXTENDED;
				break;

			default:
				np_error("unknown regex modifier '%c'\n", *op);
				break;
			}
			op++;
		}
	}

	*_opts = opts;
}

pcre_t *pcre_create(const void *pattern, unsigned int len)
{
	pcre_t *pcre;
	PCRE2_SIZE erroffset;
	int ec, rc;
	// size_t priv_size = sizeof(pcre_t);
	// int save = offsetof(pcre_t, patlen);

	pcre = kmalloc(sizeof(pcre_t), GFP_KERNEL);
	if(ZERO_OR_NULL_PTR(pcre)) {
		np_error("alloc pcre failed.\n");
		return NULL;
	}
	pcre->patlen = len;
	pcre->pattern = calloc(len + 1, sizeof(u8));

	if (IS_ERR_OR_NULL(pcre->pattern))
		goto err_pattern;

	memcpy(pcre->pattern, pattern, len);

	rc = pattern_parse((char *)pattern, &pcre->pcre, &pcre->op_str);
	if (rc < 0)
		goto err_pattern;

	opts_parse(pcre->op_str, &pcre->opts);

	pcre->re = pcre2_compile(pcre->pcre, PCRE2_ZERO_TERMINATED,
		pcre->opts, &ec, &erroffset, NULL);
	if (IS_ERR_OR_NULL(pcre->re))
		goto err_code;

	if (sysctl_jit_enable) {
		pcre->mcontext = pcre2_match_context_create(NULL);
		if (IS_ERR_OR_NULL(pcre->mcontext))
			goto err_match_context;

		rc = pcre2_jit_compile(pcre->re, PCRE2_JIT_COMPLETE);
		if (rc < 0)
			goto err_match_context;

		pcre->jit_stack = pcre2_jit_stack_create(\
			sysctl_jit_stack_start * 1024,
			sysctl_jit_stack_max * 1024, NULL);
		if (IS_ERR_OR_NULL(pcre->jit_stack))
			goto err_jit_stack;

		pcre2_jit_stack_assign(pcre->mcontext, NULL, pcre->jit_stack);
	}

	pcre->match_data = pcre2_match_data_create(1, NULL);
	if (IS_ERR_OR_NULL(pcre->match_data))
		goto err_match_data;

	return pcre;

 err_match_data:
	np_debug("err_match_data\n");
	if (sysctl_jit_enable)
		pcre2_jit_stack_free(pcre->jit_stack);

 err_jit_stack:
	np_debug("err_jit_stack\n");
	if (sysctl_jit_enable)
		pcre2_match_context_free(pcre->mcontext);

 err_match_context:
	np_debug("err_match_context\n");
	pcre2_code_free(pcre->re);

 err_code:
	np_debug("err_code\n");
	free(pcre->pattern);

 err_pattern:
	np_debug("err pattern compile.\n");
	free(pcre);
	return NULL;
}
EXPORT_SYMBOL(pcre_create);

void pcre_destroy(pcre_t *pcre)
{
	if (pcre->pattern)
		free(pcre->pattern);

	if (pcre->re)
		pcre2_code_free(pcre->re);

	if (pcre->match_data)
		pcre2_match_data_free(pcre->match_data);

	if (pcre->mcontext)
		pcre2_match_context_free(pcre->mcontext);

	if (pcre->jit_stack)
		pcre2_jit_stack_free(pcre->jit_stack);

	if (pcre->pcre)
		pcre2_substring_free(pcre->pcre);

	if (pcre->op_str)
		pcre2_substring_free(pcre->op_str);
}
EXPORT_SYMBOL(pcre_destroy);

void *pcre_get_pattern(pcre_t *pcre)
{
	return pcre->pattern;
}

unsigned int pcre_get_pattern_len(pcre_t *pcre)
{
	return pcre->patlen;
}

static int sysctl_pcre_jit(struct ctl_table *ctl, int write,
                  void __user *buffer,
                  size_t *lenp, loff_t *ppos)
{
    int ret = proc_dointvec(ctl, write, buffer, lenp, ppos);

	if (sysctl_jit_enable)
		sysctl_jit_enable = true;

	if (sysctl_jit_stack_start < 8)
		sysctl_jit_stack_start = 8;

	if (sysctl_jit_stack_start > sysctl_jit_stack_max)
		sysctl_jit_stack_max = sysctl_jit_stack_start;

	return ret;
}

static struct ctl_table_header *pcre_table_header = NULL;

static struct ctl_table pcre_table[] = {
    {
        .procname   = "jit_enable",
        .data       = &sysctl_jit_enable,
        .maxlen     = sizeof(int),
        .mode       = S_IRUGO|S_IWUSR,
        .proc_handler   = sysctl_pcre_jit,
    },
    {
        .procname   = "jit_stack_start",
        .data       = &sysctl_jit_stack_start,
        .maxlen     = sizeof(int),
        .mode       = S_IRUGO|S_IWUSR,
        .proc_handler   = sysctl_pcre_jit,
    },
    {
        .procname   = "jit_stack_max",
        .data       = &sysctl_jit_stack_max,
        .maxlen     = sizeof(int),
        .mode       = S_IRUGO|S_IWUSR,
        .proc_handler   = sysctl_pcre_jit,
    },
    { }
};

static struct ctl_table pcre_dir_table[] = {
    {
        .procname   = "pcre",
        .maxlen     = 0,
        .mode       = S_IRUGO|S_IXUGO,
        .child      = pcre_table,
    },
    { }
};

int pcre_init(void)
{
	extern int pcre2_init(void);
	PCRE2_SIZE erroffset;
	int ec;

	ec = pcre2_init();
	if(ec) {
		np_error("pcre2 init failed: %d.\n", ec);
		return ec;
	}

	parse_regex = pcre2_compile(PARSE_REGEX,
				    PCRE2_ZERO_TERMINATED, 0, &ec,
				    &erroffset, NULL);
	if (IS_ERR_OR_NULL(parse_regex)) {
		PCRE2_UCHAR8 buffer[120];
		(void)pcre2_get_error_message(ec, buffer, 120);
		np_error("valid regex compile error.\n");
		return -ENOMEM;
	}

	pcre_table_header = register_sysctl_table(pcre_dir_table);
	return 0;
}

void pcre_cleanup(void)
{
	extern void pcre2_exit(void);

	if (parse_regex)
		pcre2_code_free(parse_regex);

	pcre2_exit();
	unregister_sysctl_table(pcre_table_header);
}
