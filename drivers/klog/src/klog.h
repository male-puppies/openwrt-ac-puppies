#ifndef _KLOG_H__
#define _KLOG_H__

void *klog_init(char *name, uint16_t verbose, uint16_t limit_flag);
int klog_fini(void *logfd);

int klog_set_ratelimit(void *logfd, int interval, int burst);
int klog_set_verbose(void *logfd, uint16_t verbose, uint16_t ratelimit, uint32_t how_long);
int klog_get_verbose(void *logfd, uint32_t *cur_verbose, uint32_t *restore_verbose, uint32_t *howlong);

int klog_debug_check(void *logfd);
int klog_info_check(void *logfd);
int klog_warn_check(void *logfd);
int klog_error_check(void *logfd);
int klog_dumpbuf_check(void *logfd);
int klog_trace_check(void *logfd, int level);

void hex_printout(const char *msg, const unsigned char *buf, unsigned int len);

#define klog_debug(logfd, fmt...) \
        do { \
            if(klog_debug_check(logfd)) { \
                printk("[dbug] (%s, %d): ", __FUNCTION__,  __LINE__);  \
                printk(fmt); \
            } \
        } while(0)

#define klog_info(logfd, fmt...) \
        do { \
            if(klog_info_check(logfd)) { \
                printk("[info] (%s, %d): ", __FUNCTION__,  __LINE__);  \
                printk(fmt); \
            } \
        } while(0)

#define klog_warn(logfd, fmt...) \
        do { \
            if(klog_warn_check(logfd)) { \
                printk("[warn] (%s, %d): ", __FUNCTION__,  __LINE__);  \
                printk(fmt); \
            } \
        } while(0)

#define klog_error(logfd, fmt...) \
        do { \
            if(klog_error_check(logfd)) { \
                printk("[erro] (%s, %d): ", __FUNCTION__,  __LINE__);  \
                printk(fmt); \
            } \
        } while(0)

#define klog_dumpbuf(logfd, buf, size, fmt...) \
        do { \
            if(klog_dumpbuf_check(logfd)) { \
                printk("[dump] (%s, %d): ", __FUNCTION__,  __LINE__);  \
                printk(fmt); \
                hex_printout("", buf, size); \
            } \
        } while(0)

#define klog_trace(logfd, level, fmt...) \
        do { \
            if(klog_trace_check(logfd, level)) { \
                printk("[trac] (%s, %d): ", __FUNCTION__,  __LINE__);  \
                printk(fmt); \
            } \
        } while(0)


#endif //#ifndef _KLOG_H__

