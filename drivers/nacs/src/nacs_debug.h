#ifndef _NACS_DEBUG_H
#define _NACS_DEBUG_H
#include <ntrack_log.h>
extern void *nacs_klog_fd;

#define NAC_PRINT_DEBUG(fmt,...)   do {printk(KERN_DEBUG fmt, ##__VA_ARGS__); } while(0)
#define NACS_DEBUG(fmt...) 	klog_debug(nacs_klog_fd, ##fmt)
#define NACS_INFO(fmt...) 	klog_info(nacs_klog_fd, ##fmt)
#define NACS_WARN(fmt...) 	klog_warn(nacs_klog_fd, ##fmt)
#define NACS_ERROR(fmt...) 	klog_error(nacs_klog_fd, ##fmt)
#endif