#include <ntrack_log.h>

extern void *nfw_klog_fd;
#define fw_print printk
#ifdef __DEBUG
 #define fw_debug(fmt...)   do{ \
						fw_print("%s: ", __FUNCTION__); \
						fw_print(fmt); \
					} while(0)
#else
 #define fw_debug(fmt...) 	klog_debug(nfw_klog_fd, ##fmt)
#endif
#define fw_info(fmt...) 	klog_info(nfw_klog_fd, ##fmt)
#define fw_warn(fmt...) 	klog_warn(nfw_klog_fd, ##fmt)
#define fw_error(fmt...) 	klog_error(nfw_klog_fd, ##fmt)
