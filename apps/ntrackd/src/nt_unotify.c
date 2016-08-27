#define _GNU_SOURCE

#include "ntrackd.h"

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

int do_nt_unotify(void *buff, int len, int port)
{
	struct msghdr message;
	struct iovec io;
	struct sockaddr_in addr;

	addr.sin_family = AF_INET;
	addr.sin_port = htons(port);
	inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr);

	io.iov_base = buff;
	io.iov_len = len;

	memset(&message, 0, sizeof(message));
	message.msg_iov = &io;
	message.msg_iovlen = 1;
	message.msg_name = &addr;
	message.msg_namelen = sizeof(addr);

	size_t size = sendmsg(sk_fd, &message, 0);
	if (size <= 0 ) {
		nt_error("xmit[%p,%d] failed.\n", buff, len);
		return errno;
	}
	nt_debug("%d bytes xmit.\n", size);
	return 0;
}

int nt_unotify(void *buff, int len)
{
	return do_nt_unotify(buff, len, 50002);
}


int nt_unotify_auth(auth_msg_t *auth, ntrack_t *ntrack)
{
	int len = 0, ret = -1;
	char *buf = trans_authmsg(ntrack, auth, &len);
	if (buf) {
		ret = do_nt_unotify(buf, len, 50002);
		if (ret != 0) {
			nt_error("nt_unotify auth failed: %s\n", strerror(errno));
		}
		free(buf);
	}
	return ret;
}


int nt_unotify_ac(nacs_msg_t *msg)
{
	int len = 0, ret = -1;
	char *buf = trans_aclog(msg, &len);
	if (buf) {
		ret = do_nt_unotify(buf, len, 60000);
		if (ret != 0) {
			nt_error("nt_unotify ac failed: %s\n", strerror(errno));
		}
		free(buf);
	}
	return ret;
}
