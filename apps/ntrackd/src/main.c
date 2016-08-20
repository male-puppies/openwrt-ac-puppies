#define _GNU_SOURCE
#define __DEBUG

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
#include <sys/socket.h>

#include <linux/netlink.h>

#include <pthread.h>

#include <ntrack_rbf.h>
#include <ntrack_log.h>
#include <ntrack_msg.h>
#include <ntrack_auth.h>
#include <ntrack_nacs.h>

/* kernel user node message delivery to authd. */
extern int nt_unotify_init(void);
extern int nt_unotify(void *buff, int len);

static ntrack_t ntrack;

static int fn_message_disp(void *p)
{
#if 0
	cpu_set_t set;
	CPU_ZERO(&set);
	if(sched_getaffinity(0, sizeof(set), &set) == -1) {
		nt_error("get affinity.\n");
		return 0;
	}
	int i;
	for(i=0; i<CPU_COUNT(&set); i++) {
		if(CPU_ISSET(i, &set)) {
			nt_debug("on core: %d\n", i);
		}
	}
#endif

	nt_msghdr_t *hdr = p;
	switch(hdr->type) {
		case en_MSG_PCAP:
		break;
		case en_MSG_NODE:
		break;
		case en_MSG_AUTH:
		{
			user_info_t *ui;
			auth_msg_t *auth = nt_msg_data(hdr);
			char buf[128];
			int n;
			n = sprintf(buf, "{\"cmd\":\"keepalive\",\"magic\":%u,\"uid\":%u}", auth->magic, auth->id);
			
			nt_debug("message uid: %u, magic: %u\n", auth->id, auth->magic);
			ui = nt_get_user_by_id(&ntrack, auth->id, auth->magic);
			if(ui) {
				dump_user(ui);
				if (nt_unotify(buf, n) != 0) {
					nt_error("nt_unotify failed: %s\n", strerror(errno));
				}
			} else {
				nt_error("[%u:%u]->not found userinfo.\n", auth->id, auth->magic);
			}
		}
		break;

		case en_MSG_NACS:
			{
				nacs_msg_t *nacs = nt_msg_data(hdr);
				/*todo transmit to other process*/
			}
			break;

		default:
		{
			nt_error("unknown message. %d\n", hdr->type);
		}
		break;
	}
	return 0;
}

typedef struct {
	int core_id; /* which core, this thread to run on. */
	int running;
	pthread_t tid;
} nt_thread_t;

static void *nt_work_fn(void *d)
{
	rbf_t *rbfp;
	cpu_set_t set;
	nt_thread_t *nth = (nt_thread_t*)d;

	CPU_ZERO(&set);
	CPU_SET(nth->core_id, &set);
	if(sched_setaffinity(0, sizeof(set), &set) == -1) {
		nt_error("set [%d] affinity.\n", nth->core_id);
		return (void*)-1;
	}
	nt_debug("nt work thread on core: %d\n", nth->core_id);

	if(nt_message_init(&rbfp)){
		nt_error("ring buff init failed.\n");
		return (void*)-1;
	}

	nth->running = 1;
	nt_message_process(rbfp, &nth->running, fn_message_disp);
	return 0;
}

int main(int argc, char *argv[])
{
	int i;

	/* to user authd. */
	nt_unotify_init();

	/* mmap init & user/flow info. */
	if (nt_base_init(&ntrack)) {
		nt_error("ntrack message init failed.\n");
		return 0;
	}

	cpu_set_t set;
	CPU_ZERO(&set);
	if (sched_getaffinity(0, sizeof(set), &set) == -1) {
		nt_error("get cpuset error: %s\n", strerror(errno));
		exit(EXIT_FAILURE);
	}

	nt_info("core total nums[%d]\n", CPU_COUNT(&set));
	nt_thread_t *threads = malloc(sizeof(nt_thread_t) * CPU_COUNT(&set));
	for (i=0; i<CPU_COUNT(&set); i++) {
		pthread_attr_t attr;
		pthread_attr_init(&attr);

		threads[i].core_id = i;
		if(pthread_create(&threads[i].tid, &attr, nt_work_fn, &threads[i]) !=0 ) {
			nt_error("create [%d] work thread.\n", i);
			exit(EXIT_FAILURE);
		}
		usleep(10);
	}

	for(i=0; i<CPU_COUNT(&set); i++) {
		void *res;
		if(pthread_join(threads[i].tid, &res) !=0 ) {
			nt_error("join thread[%d] error.\n", i);
			exit(EXIT_FAILURE);
		}
		nt_info("join %d: %p\n", i, res);
		free(res);
	}
	free(threads);
	return 0;
}
