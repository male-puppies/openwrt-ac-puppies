/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Mon, 11 Jul 2016 14:35:31 +0800
 */
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

#include <ntrack_rbf.h>
#include <ntrack_log.h>
#include <ntrack_msg.h>
#include <ntrack_auth.h>

static ntrack_t ntrack;

//modules init so
//nt_base_init(&ntrack);


