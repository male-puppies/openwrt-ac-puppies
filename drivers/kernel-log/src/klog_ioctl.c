#include <linux/fs.h>
#include <linux/proc_fs.h>
#include <linux/mm.h>
#include <linux/types.h>
#include <asm/uaccess.h>

#include "klog_priv.h"

static int klog_open(struct inode *inode, struct file *file);
static int klog_release(struct inode *inode, struct file *file);
static long klog_ioctl(struct file *file, unsigned int cmd, unsigned long data);
static ssize_t klog_write(struct file *file, const char __user *buf, size_t count, loff_t *off);
static ssize_t klog_read(struct file *filp, char *buf, size_t count, loff_t *off);



static struct proc_dir_entry *proc_klog;
static struct file_operations klog_fops = {
    .unlocked_ioctl = klog_ioctl,
    .open = klog_open,
    .release = klog_release,
    .read = klog_read,
    .write = klog_write,
};


int klog_open(struct inode *inode, struct file *file)
{
    return 0;
}


int klog_release(struct inode *inode, struct file *file)
{
    return 0;
}

ssize_t klog_write(struct file *file, const char __user *buf, size_t count, loff_t *off)
{
    char kbuf[512] = {0};
    char *ptr;
    int cnt;

    if(count >= sizeof(kbuf)) {
        printk("write too many data, cut it off to len: %d\n", (int)sizeof(kbuf) - 1);
        cnt = sizeof(kbuf) - 1;
    } else {
        cnt = count;
    }

    if(copy_from_user(kbuf, buf, cnt)) {
        printk("copy from user failed\n");
        return -EPERM;
    }

    ptr = strim(kbuf);

#define const_str_size(str) (sizeof(str)-1)
    if(!strncmp(ptr, "set_verbose", const_str_size("set_verbose"))) {
        char name[32] = {0};
        uint16_t verbose = 0, limit = 0;

        if(sscanf(ptr, "set_verbose %s %hx %hx", name, &verbose, &limit) != 3) {
            return -EINVAL;
        }
        klog_set_verbose_by_name(name, verbose, limit);
    } else if(!strncmp(ptr, "set_ratelimit", const_str_size("set_ratelimit"))) {
        char name[32] = {0};
        int interval = 0, burst = 0;

        if(sscanf(ptr, "set_ratelimit %s %x %x", name, &interval, &burst) != 3) {
            return -EINVAL;
        }
        klog_set_ratelimit_by_name(name, interval, burst);
    }

    return count;
}

ssize_t klog_read(struct file *filp, char *buf, size_t count, loff_t *off)
{
    int len = 0;
    if (*off != 0) {
        return 0;
    }
    len += klog_show_list(buf + len, count - len);
    len += snprintf(buf + len, count - len,
                    "\n"
                    "Command: \n"
                    "   set_verbose   name  verbose   ratelimit\n"
                    "       --- set `verbose` with `ratelimit` on every bits\n"
                    "           verbose(0~0xFF): 0x1->DEBUG, 0x2->INFO, 0x4->WARN, 0x8->ERROR, 0x10->DUMPBUF, 0x40~0x8000->TRACE-1~TRACE-10\n"
                    "           ratelimit(0~0xFF): open limit on `verbose`\n"
                    "   set_ratelimit name  interval  burst\n"
                    "       --- max `burst` in one `interval`\n"
                   );

    *off += len;
    return len;
}

long klog_ioctl(struct file *file, unsigned int cmd, unsigned long data)
{
    switch(cmd) {
        default:
            return -EPERM;
    }
    return 0;
}


int klog_interface_init(void)
{
    proc_klog = proc_create("klog", S_IRUSR | S_IWUSR, NULL, &klog_fops);
    if(!proc_klog) {
        printk("create /proc/klog entry failed\n");
        remove_proc_entry("klog", NULL);
        return -1;
    }

    printk("klog_interface_init over...\n");

    return 0;
}

void klog_interface_fini(void)
{
    remove_proc_entry("klog", NULL);

    printk("klog_interface_fini over...\n");
}

