#ifndef __NTRACK_LOGS_H__

//common defs
#define NIPQUAD(addr) \
	((unsigned char *)&addr)[0], \
	((unsigned char *)&addr)[1], \
	((unsigned char *)&addr)[2], \
	((unsigned char *)&addr)[3]

#define HIPQUAD(addr) \
	((unsigned char *)&addr)[3], \
	((unsigned char *)&addr)[2], \
	((unsigned char *)&addr)[1], \
	((unsigned char *)&addr)[0]
	
#define FMT_USER_STR "uid:%08u magic:%08u gid:%04d ucrc:%010u status:%03d szone:%03d sipgrp:x%016llx ref:%04u - %u.%u.%u.%u"
#define FMT_USER(ui) \
			(ui)->id, (ui)->magic, \
			(ui)->hdr.u_grp_id, (ui)->hdr.u_usr_crc, \
			(ui)->hdr.status, \
			(ui)->hdr.src_zone_id, (ui)->hdr.src_ipgrp_bits, \
			(ui)->refcnt, \
			NIPQUAD((ui)->ip)

#define FMT_MAC_STR "%02x:%02x:%02x:%02x:%02x:%02x"
#define FMT_MAC(m)  (unsigned char)m[0],(unsigned char)m[1],(unsigned char)m[2],\
			(unsigned char)m[3],(unsigned char)m[4],(unsigned char)m[5]

#ifdef __KERNEL__
#include <linux/kernel.h>
#include <linux/module.h>

#include <linux/klog.h>

extern void *ntrack_klog_fd;
#define nt_print printk
#ifdef __DEBUG
 #define nt_debug(fmt...) 	do{ \
						nt_print("%s: ", __FUNCTION__); \
						nt_print(fmt); \
					} while(0)
#else
 #define nt_debug(fmt...) 	klog_debug(ntrack_klog_fd, ##fmt)
#endif
#define nt_info(fmt...) 	klog_info(ntrack_klog_fd, ##fmt)
#define nt_warn(fmt...) 	klog_warn(ntrack_klog_fd, ##fmt)
#define nt_error(fmt...) 	klog_error(ntrack_klog_fd, ##fmt)
#define nt_dump(buf, size, fmt, args...) 	klog_dumpbuf(ntrack_klog_fd, buf, size, fmt, ##args)
#define nt_trace(level, fmt...) 	klog_trace(ntrack_klog_fd, level, ##fmt)
#define nt_assert(x, fmt...) 	BUG_ON(!(x))

extern void *nproto_klog_fd;
#define np_print printk
#ifdef __DEBUG
 #define np_debug(fmt...)   do{ \
						np_print("%s: ", __FUNCTION__); \
						np_print(fmt); \
					} while(0)
#else
 #define np_debug(fmt...) 	klog_debug(nproto_klog_fd, ##fmt)
#endif
#define np_info(fmt...) 	klog_info(nproto_klog_fd, ##fmt)
#define np_warn(fmt...) 	klog_warn(nproto_klog_fd, ##fmt)
#define np_error(fmt...) 	klog_error(nproto_klog_fd, ##fmt)
#define np_dump(buf, size, fmt, args...) 	klog_dumpbuf(nproto_klog_fd, buf, size, fmt, ##args)
#define np_trace(level, fmt...) 	klog_trace(nproto_klog_fd, level, ##fmt)

#else /* end kernel */

#define _GNU_SOURCE
#include <sched.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <fcntl.h>
#include <assert.h>

#include <sys/types.h>

#define nt_print printf
void hexdump(FILE *fp, const void *data, int size);

#ifdef __DEBUG
#define nt_debug(fmt...) 	do{ \
		fprintf(stderr, "[dbg] %s: ", __FUNCTION__); \
		fprintf(stderr, ##fmt); \
	}while(0)
#else
#define nt_debug(fmt...) do{}while(0)
#endif

#define nt_info(fmt...) 	do{ \
		fprintf(stderr, "[inf] %s: ", __FUNCTION__); \
		fprintf(stderr, ##fmt); \
	}while(0)

#define nt_warn(fmt...) 	do{ \
		fprintf(stderr, "[war] %s: ", __FUNCTION__); \
		fprintf(stderr, ##fmt); \
	}while(0)

#define nt_error(fmt...) 	do{ \
		fprintf(stderr, "[err] %s: ", __FUNCTION__); \
		fprintf(stderr, ##fmt); \
	}while(0)

#define nt_dump(buf, size, fmt...) 	do { \
		fprintf(stderr, "[dump] %s: ", __FUNCTION__); \
		fprintf(stderr, ##fmt); \
		hexdump(stderr, buf, size); \
	} while(0)

#define nt_assert(exp, fmt...) assert(exp)

#endif /* __KERNEL__ */

/* debug macro's */
/* Force a compilation error if condition is false, but also produce a result
 * (of value 0 and type size_t), so it can be used e.g. in a structure
 * initializer (or wherever else comma expressions aren't permitted). 
 */
/* Linux calls these BUILD_BUG_ON_ZERO/_NULL, which is rather misleading. */

#define STATIC_ZERO_ASSERT(condition) (sizeof(struct { int:-!(condition); }))
#define STATIC_NULL_ASSERT(condition) ((void *)STATIC_ZERO_ASSERT(condition))

/* Force a compilation error if condition is false */
#define STATIC_ASSERT(condition) ((void)STATIC_ZERO_ASSERT(condition))

#endif //__NTRACK_LOGS_H__
