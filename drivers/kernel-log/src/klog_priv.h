#ifndef _KLOG_PRIV_H__
#define _KLOG_PRIV_H__

int klog_interface_init(void);
void klog_interface_fini(void);

int klog_show_list(char *kbuf, int size);
int klog_set_verbose_by_name(char *name, uint16_t verbose, uint16_t ratelimit);
int klog_set_ratelimit_by_name(char *name, int interval, int burst);

#endif //#ifndef _KLOG_PRIV_H__

