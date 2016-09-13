#include "lib_private.h"

const char* fn_stat_lock = "/proc/nproto/stat_lock";

static int fd_lock = -1;

static int flush_lock(void)
{
	fd_lock = open(fn_stat_lock, O_RDONLY);
	if(fd_lock == -1) {
		nt_error("open lock file [%s]\n", fn_stat_lock);
		exit(errno);
	}
	return 0;
}

static void flush_unlock(void)
{
	close(fd_lock);
}

int nt_stat_flush(ntrack_t *nt)
{
	int i, idx;
	stat_info_t *info = nt->stat_base;
	stat_data_t *data;

	assert(nt);

	flush_lock();
	
	fprintf(stderr, "dump flow:\n");
	for (i = 0; i < info->nr_active_flow; ++i) {
		idx = info->offset_stat_flow + i;
		data = &info->data[i];
		fprintf(stderr, "%u %u\n", data->id, data->magic);
	}

	fprintf(stderr, "dump user:\n");
	for (i = 0; i < info->nr_active_user; ++i)	{
		idx = info->offset_stat_user + i;
		data = &info->data[i];
		fprintf(stderr, "%u %u\n", data->id, data->magic);
	}

	flush_unlock();
	return 0;
}
