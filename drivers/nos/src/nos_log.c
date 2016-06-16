/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Thu, 16 Jun 2016 17:15:56 +0800
 */
#include <linux/netfilter.h>
#include "nos_log.h"

const char *const hooknames[] = { 
	[NF_INET_PRE_ROUTING] = "PREROUTING",
	[NF_INET_LOCAL_IN] = "INPUT",
	[NF_INET_FORWARD] = "FORWARD",
	[NF_INET_LOCAL_OUT] = "OUTPUT",
	[NF_INET_POST_ROUTING] = "POSTROUTING",
};

const char *const errornames[] = {
	[EPERM] = "EPERM",
	[ENOENT] = "ENOENT",
	[ESRCH] = "ESRCH",
	[EINTR] = "EINTR",
	[EIO] = "EIO",
	[ENXIO] = "ENXIO",
	[E2BIG] = "E2BIG",
	[ENOEXEC] = "ENOEXEC",
	[EBADF] = "EBADF",
	[ECHILD] = "ECHILD",
	[EAGAIN] = "EAGAIN",
	[ENOMEM] = "ENOMEM",
	[EACCES] = "EACCES",
	[EFAULT] = "EFAULT",
	[ENOTBLK] = "ENOTBLK",
	[EBUSY] = "EBUSY",
	[EEXIST] = "EEXIST",
	[EXDEV] = "EXDEV",
	[ENODEV] = "ENODEV",
	[ENOTDIR] = "ENOTDIR",
	[EISDIR] = "EISDIR",
	[EINVAL] = "EINVAL",
	[ENFILE] = "ENFILE",
	[EMFILE] = "EMFILE",
	[ENOTTY] = "ENOTTY",
	[ETXTBSY] = "ETXTBSY",
	[EFBIG] = "EFBIG",
	[ENOSPC] = "ENOSPC",
	[ESPIPE] = "ESPIPE",
	[EROFS] = "EROFS",
	[EMLINK] = "EMLINK",
	[EPIPE] = "EPIPE",
	[EDOM] = "EDOM",
	[ERANGE] = "ERANGE",
};
