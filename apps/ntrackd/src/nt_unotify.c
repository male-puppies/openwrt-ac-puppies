#define _GNU_SOURCE
#include <sched.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <fcntl.h>
#include <errno.h>

#include <arpa/inet.h>

#include <sys/wait.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/socket.h>

#include <ntrack_rbf.h>
#include <ntrack_log.h>
#include <ntrack_msg.h>
#include <ntrack_auth.h>

static int sk_fd = -1;
int nt_unotify_init(void)
{
	sk_fd = socket(AF_INET, SOCK_DGRAM, 0);
	if(sk_fd < 0) {
		nt_error("socket error: %s\n", strerror(errno));
		exit(-1);
	}
	int bufsize = 1 << 18;
	int ret = setsockopt(sk_fd, SOL_SOCKET, SO_RCVBUF, &bufsize, sizeof(int));
	if (ret < 0) {
		nt_error("set recv buff size failed: %s\n",strerror(errno));
		exit(-1);
	}

	return sk_fd;
}

void nt_unotify_cleanup(void)
{
	if(sk_fd >= 0) {
		close(sk_fd);
		sk_fd = -1;
	}
}

int nt_unotify(void *buff, int len)
{
	struct msghdr message;
	struct iovec io;
	struct sockaddr_in addr_authd;

	addr_authd.sin_family = AF_INET;
	addr_authd.sin_port = htons(50000);
	inet_pton(AF_INET, "127.0.0.1", &addr_authd.sin_addr);

	io.iov_base = buff;
	io.iov_len = len;

	message.msg_iov = &io;
	message.msg_iovlen = 1;
	message.msg_name = &addr_authd;
	message.msg_namelen = sizeof(addr_authd);

	size_t size = sendmsg(sk_fd, &message, 0);
	if (size <= 0 ) {
		nt_error("xmit[%p,%d] failed.\n", buff, len);
		return errno;
	}
	nt_info("%d bytes xmit.\n", size);

	return 0;
}
