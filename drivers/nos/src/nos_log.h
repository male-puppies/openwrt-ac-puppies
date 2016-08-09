/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Thu, 16 Jun 2016 17:15:56 +0800
 */
#ifndef _NOS_LOG_H_
#define _NOS_LOG_H_

extern const char *const hooknames[];
extern const char *const errornames[];

#include <ntrack_log.h>

extern void *nos_klog_fd;
#ifdef __DEBUG
 #define nt_debug(fmt...) 	do{ \
						nt_print("%s: ", __FUNCTION__); \
						nt_print(fmt); \
					} while(0)
#else
 #define nt_debug(fmt...) 	klog_debug(nos_klog_fd, ##fmt)
#endif
#define nt_info(fmt...) 	klog_info(nos_klog_fd, ##fmt)
#define nt_warn(fmt...) 	klog_warn(nos_klog_fd, ##fmt)
#define nt_error(fmt...) 	klog_error(nos_klog_fd, ##fmt)

#endif /* _NOS_LOG_H_ */
