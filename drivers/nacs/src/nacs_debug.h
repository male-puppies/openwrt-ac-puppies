#ifndef _NACS_DEBUG_H
#define _NACS_DEBUG_H
#include <ntrack_log.h>
extern void *nfw_klog_fd;
#ifdef __DEBUG
#define NACS_DEBUG(fmt,...)   do {printk(KERN_DEBUG fmt, ##__VA_ARGS__); } while(0)
#else
#define NACS_DEBUG(fmt...) klog_debug(nfw_klog_fd, ##fmt)
#endif

#define NAC_PRINT_DEBUG(fmt,...)   do {printk(KERN_DEBUG fmt, ##__VA_ARGS__); } while(0)
#define NACS_INFO(fmt...) 	klog_info(nfw_klog_fd, ##fmt)
#define NACS_WARN(fmt...) 	klog_warn(nfw_klog_fd, ##fmt)
#define NACS_ERROR(fmt...) 	klog_error(nfw_klog_fd, ##fmt)
#endif