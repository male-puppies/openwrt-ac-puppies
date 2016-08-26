#include <ntrack_log.h>

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
#define NP_ASSERT(f) BUG_ON(!(f))