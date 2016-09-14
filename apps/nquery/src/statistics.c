#include "nquery.h"

#define FMT_FN_FLOW "/var/run/stat_flow/%lu.dump"
#define FMT_FN_USER "/var/run/stat_user/%lu.dump"

const char* fn_stat_lock = "/proc/nproto/lock_stat";
static int fd_lock = -1;

typedef struct {
	FILE *fp;
}trav_priv_t;

FILE *open_and_lock(const char *fn)
{
	FILE *fp = fopen(fn, "w+");
	if(!fp) {
		nt_error("open '%s' failed: %s\n", fn, strerror(errno));
		return NULL;
	}
	return fp;
}

static int trav_priv_init(trav_priv_t *ptrav, const char *fname)
{
	FILE *fp = open_and_lock(fname);
	if(!fp) {
		nt_error("open and lock file: %s failed.\n", fname);
		exit(-1);
	}
	ptrav->fp = fp;
	return 0;
}

static int trav_flush(trav_priv_t *ptrav)
{
	/* update the counters */
	assert(ptrav->fp);
	fclose(ptrav->fp);
}

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
	char buff[128];
	trav_priv_t *ptrav = p;

	snprintf(buff, sizeof(buff), "%u.%u.%u.%u", NIPQUAD(ui->ip));
	return dump_to_file(ptrav->fp, buff, ui->hdr.recv_bytes, ui->hdr.xmit_bytes);
}

static int trav_hook_flow(flow_info_t *fi, void *p)
{
	char buff[128];
	trav_priv_t *ptrav = p;

	snprintf(buff, sizeof(buff), "%u.%u.%u.%u:%u-%u.%u.%u.%u:%u-%u",
		NIPQUAD(fi->tuple.ip_src), ntohs(fi->tuple.port_src),
		NIPQUAD(fi->tuple.ip_dst), ntohs(fi->tuple.port_dst), fi->tuple.proto);
	return dump_to_file(ptrav->fp, buff, fi->hdr.recv_bytes, fi->hdr.xmit_bytes);
}

static int ntrack_stat_trav(char *fn, nt_trav_t trav_fn, void *hook)
{
	int fd, res = 0, offset = 0;
	trav_priv_t trav;

	memset(&trav, 0, sizeof(trav));
	res = trav_priv_init(&trav, fn);
	if(res) {
		exit(-1);
	}

	do {
		int count = trav_fn(pntrack, offset, 1000, &trav, hook);
		if(count <= 0) {
			break;
		}
		offset += count;
		nt_info("offset: %d, count: %d\n", offset, count);
		sleep(0.1);
	} while(1);

	res = trav_flush(&trav);
	if(res) {
		exit(-1);
	}
	return 0;
}

int ntrack_stat(int type)
{
	char dump_fname[1024];
	if(type) {
		snprintf(dump_fname, sizeof(dump_fname), FMT_FN_FLOW, (unsigned long)time(NULL));
		return ntrack_stat_trav(dump_fname, nt_trav_flow, trav_hook_flow);
	}
	snprintf(dump_fname, sizeof(dump_fname), FMT_FN_USER, (unsigned long)time(NULL));
	return ntrack_stat_trav(dump_fname, nt_trav_user, trav_hook_user);
}


static int flush_lock(void)
{
	fd_lock = open(fn_stat_lock, O_RDONLY);
	if(fd_lock == -1) {
		nt_error("open lock file [%s]\n", fn_stat_lock);
		return -1;
	}
	return 0;
}

static void flush_unlock(void)
{
	close(fd_lock);
}

static int nt_stat_flush(ntrack_t *nt, FILE *fp)
{
	int i, idx;
	stat_info_t *info = nt->stat_base;
	stat_data_t *data;

	assert(nt);

	if(flush_lock()) {
		return -1;
	}

	if(!fp)
		fp = stdout;

	// fprintf(fp, "dump flow:\n");
	for (i = 0; i < info->nr_active_flow; ++i) {
		idx = info->offset_stat_flow + i;
		data = &info->data[i];
		fprintf(fp, "[%u-%u]"FMT_STAT_STR"\n",
			data->id, data->magic, FMT_STAT_DATA(data));
	}

	// fprintf(fp, "dump user:\n");
	for (i = 0; i < info->nr_active_user; ++i)	{
		idx = info->offset_stat_user + i;
		data = &info->data[i];
		fprintf(fp, "[%u:%u]"FMT_STAT_STR"\n",
			data->id, data->magic, FMT_STAT_DATA(data));
	}

	fflush(fp);
	flush_unlock();
	return 0;
}

int ntrack_flush(void)
{
	return nt_stat_flush(pntrack, NULL);
}
