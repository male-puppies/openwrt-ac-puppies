#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include "rdsparser.h"

#ifdef _WIN32 
#define snprintf _snprintf
#endif 

#define BUG_ON(conn) do{\
	if((conn)) {\
		fprintf(stderr, "%s %d\n", __FILE__, __LINE__);\
		exit(-1);\
	}}while(0)

void *mnew(int size) {
	void *buff = malloc(size);	BUG_ON(!buff); 
	return buff;
}

enum {
	RDS_NEW,
	RDS_RUN, 
	RDS_ERR,
};

#define DEFAULT_BUFF_SIZE	(32 * 1024)
#define EXPECT_BUFF_SIZE	(256 * 1024)

typedef struct rdsst {
	char *buff;
	int cursize;
	int maxsize;
	int state;

	rds_result res;
} rdsst;

void rds_free(rdsst *rds) {
	if (rds->buff) {
		free(rds->buff);
		rds->buff = NULL;
	}
	rds_result_free(&rds->res);
	free(rds);
}

char *rds_encode(rds_str *arr, int count, int *len) {
	assert(arr && count > 0);

	char *buff;
	int i, pos, ret, total;

	total = count * 10 + (count * 2 + 1) * 2; /* 参数个数和每段长度最长为10位数字；\r\n长度为2，每个段有2个，参数个数带一个\r\n */
	
	for (i = 0; i < count; i++) {
		total += arr[i].len;	assert(arr[i].p && arr[i].len > 0 && arr[i].len <= 256 * 1024 * 1024);
	}

	pos = 0;
	buff = (char *)mnew(total);
	
	ret = snprintf(buff + pos, total - pos, "*%d\r\n", count);		BUG_ON(ret >= total);
	pos += ret;

	for (i = 0; i < count; i++) {
		ret = snprintf(buff + pos, total - pos, "$%d\r\n", arr[i].len);	BUG_ON(ret >= total);
		pos += ret;

		BUG_ON(pos + arr[i].len + 2 >= total);
		
		memcpy(buff + pos, arr[i].p, arr[i].len);
		pos += arr[i].len;

		memcpy(buff + pos, "\r\n", 2);
		pos += 2;
	}

	BUG_ON(pos + 1 >= total);

	buff[pos] = 0;
	*len = pos;

	return buff;
}

rdsst *rds_new() {
	rdsst *ins = (rdsst *)mnew(sizeof(rdsst));
	memset(ins, 0, sizeof(rdsst));
	return ins;
}

static int adjust_size(int size) {
	int i;
	for (i = 0; i <24 ; i++) {
		int n = (1<<i);
		if (n >= size) {
			return n;
		}
	}
	BUG_ON(1);
}

static void rds_cache(rdsst *rds, const char *buff, size_t bufsize) {
	if (!rds->buff) {
		rds->maxsize = DEFAULT_BUFF_SIZE;
		rds->buff = (char *)mnew(rds->maxsize);
	}

	if (rds->cursize + (int)bufsize > rds->maxsize) {
		int nsize = rds->cursize + bufsize;					BUG_ON(nsize > 10 * 1024*1024);
		rds->maxsize = adjust_size(nsize);
		rds->buff = (char *)realloc(rds->buff, nsize);		BUG_ON(!(rds->buff));
		printf("%s %d realloc buffer %d\n", __FILE__, __LINE__, rds->maxsize);
	}

	memcpy(rds->buff + rds->cursize, buff, bufsize);
	rds->cursize += bufsize;
}

static void shrink_buff(rdsst *rds) {
	if (rds->maxsize <= EXPECT_BUFF_SIZE) {
		return;
	}

	printf("shrink %d %d %d\n", rds->cursize, rds->maxsize, EXPECT_BUFF_SIZE); 

	rds->maxsize = EXPECT_BUFF_SIZE;
	rds->buff = (char *)realloc(rds->buff, rds->maxsize);		BUG_ON(!(rds->buff));
}

int static read_rds_len(const char *base, const char *last, char ch, char **pp, int *out) {
	BUG_ON(!base || !last || base > last);

	if (*base != ch) { 
		return -1;
	}

	// read content len
	const char *p = base + 1;
	if (p >= last) {
		return 1;		// not read enough
	}

	int count = 0;
	do {
		if (p + 1 >= last) {
			return 1;	// not read enough
		}

		if (*p == '\r' && *(p + 1) == '\n') { 
			p += 2;
			break;		//match "\r\n"
		}

		if (*p < '0' || *p > '9') {
			return -1;		// error : not a number
		}

		count *= 10;
		count += *p - '0';

		p++;
	} while(1);

	if (count >= 100000000) { 
		return -1;	// error : too large
	}

	*pp = (char *)p;
	*out = count;
	
	return 0;
}

int static read_param_content(rdsst *rds) {
	BUG_ON(rds->state != RDS_RUN || rds->res.res_idx >= rds->res.res_count);
	
	int i;
	for (i = rds->res.res_idx; i < rds->res.res_count; i++) {
		char  *p;
		int len, ret;
		
		if (!rds->cursize) {
			return 1;
		}
		
		ret = read_rds_len(rds->buff, rds->buff + rds->cursize, '$', &p, &len);
		if (ret < 0) { 
			return -1;
		}

		if (ret > 0) {
			return 1;
		}

		int left = rds->cursize - (p - rds->buff);
		if (left < len + 2) {	//"\r\n"
			return 1;
		}

		if (*(p + len) != '\r' || *(p + len + 1) != '\n') {
			return -1;
		}

		rds_str *rs = &rds->res.res_arr[i];
		rs->len = len;

		rs->p = (char *)mnew(len + 1);
		memcpy(rs->p, p, len);
		rs->p[len] = 0;

		p += len + 2;		/* "\r\n" */
		left -= (len + 2);

		rds->cursize -= p - rds->buff;
		memmove(rds->buff, p, left);
		
		rds->res.res_idx++;
	}

	return 0;
}

int rds_decode(rdsst *rds, const char *buff, int bufsize, rds_result *out) { 
	BUG_ON(rds->state == RDS_ERR);

	if (buff && bufsize > 0) {
		rds_cache(rds, buff, bufsize);	BUG_ON(!bufsize);
	}

	if (!rds->cursize) {
		return 1;
	}

	if (rds->state == RDS_NEW) {
		char *p;
		int count, ret;
		rds_result *res; 

		ret = read_rds_len(rds->buff, rds->buff + rds->cursize, '*', &p, &count);
		if (ret < 0) {
			rds->state = RDS_ERR;
			return -1;
		}

		if (ret > 0) {
			return 1;
		}

		res = &rds->res;	BUG_ON(res->res_arr || res->res_idx || res->res_count);
		res->res_arr = (rds_str *)(mnew(sizeof(rds_str) * count));
		res->res_count = count;

		rds->state = RDS_RUN;

		rds->cursize -= p - rds->buff;		BUG_ON(rds->cursize < 0);
		memmove(rds->buff, p, rds->cursize); 
	}

	int ret = read_param_content(rds);
	if (ret < 0) {
		rds->state = RDS_ERR;
		return -1;
	}

	if (ret > 0) {
		return 1;
	}

	rds_result *res = &rds->res;			BUG_ON(res->res_idx != res->res_count);
	memcpy(out, res, sizeof(rds_result));
	memset(res, 0, sizeof(rds_result));

	rds->state = RDS_NEW;
	if (!rds->cursize) {
		shrink_buff(rds);
	}

	return 0;
}

void rds_result_free(rds_result *res) {
	int i;
	for (i = 0; i < res->res_idx; i++) {
		if (res->res_arr[i].p) {
			free(res->res_arr[i].p);
			res->res_arr[i].p = NULL;
		}
	}
	free(res->res_arr);
}

int rds_empty(rdsst *rds) {
	return rds->cursize == 0;
}
