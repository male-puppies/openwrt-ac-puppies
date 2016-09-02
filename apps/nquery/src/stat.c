#include "nquery.h"

const char *fn_stat_flow = "/var/run/nt_flow.dump";
const char *fn_stat_user = "/var/run/nt_user.dump";

static int dump_to_file(FILE *fp, char *id, uint64_t recv, uint64_t xmit)
{
	int n;

	n = fprintf(fp, "[%s] %ld %llu %llu\n", id, time(NULL), recv, xmit);
	if(n<0) {
		nt_error("err %p: %s\n", fp, strerror(errno));
	}
	return n;
}

static int trav_hook_user(user_info_t *ui, void *p)
{
	FILE* fp = p;
	char buff[128];

	snprintf(buff, sizeof(buff), "%u.%u.%u.%u", NIPQUAD(ui->ip));
	return dump_to_file(fp, buff, ui->hdr.recv_bytes, ui->hdr.xmit_bytes);
}

static int trav_hook_flow(flow_info_t *fi, void *p)
{
	FILE* fp = p;
	char buff[128];

	snprintf(buff, sizeof(buff), "%d-%d", fi->id, fi->magic);
	return dump_to_file(fp, buff, fi->hdr.recv_bytes, fi->hdr.xmit_bytes);
}

FILE *open_and_lock(const char *fn)
{
	FILE *fp = fopen(fn, "a+");
	if(!fp) {
		nt_error("open '%s' failed: %s\n", fn, strerror(errno));
		return NULL;
	}
	return fp;
}

static int ntrack_stat_user(void)
{
	int res = 0;

	FILE *fp = open_and_lock(fn_stat_user);
	if(!fp) {
		nt_error("open and lock file: %s failed.\n", fn_stat_user);
		exit(-1);
	}

	res = nt_trav_user(pntrack, 0, 0, fp, trav_hook_user);
	if(res < 0) {
		nt_error("trav failed: %d\n", res);
		exit(-1);
	}

	fclose(fp);
	return 0;
}

static int ntrack_stat_flow(void)
{
	int fd, res = 0;

	FILE *fp = open_and_lock(fn_stat_flow);
	if(!fp) {
		nt_error("open and lock file: %s failed.\n", fn_stat_user);
		exit(-1);
	}

	res = nt_trav_flow(pntrack, 0, 0, fp, trav_hook_flow);
	if(res < 0) {
		nt_error("trav failed: %d\n", res);
		exit(-1);
	}

	fclose(fp);
	return 0;
}

int ntrack_stat(int type)
{
	if(type) {
		return ntrack_stat_flow();
	}
	return ntrack_stat_user();
}