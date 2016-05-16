#define _GNU_SOURCE
#include <sched.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <fcntl.h>

#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>

#include <ntrack_rbf.h>

#define SHM_NAME "/dev/mem"

int main(int argc, char *argv[])
{
	cpu_set_t set;
	rbf_t *rbp;
	void *base_addr, *p;
	uint32_t size = (RBF_NODE_SIZE) * 1024 + sizeof(rbf_hdr_t);

	CPU_ZERO(&set);

	int fd = open(SHM_NAME, O_RDWR);
	if(fd == -1) {
		perror("open shm.\n");
		exit(EXIT_FAILURE);
	}

	base_addr = mmap(0, 4<<20, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 16<<20);
	if (!base_addr) {
		perror("mem map.\n");
		exit(EXIT_FAILURE);
	}

	// memset(base_addr, 0xff, size);
	rbp = rbf_init(base_addr, size);
	if(!rbp) {
		perror("rbp init\n");
		exit(EXIT_FAILURE);
	}

	switch(fork()) {
		case -1:
		perror("fork failed.\n");
		exit(EXIT_FAILURE);
		break;

		case 0:
		CPU_SET(1, &set);
		if(sched_setaffinity(getpid(), sizeof(set), &set) == -1) {
			perror("set c affinity.\n");
			exit(EXIT_FAILURE);
		}
		// fprintf(stderr, "%d->%d core: %d\n", getppid(), getpid(), sched_getcpu());

		while(1) {
			p = rbf_get_buff(rbp);
			if (!p) {
				perror("overflow\n");
				sleep(1);
				continue;
			}
			memset(p, 'x', RBF_NODE_SIZE);
			rbf_release_buff(rbp);
		};

		exit(EXIT_SUCCESS);

		default:
		CPU_SET(0, &set);
		if(sched_setaffinity(getpid(), sizeof(set), &set) == -1) {
			perror("set p affinity.\n");
			exit(EXIT_FAILURE);
		}
		// fprintf(stderr, "%d->%d core: %d\n", getppid(), getpid(), sched_getcpu());

		while(1) {
			p = rbf_get_data(rbp);
			if (!p) {
				fprintf(stderr, "read empty.\n");
				sleep(1);
				continue;
			}
			if(memcmp(p, "xxxxx", 5) != 0) {
				fprintf(stderr, "read error data.\n");
			} else {
				fprintf(stderr, "ok\n");
			}
			memset(p, '.', RBF_NODE_SIZE);
			rbf_release_data(rbp);
		}

		wait(NULL);
		exit(EXIT_SUCCESS);
	}

	return 0;
}
