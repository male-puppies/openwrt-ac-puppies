#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/types.h>

#include <linux/skbuff.h>
#include <linux/list.h>
#include <linux/types.h>

#include "klog_priv.h"


enum klog_verbose_bit {
    KLOG_VERBOSE_DEBUG = 0, //0x1
    KLOG_VERBOSE_INFO = 1,  //0x2
    KLOG_VERBOSE_WARN = 2,  //0x4
    KLOG_VERBOSE_ERROR = 3, //0x8
    KLOG_VERBOSE_DUMPBUF = 4,   //0x10
    KLOG_VERBOSE_TRACE_BASE = 5,   //0x20
    KLOG_VERBOSE_TRACE_1 = 6,   //0x40
    KLOG_VERBOSE_TRACE_2 = 7,   //0x80
    KLOG_VERBOSE_TRACE_3 = 8,   //0x100
    KLOG_VERBOSE_TRACE_4 = 9,   //0x200
    KLOG_VERBOSE_TRACE_5 = 10,  //0x400
    KLOG_VERBOSE_TRACE_6 = 11,  //0x800
    KLOG_VERBOSE_TRACE_7 = 12,  //0x1000
    KLOG_VERBOSE_TRACE_8 = 13,  //0x2000
    KLOG_VERBOSE_TRACE_9 = 14,  //0x4000
    KLOG_VERBOSE_TRACE_10 = 15, //0x8000
    /* no any more */
};
#define verbose_value(bit)  (1<<(bit))
#define limit_value(bit)    (1<<((bit)+16))


struct klog_item {
#define KLOG_ITEM_MAGIC 0x2233abcd
    uint32_t magic;
    uint32_t verbose;
    uint32_t original_verbose;
    spinlock_t lock;
    struct timer_list timer;
    struct ratelimit_state ratelimit;
    struct list_head list;
    char name[32];
};

static struct list_head g_klog_list = LIST_HEAD_INIT(g_klog_list);
static rwlock_t g_klog_lock = __RW_LOCK_UNLOCKED(g_klog_lock);



void hex_printout(const char *msg, const unsigned char *buf, unsigned int len)
{
    static const char hex_char[] = "0123456789ABCDEF";
    const unsigned char *ptr = (const unsigned char*)buf;
    int i, nbytes, j, nlines;
    char msgbuf[120], *dst;

    nlines = ((len + 0x0f) >> 4);
    printk("%s--> addr=%08lx %d bytes\n", msg, (unsigned long)buf, len);

    for (j = 0; j < nlines; j++) {
        nbytes = (len < 16 ? len : 16);

        dst = msgbuf;
        memset(dst, 0x20, 4);
        dst += 4;
        for (i = 0; i < nbytes; i++) {
            unsigned char ival = *ptr++;
            *dst ++ = hex_char[(ival >> 4) & 0x0F];
            *dst ++ = hex_char[ival & 0x0F];
            *dst ++ = ' ';
        }

        memset(dst, 0x20, 3 * (17 - nbytes));
        dst += 3 * (17 - nbytes);

        ptr -= nbytes;
        for (i = 0; i < nbytes; i++) {
            if (*ptr >= 0x20 && *ptr <= 0x7e && *ptr != '%') {
                *dst = *ptr;
            } else {
                *dst = '.';
            }
            ptr++;
            dst++;
        }
        *dst++ = '\n';
        *dst = 0;
        printk("%s", msgbuf);
        len -= nbytes;
    }
}
EXPORT_SYMBOL_GPL(hex_printout);


static void restore_verbose(unsigned long data)
{
    struct klog_item *item = (struct klog_item *)data;
    spin_lock_bh(&item->lock);
    item->verbose = item->original_verbose;
    item->original_verbose = 0;
    spin_unlock_bh(&item->lock);
}

inline void __clear_item_timer(struct klog_item *item)
{
    del_timer(&item->timer);
    item->original_verbose = 0;
}

inline void __set_item_verbose(struct klog_item *item, uint16_t verbose, uint16_t limit)
{
    item->verbose = (limit << 16) | verbose;
}

int klog_show_list(char *kbuf, int size)
{
    struct klog_item *item;
    int len = 0;

    len += snprintf(kbuf + len, size - len,
                    "klog list:\n"
                    "%*s %*s %*s %*s %*s %*s %*s %*s\n",
                    16, "name",
                    8, "verbose",
                    8, "rate",
                    8, "intv",
                    8, "burst",
                    8, "rst_vb",
                    8, "rst_rl",
                    8, "expir"
                   );

    read_lock_bh(&g_klog_lock);
    list_for_each_entry(item, &g_klog_list, list) {
        len += snprintf(kbuf + len, size - len,
                        "%*s 0x%-*x 0x%-*x %-*d %-*d 0x%-*x 0x%-*x %-*lu\n",
                        16, item->name,
                        8, item->verbose & 0xff,
                        8, item->verbose >> 16,
                        8, item->ratelimit.interval / HZ,
                        8, item->ratelimit.burst,
                        8, item->original_verbose & 0xff,
                        8, item->original_verbose >> 16,
                        8, (item->timer.expires - jiffies) / HZ);
    }
    read_unlock_bh(&g_klog_lock);
    return len;
}

int klog_set_verbose_by_name(char *name, uint16_t verbose, uint16_t ratelimit)
{
    struct klog_item *item;
    int ret = 0;

    read_lock_bh(&g_klog_lock);
    list_for_each_entry(item, &g_klog_list, list) {
        if(!strcmp(item->name, name)) {
            spin_lock_bh(&item->lock);
            __clear_item_timer(item);
            __set_item_verbose(item, verbose, ratelimit);
            spin_unlock_bh(&item->lock);
            ret++;
        }
    }
    read_unlock_bh(&g_klog_lock);
    return ret == 0 ? -1 : ret;
}

int klog_set_ratelimit_by_name(char *name, int interval, int burst)
{
    struct klog_item *item;
    int ret = 0;

    read_lock_bh(&g_klog_lock);
    list_for_each_entry(item, &g_klog_list, list) {
        if(!strcmp(item->name, name)) {
            spin_lock_bh(&item->lock);
            item->ratelimit.interval = interval;
            item->ratelimit.burst = burst;
            spin_unlock_bh(&item->lock);
            ret++;
        }
    }
    read_unlock_bh(&g_klog_lock);
    return ret == 0 ? -1 : ret;
}

void *klog_init(char *name, uint16_t verbose, uint16_t limit_flag)
{
    struct klog_item *item = kmalloc(sizeof(struct klog_item), GFP_KERNEL);
    if(!item) {
        return NULL;
    }

    item->magic = KLOG_ITEM_MAGIC;
    __set_item_verbose(item, verbose, limit_flag);
    if(name) {
        snprintf(item->name, sizeof(item->name), "%s", name);
    } else {
        snprintf(item->name, sizeof(item->name), "%s", "undefined");
    }
    spin_lock_init(&item->lock);
    ratelimit_state_init(&item->ratelimit, 10 * HZ, 5);
    init_timer(&item->timer);
    item->timer.data = (unsigned long)item;
    item->timer.function = restore_verbose;

    write_lock_bh(&g_klog_lock);
    list_add(&item->list, &g_klog_list);
    write_unlock_bh(&g_klog_lock);
    return item;
}
EXPORT_SYMBOL_GPL(klog_init);


int klog_fini(void *logfd)
{
    struct klog_item *item;

    item = (struct klog_item *)logfd;
    if(item->magic != KLOG_ITEM_MAGIC) {
        printk("not a logfd\n");
        return -1;
    }

    write_lock_bh(&g_klog_lock);
    list_del(&item->list);
    write_unlock_bh(&g_klog_lock);
    kfree(item);
    return 0;
}
EXPORT_SYMBOL_GPL(klog_fini);

inline int klog_ratelimit(struct klog_item *item)
{
    return __ratelimit(&item->ratelimit);
}

int klog_set_ratelimit(void *logfd, int interval, int burst)
{
    struct klog_item *item;

    item = (struct klog_item *)logfd;
    if(item->magic != KLOG_ITEM_MAGIC) {
        printk("not a logfd\n");
        return -1;
    }

    spin_lock_bh(&item->lock);
    item->ratelimit.interval = interval * HZ;
    item->ratelimit.burst = burst;
    spin_unlock_bh(&item->lock);
    return 0;
}
EXPORT_SYMBOL_GPL(klog_set_ratelimit);


int klog_set_verbose(void *logfd, uint16_t verbose, uint16_t ratelimit, uint32_t how_long)
{
    struct klog_item *item;

    item = (struct klog_item *)logfd;
    if(item->magic != KLOG_ITEM_MAGIC) {
        printk("not a logfd\n");
        return -1;
    }

    if(how_long == 0) {
        return 0;
    }

    if(how_long != (uint32_t) - 1) {
        spin_lock_bh(&item->lock);
        del_timer(&item->timer);
        if(item->original_verbose == 0) {
            item->original_verbose = item->verbose;
        }
        __set_item_verbose(item, verbose, ratelimit);
        mod_timer(&item->timer, jiffies + how_long * HZ);
        spin_unlock_bh(&item->lock);

    } else {
        spin_lock_bh(&item->lock);
        __clear_item_timer(item);
        __set_item_verbose(item, verbose, ratelimit);
        spin_unlock_bh(&item->lock);
    }
    return 0;
}
EXPORT_SYMBOL_GPL(klog_set_verbose);


int klog_get_verbose(void *logfd, uint32_t *cur_verbose, uint32_t *restore_verbose, uint32_t *howlong)
{
    struct klog_item *item;

    item = (struct klog_item *)logfd;
    if(item->magic != KLOG_ITEM_MAGIC) {
        return -1;
    }

    *cur_verbose = item->verbose;
    *restore_verbose = item->original_verbose;
    *howlong = (item->timer.expires - jiffies) / HZ;
    return 0;
}
EXPORT_SYMBOL_GPL(klog_get_verbose);



inline int klog_verbose_check(void *logfd, enum klog_verbose_bit bit)
{
    struct klog_item *item;

    item = (struct klog_item *)logfd;
    if(item->verbose & verbose_value(bit)) {
        if(!(item->verbose & limit_value(bit))
                || klog_ratelimit(item)) {
            return 1;
        }
    }
    return 0;
}

int klog_debug_check(void *logfd)
{
    return klog_verbose_check(logfd, KLOG_VERBOSE_DEBUG);
}
EXPORT_SYMBOL_GPL(klog_debug_check);

int klog_info_check(void *logfd)
{
    return klog_verbose_check(logfd, KLOG_VERBOSE_INFO);
}
EXPORT_SYMBOL_GPL(klog_info_check);

int klog_warn_check(void *logfd)
{
    return klog_verbose_check(logfd, KLOG_VERBOSE_WARN);
}
EXPORT_SYMBOL_GPL(klog_warn_check);

int klog_error_check(void *logfd)
{
    return klog_verbose_check(logfd, KLOG_VERBOSE_ERROR);
}
EXPORT_SYMBOL_GPL(klog_error_check);

int klog_dumpbuf_check(void *logfd)
{
    return klog_verbose_check(logfd, KLOG_VERBOSE_DUMPBUF);
}
EXPORT_SYMBOL_GPL(klog_dumpbuf_check);

int klog_trace_check(void *logfd, int level)
{
    return klog_verbose_check(logfd, KLOG_VERBOSE_TRACE_BASE + level);
}
EXPORT_SYMBOL_GPL(klog_trace_check);


int klog_module_init(void)
{
    return klog_interface_init();
}

void klog_module_fini(void)
{
    klog_interface_fini();
}

module_init(klog_module_init);
module_exit(klog_module_fini);
MODULE_LICENSE("GPL");
MODULE_AUTHOR("js@stt.com.cn");


