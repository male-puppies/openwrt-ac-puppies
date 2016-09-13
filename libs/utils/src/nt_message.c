#include "lib_private.h"

const char *fn_sys_mem = "/dev/mem";
const char *fn_base_loff = "/proc/sys/kernel/nt_shm_base";
const char *fn_mem_size = "/proc/sys/kernel/nt_shm_size";
const char *fn_shm_uoff = "/proc/sys/kernel/nt_user_offset";
const char *fn_shm_foff = "/proc/sys/kernel/nt_flow_offset";
const char *fn_stat_off = "/proc/sys/kernel/nt_stat_offset";
const char *fn_stat_size = "/proc/sys/kernel/nt_stat_size";
const char *fn_flow_max = "/proc/sys/kernel/nt_flow_max";
const char *fn_user_max = "/proc/sys/kernel/nt_user_max";
const char *fn_shm_cap_sz = "/proc/sys/kernel/nt_cap_block_sz";

static void* shm_base_addr = NULL;
static void* shm_base_user = NULL;
static void* shm_base_flow = NULL;
static void* shm_base_stat = NULL;

static void* nt_shm_base;
static uint32_t nt_shm_size;
static uint32_t shm_user_offset;
static uint32_t shm_flow_offset;
static uint32_t shm_stat_offset;
static uint32_t shm_stat_size;
static uint32_t nt_flow_max, nt_user_max;
static uint32_t nt_cap_block_sz;

static int proc_uint(void *out, const char *fname)
{
	int fd = open(fname, O_RDONLY);
	if(fd < 0) {
		nt_error("open %s\n", fname);
		return -EINVAL;
	}

	char buff[32];
	memset(buff, 0, sizeof(buff));
	ssize_t c = read(fd, buff, sizeof(buff));
	close(fd);

	if(c > 0) {
		*(int*)out = atoi(buff);
		return 0;
	} else {
		nt_error("%s\n", strerror(errno));
		return errno;
	}
}

static int proc_pars_init(void)
{
	int res = 0;

	if((res=proc_uint(&nt_shm_base, fn_base_loff))) {
		nt_error("read nt base loff failed: %d\n", res);
		return res;
	}
	if((res=proc_uint(&nt_shm_size, fn_mem_size))) {
		nt_error("read nt shm size failed: %d\n", res);
		return res;
	}
	if((res=proc_uint(&nt_cap_block_sz, fn_shm_cap_sz))) {
		nt_error("read nt cap block failed: %d\n", res);
		return res;
	}
	if((res=proc_uint(&shm_user_offset, fn_shm_uoff))) {
		nt_error("read nt user offset failed: %d\n", res);
		return res;
	}
	if((res=proc_uint(&shm_flow_offset, fn_shm_foff))) {
		nt_error("read nt flow offset failed: %d\n", res);
		return res;
	}
	if((res=proc_uint(&shm_stat_offset, fn_stat_off))) {
		nt_error("read nt stat offset failed: %d\n", res);
		return res;
	}
	if((res=proc_uint(&shm_stat_size, fn_stat_size))) {
		nt_error("read nt stat size failed: %d\n", res);
		return res;
	}
	if((res=proc_uint(&nt_flow_max, fn_flow_max))) {
		nt_error("read nt flow max failed.\n");
		return res;
	}
	if((res=proc_uint(&nt_user_max, fn_user_max))) {
		nt_error("read nt user max failed.\n");
		return res;
	}	

	nt_info("nt proc: 0x%x-0x%x\n"
		"\tuser offset: 0x%x, count: %u\n"
		"\tflow offset: 0x%x, count: %u\n"
		"\tstat offset: 0x%x, mem_sz: %u\n"
		"\tcapblk size: 0x%x\n",
		(unsigned int)nt_shm_base, (unsigned)nt_shm_size,
		(unsigned int)shm_user_offset, (unsigned)nt_user_max,
		(unsigned int)shm_flow_offset, (unsigned)nt_flow_max,
		(unsigned int)shm_stat_offset, (unsigned)shm_stat_size,
		(unsigned int)nt_cap_block_sz);

	return 0;
}

static int shm_init(ntrack_t *nt)
{
	int fd = open(fn_sys_mem, O_RDWR);
	if(fd == -1) {
		nt_error("open shm.\n");
		return -EINVAL;
	}

	shm_base_addr = mmap(0, nt_shm_size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, (off_t)nt_shm_base);
	if (shm_base_addr == MAP_FAILED) {
		nt_error("mem map.\n");
		return -ENOMEM;
	}
	shm_base_user = shm_base_addr + shm_user_offset;
	shm_base_flow = shm_base_addr + shm_flow_offset;
	shm_base_stat = shm_base_addr + shm_stat_offset;

	nt_info("shm[off:%x, size: %x]\n\tbase: %p, user: %p, flow: %p, stat: %p\n", \
		(unsigned int)nt_shm_base, (unsigned int)nt_shm_size, \
		shm_base_addr, shm_base_user, shm_base_flow, shm_base_stat);

	nt->fi_base = shm_base_flow;
	nt->ui_base = shm_base_user;
	nt->stat_base = shm_base_stat;
	nt->fi_count = nt_flow_max;
	nt->ui_count = nt_user_max;
	nt->stat_size = shm_stat_size;

	return 0;
}

static int shm_rbf_init(rbf_t **rbfpp)
{
	cpu_set_t set;
	rbf_t *rbp = NULL;

	CPU_ZERO(&set);
	if(sched_getaffinity(0, sizeof(set), &set) == -1) {
		nt_error("get affinity. %s\n", strerror(errno));
		return errno;
	}
	nt_info("cpu sets: 0x%x\n", *(unsigned int*)&set);

	for (int i=0; i<=CPU_COUNT(&set); i++) {
		if(CPU_ISSET(i, &set)) {
			rbp = rbf_init(shm_base_addr + nt_cap_block_sz * i, nt_cap_block_sz);
			if(!rbp) {
				nt_error("rbp init\n");
				continue;
			}
			nt_info("on core: %d, %p\n", i, rbp);
			*rbfpp = rbp;
			break;
		} else {
			nt_info("ignore core: %d\n", i);
		}
	}

	return 0;
}

int nt_message_init(rbf_t **rbfpp)
{
	if (shm_rbf_init(rbfpp)) {
		return -EINVAL;
	}
	return 0;
}

int nt_base_init(ntrack_t *nt)
{
	if (proc_pars_init()) {
		return -EINVAL;
	}

	if (shm_init(nt)) {
		return -EINVAL;
	}

	return 0;
}

int nt_message_process(rbf_t *rbfp, uint32_t *running, nmsg_cb_t cb)
{
	void *p;

	nt_assert(rbfp);
	while(*running) {
		p = rbf_get_data(rbfp);
		if (!p) {
			// nt_debug("read empty.\n");
			usleep(500);
			continue;
		}
		// nt_dump(p, 128, "node\n");
		if(cb) {
			cb(p);
		}
		// rbf_dump(rbfp);
		rbf_release_data(rbfp);
	}
}