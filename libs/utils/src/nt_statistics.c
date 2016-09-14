#include "lib_private.h"

#define FMT_STAT_STR "%u %u %u %u"
#define FMT_STAT_DATA(x) \
			(unsigned)(x)->xmit_pkts,\
			(unsigned)(x)->xmit_bytes,\
			(unsigned)(x)->recv_pkts,\
			(unsigned)(x)->recv_bytes

const char* fn_stat_lock = "/proc/nproto/lock_stat";
static int fd_lock = -1;

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

int nt_stat_flush(ntrack_t *nt, FILE *fp)
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
