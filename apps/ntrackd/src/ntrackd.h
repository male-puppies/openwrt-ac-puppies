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

#include <linux/netlink.h>

#include <pthread.h>

#include <ntrack_rbf.h>
#include <ntrack_log.h>
#include <ntrack_msg.h>
#include <ntrack_auth.h>
#include <ntrack_nacs.h>

int nt_unotify_init(void);
int nt_unotify_ac(nacs_msg_t *msg);
int nt_unotify_auth(auth_msg_t *auth, ntrack_t *ntrack);

char *trans_aclog(nacs_msg_t *msg, int *len);
char *trans_authmsg(ntrack_t *ntrack, auth_msg_t *auth, int *len);