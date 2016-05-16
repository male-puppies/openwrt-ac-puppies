#define _GNU_SOURCE
#include <sched.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <fcntl.h>
#include <errno.h>

#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>

#include <linux/nos_track.h>

#include <ntrack_rbf.h>
#include <ntrack_log.h>
#include <ntrack_msg.h>

const char *fn_sys_mem = "/dev/mem";
const char *fn_shm_uoff = "/proc/sys/kernel/nt_user_offset";
const char *fn_shm_foff = "/proc/sys/kernel/nt_flow_offset";
const char *fn_shm_cap_sz = "/proc/sys/kernel/nt_cap_block_sz";

static void* shm_base_addr = NULL;
static void* shm_base_user = NULL;
static void* shm_base_flow = NULL;
static uint32_t shm_user_offset;
static uint32_t shm_flow_offset;
static uint32_t nt_cap_block_sz;
static rbf_t *nt_message_rbf = NULL;

static int proc_uint(uint32_t *out, const char *fname)
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
		*out = atoi(buff);
		return 0;
	} else {
		nt_error("%s\n", strerror(errno));
		return errno;
	}
}

static int proc_pars_init(void)
{
	int res = 0;

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

	nt_info("nt proc: \n"
		"\tuser offset: 0x%x\n" 
		"\tflow offset: 0x%x\n" 
		"\tcapblk size: 0x%x\n", 
		shm_user_offset, shm_flow_offset, nt_cap_block_sz);

	return 0;
}

static int shm_init(void **ui_base, uint32_t *ui_cnt, void ** fi_base, uint32_t *fi_cnt)
{
	int fd = open(fn_sys_mem, O_RDWR);
	if(fd == -1) {
		nt_error("open shm.\n");
		return -EINVAL;
	}

	shm_base_addr = mmap(0, SIZE_RESERVE_MEM, PROT_READ | PROT_WRITE, MAP_SHARED, fd, START_RESERVE_MEM);
	if (!shm_base_addr) {
		nt_error("mem map.\n");
		return -ENOMEM;
	}
	shm_base_user = shm_base_addr + shm_user_offset;
	shm_base_flow = shm_base_addr + shm_flow_offset;

	nt_info("shm[off:%x, size: %x]\n\tbase: %p, user: %p, flow: %p\n", START_RESERVE_MEM, SIZE_RESERVE_MEM, \
		shm_base_addr, shm_base_user, shm_base_flow);

	*fi_base = shm_base_flow;
	*ui_base = shm_base_user;
	*fi_cnt = flow_info_count;
	*ui_cnt = user_info_count;

	return 0;
}

static int shm_rbf_init(void)
{
	cpu_set_t set;
	rbf_t *rbp = NULL;

	CPU_ZERO(&set);
	if(sched_getaffinity(getpid(), sizeof(set), &set) == -1) {
		nt_error("get affinity. %s\n", strerror(errno));
		return errno;
	}
	fprintf(stderr, "cpu sets: 0x%x\n", *(unsigned long*)&set);

	for (int i=0; i<=CPU_COUNT(&set); i++) {
		if(CPU_ISSET(i, &set)) {
			rbp = rbf_init(shm_base_addr + nt_cap_block_sz * i, nt_cap_block_sz);
			if(!rbp) {
				nt_error("rbp init\n");
				continue;
			}
			nt_info("on core: %d, %p\n", i, rbp);
			nt_message_rbf = rbp;
			break;
		} else {
			nt_info("not core: %d\n", i);
		}
	}

	return 0;
}

int nt_message_init(ntrack_t *nt)
{
	if (proc_pars_init()) {
		return -EINVAL;
	}

	if (shm_init(
		&nt->ui_base, &nt->ui_count, 
		&nt->fi_base, &nt->fi_count)) {
		return -EINVAL;
	}

	if (shm_rbf_init()) {
		return -EINVAL;
	}

	return 0;
}

int nt_message_process(uint32_t *running, nmsg_cb_t cb)
{
	void *p;

	nt_assert(nt_message_rbf);
	while(*running) {
		p = rbf_get_data(nt_message_rbf);
		if (!p) {
			// nt_debug("read empty.\n");
			sleep(0.01); //10ms
			continue;
		}
		// nt_dump(p, 128, "node\n");
		if(cb) {
			cb(p);
		}
		rbf_dump(nt_message_rbf);
		rbf_release_data(nt_message_rbf);
	}
}