#ifndef __RDS_PARSER_H__
#define __RDS_PARSER_H__

typedef struct rds_str {
	int len;
	char *p;
} rds_str;

typedef struct rds_result {
	rds_str *res_arr;
	int res_idx;
	int res_count;
} rds_result;

typedef struct rdsst rdsst;

/* build */
char *rds_encode(rds_str *arr, int count, int *len);

rdsst *rds_new();
void rds_free(rdsst *rds); 
int rds_decode(rdsst *rds, const char *buff, int bufsize, rds_result *res);
void rds_result_free(rds_result *res);
int rds_empty(rdsst *rds); 
#endif
