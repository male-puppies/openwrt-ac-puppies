/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Thu, 16 Jun 2016 10:32:40 +0800
 */
#include <linux/ctype.h>
#include <linux/cdev.h>
#include <linux/device.h>
#include <linux/fs.h>
#include <linux/seq_file.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/mm.h>
#include <linux/vmalloc.h>
#include <linux/module.h>
#include <linux/netdevice.h>
#include <linux/string.h>
#include <linux/syscalls.h>
#include <linux/uaccess.h>
#include <linux/unistd.h>
#include <linux/version.h>
#include <linux/mman.h>
#include <linux/spinlock.h>
#include <linux/rcupdate.h>
#include <linux/highmem.h>
#include <ntrack_comm.h>
#include "nos.h"
#include "nos_ipgrp.h"

static int nos_ipgrp_major = 0;
static int nos_ipgrp_minor = 0;
static int number_of_devices = 1;
static struct cdev nos_ipgrp_cdev;
const char *nos_ipgrp_dev_name = "nos_ipgrp_ctl";
static struct class *nos_ipgrp_class;
static struct device *nos_ipgrp_dev;

static struct ipgrp_conf ipgrp_conf;
static inline void ipgrp_conf_init(void)
{
	memset(&ipgrp_conf, 0, sizeof(ipgrp_conf));
}

static inline void nos_ipgrp_cleanup(void)
{
	int i;
	nos_hook_disable = 1;
	synchronize_rcu();
	for (i = 0; i < ipgrp_conf.num; i++)
	{
		if (ipgrp_conf.ipgrp[i].ipset_set) {
			//it's not @all ipgrp
			ip_set_put_byindex(&init_net, ipgrp_conf.ipgrp[i].ipset_id);
		}
	}
	memset(&ipgrp_conf, 0, sizeof(ipgrp_conf));
	nos_hook_disable = 0;
}

static inline void ipgrp_conf_exit(void)
{
	nos_ipgrp_cleanup();
}

static inline int nos_ipgrp_set(const struct ip_grp_t *ipgrp)
{
	int i;

	if (ipgrp->id >= MAX_IPGRP)
		return -EINVAL;

	for (i = 0; i < ipgrp_conf.num; i++)
	{
		if (ipgrp_conf.ipgrp[i].id == ipgrp->id)
			return -EEXIST;
	}
	if (ipgrp_conf.num == MAX_IPGRP)
		return -ENOSPC;

	nos_hook_disable = 1;
	synchronize_rcu();
	i = ipgrp_conf.num;
	memcpy(&ipgrp_conf.ipgrp[i], ipgrp, sizeof(struct ip_grp_t));
	ipgrp_conf.num = i + 1;
	nos_hook_disable = 0;

	return 0;
}

static inline int nos_ipgrp_delete(const struct ip_grp_t *ipgrp)
{
	int i;
	for (i = 0; i < ipgrp_conf.num; i++)
	{
		if (ipgrp_conf.ipgrp[i].id == ipgrp->id) {
			nos_hook_disable = 1;
			synchronize_rcu();
			if (ipgrp_conf.ipgrp[i].ipset_set) {
				//it's not @all ipgrp
				ip_set_put_byindex(&init_net, ipgrp_conf.ipgrp[i].ipset_id);
			}
			if (i + 1 < ipgrp_conf.num) {
				memmove(&ipgrp_conf.ipgrp[i], &ipgrp_conf.ipgrp[i+1], sizeof(struct ip_grp_t) * (ipgrp_conf.num - 1 - i));
			}
			ipgrp_conf.num = ipgrp_conf.num - 1;
			nos_hook_disable = 0;
			return 0;
		}
	}

	return -ENOENT;
}

uint64_t nos_ipgrp_match_src(const struct net_device *in, const struct net_device *out, struct sk_buff *skb)
{
	int i;
	unsigned long bits = 0;

	for (i = 0; i < ipgrp_conf.num; i++)
	{
		if (ipgrp_conf.ipgrp[i].ipset_set == NULL) //ipgrp is @all
			bits |= (1 << ipgrp_conf.ipgrp[i].id);
		else if (ip_set_test_src_ip(in, out, skb, ipgrp_conf.ipgrp[i].ipset_id) > 0)
			bits |= (1 << ipgrp_conf.ipgrp[i].id);
	}

	return bits;
}

uint64_t nos_ipgrp_match_dst(const struct net_device *in, const struct net_device *out, struct sk_buff *skb)
{
	int i;
	unsigned long bits = 0;

	for (i = 0; i < ipgrp_conf.num; i++)
	{
		if (ipgrp_conf.ipgrp[i].ipset_set == NULL) //ipgrp is @all
			bits |= (1 << ipgrp_conf.ipgrp[i].id);
		else if (ip_set_test_dst_ip(in, out, skb, ipgrp_conf.ipgrp[i].ipset_id) > 0)
			bits |= (1 << ipgrp_conf.ipgrp[i].id);
	}

	return bits;
}

void *nos_ipgrp_get(loff_t idx)
{
	if (idx < ipgrp_conf.num)
		return &ipgrp_conf.ipgrp[idx];
	return NULL;
}

static char nos_ipgrp_ctl_buffer[PAGE_SIZE];
static void *nos_ipgrp_start(struct seq_file *m, loff_t *pos)
{
	int n = 0;

	if ((*pos) == 0) {
		n = snprintf(nos_ipgrp_ctl_buffer,
				sizeof(nos_ipgrp_ctl_buffer) - 1,
				"# Usage:\n"
				"#    ipgrp <id>=<ipset_name> -- set one ipgrp\n"
				"#    ipgrp <id>=@all -- set all range 0.0.0.0~255.255.255.255\n"
				"#    delete <id> -- delete one ipgrp\n"
				"#    clean -- remove all existing ipgrp(s)\n"
				"#\n"
				"# Info: "
				"#  VALID IPGRP ID RANGE: 0~%u\n"
				"#  MAX IPGRP: %u\n"
				"#\n"
				"# Reload cmd:\n"
				"\n"
				"clean\n"
				"\n",
				MAX_IPGRP - 1, MAX_IPGRP);
		nos_ipgrp_ctl_buffer[n] = 0;
		return nos_ipgrp_ctl_buffer;
	} else if ((*pos) > 0) {
		struct ip_grp_t *ipgrp = (struct ip_grp_t *)nos_ipgrp_get((*pos) - 1);

		if (ipgrp) {
			n = snprintf(nos_ipgrp_ctl_buffer,
					sizeof(nos_ipgrp_ctl_buffer) - 1,
					"ipgrp %u=%s\n",
					ipgrp->id, ipgrp->ipset_set == NULL? "@all" : ip_set_name_byindex(&init_net, ipgrp->ipset_id));
			nos_ipgrp_ctl_buffer[n] = 0;
			return nos_ipgrp_ctl_buffer;
		}
	}

	return NULL;
}

static void *nos_ipgrp_next(struct seq_file *m, void *v, loff_t *pos)
{
	int n;

	(*pos)++;
	if ((*pos) > 0) {
		struct ip_grp_t *ipgrp = (struct ip_grp_t *)nos_ipgrp_get((*pos) - 1);

		if (ipgrp) {
			n = snprintf(nos_ipgrp_ctl_buffer,
					sizeof(nos_ipgrp_ctl_buffer) - 1,
					"ipgrp %u=%s\n",
					ipgrp->id, ipgrp->ipset_set == NULL? "@all" : ip_set_name_byindex(&init_net, ipgrp->ipset_id));
			nos_ipgrp_ctl_buffer[n] = 0;
			return nos_ipgrp_ctl_buffer;
		}
	}
	return NULL;
}

static void nos_ipgrp_stop(struct seq_file *m, void *v)
{
}

static int nos_ipgrp_show(struct seq_file *m, void *v)
{
	seq_printf(m, "%s", (char *)v);
	return 0;
}

const struct seq_operations nos_ipgrp_seq_ops = {
	.start = nos_ipgrp_start,
	.next = nos_ipgrp_next,
	.stop = nos_ipgrp_stop,
	.show = nos_ipgrp_show,
};

static ssize_t nos_ipgrp_read(struct file *file, char __user *buf, size_t buf_len, loff_t *offset)
{
	return seq_read(file, buf, buf_len, offset);
}

static ssize_t nos_ipgrp_write(struct file *file, const char __user *buf, size_t buf_len, loff_t *offset)
{
	int err = 0;
	int n, l;
	int cnt = 256;
	struct ip_grp_t ipgrp;
	static char data[256];
	static int data_left = 0;

	cnt -= data_left;
	if (buf_len < cnt)
		cnt = buf_len;

	if (copy_from_user(data + data_left, buf, cnt) != 0)
		return -EACCES;

	n = 0;
	while(n < cnt && (data[n] == ' ' || data[n] == '\n' || data[n] == '\t')) n++;
	if (n) {
		*offset += n;
		data_left = 0;
		return n;
	}

	//make sure line ended with '\n' and line len <=256
	l = 0;
	while (l < cnt && data[l + data_left] != '\n') l++;
	if (l >= cnt) {
		data_left += l;
		if (data_left >= 256) {
			printk("err: too long a line\n");
			data_left = 0;
			return -EINVAL;
		}
		goto done;
	} else {
		data[l + data_left] = '\0';
		data_left = 0;
		l++;
	}

	if (strncmp(data, "clean", 5) == 0) {
		nos_ipgrp_cleanup();
		goto done;
	} else if (strncmp(data, "ipgrp ", 6) == 0) {
		char buf[256] = {0};
		n = sscanf(data, "ipgrp %u=%s\n", &ipgrp.id, buf);
		if (n == 2) {
			ip_set_id_t id;
			struct ip_set *set;
			if (strcmp("@all", buf) == 0) {
				ipgrp.ipset_id = IPSET_INVALID_ID;
				ipgrp.ipset_set = NULL;
				if ((err = nos_ipgrp_set(&ipgrp)) == 0)
					goto done;
			} else {
				id = ip_set_get_byname(&init_net, buf, &set);
				if (id != IPSET_INVALID_ID) {
					ipgrp.ipset_id = id;
					ipgrp.ipset_set = set;
					if ((err = nos_ipgrp_set(&ipgrp)) == 0)
						goto done;
					else
						ip_set_put_byindex(&init_net, ipgrp.ipset_id);
				} else {
					printk("ip_set '%s' not found\n", buf);
					err = -EINVAL;
				}
			}
			printk("nos_ipgrp_set() failed ret=%d\n", err);
		}
	} else if (strncmp(data, "delete ", 7) == 0) {
		n = sscanf(data, "delete %u\n", &ipgrp.id);
		if (n == 1) {
			if ((err = nos_ipgrp_delete(&ipgrp)) == 0)
				goto done;
			printk("nos_ipgrp_delete() failed ret=%d\n", err);
		}
	}

	printk("ignoring line[%s]\n", data);
	if (err != 0) {
		return err;
	}

done:
	*offset += l;
	return l;
}

static int nos_ipgrp_open(struct inode *inode, struct file *file)
{
	int ret = seq_open(file, &nos_ipgrp_seq_ops);
	if (ret)
		return ret;
	//set nonseekable
	file->f_mode &= ~(FMODE_LSEEK | FMODE_PREAD | FMODE_PWRITE);

	return 0;
}

static int nos_ipgrp_release(struct inode *inode, struct file *file)
{
	return seq_release(inode, file);
}

static struct file_operations nos_ipgrp_fops = {
	.owner = THIS_MODULE,
	.open = nos_ipgrp_open,
	.release = nos_ipgrp_release,
	.read = nos_ipgrp_read,
	.write = nos_ipgrp_write,
	.llseek  = seq_lseek,
};

int nos_ipgrp_init(void)
{
	int retval = 0;
	dev_t devno;

	if (nos_ipgrp_major>0) {
		devno = MKDEV(nos_ipgrp_major, nos_ipgrp_minor);
		retval = register_chrdev_region(devno, number_of_devices, nos_ipgrp_dev_name);
	} else {
		retval = alloc_chrdev_region(&devno, nos_ipgrp_minor, number_of_devices, nos_ipgrp_dev_name);
	}
	if (retval < 0) {
		printk("alloc_chrdev_region failed!\n");
		return retval;
	}
	nos_ipgrp_major = MAJOR(devno);
	nos_ipgrp_minor = MINOR(devno);
	printk("nos_ipgrp_major=%d, nos_ipgrp_minor=%d\n", nos_ipgrp_major, nos_ipgrp_minor);

	cdev_init(&nos_ipgrp_cdev, &nos_ipgrp_fops);
	nos_ipgrp_cdev.owner = THIS_MODULE;
	nos_ipgrp_cdev.ops = &nos_ipgrp_fops;

	retval = cdev_add(&nos_ipgrp_cdev, devno, 1);
	if (retval) {
		printk("adding chardev, error=%d\n", retval);
		goto cdev_add_failed;
	}

	nos_ipgrp_class = class_create(THIS_MODULE,"nos_ipgrp_class");
	if (IS_ERR(nos_ipgrp_class)) {
		printk("failed in creating class\n");
		retval = -EINVAL;
		goto class_create_failed;
	}

	nos_ipgrp_dev = device_create(nos_ipgrp_class, NULL, devno, NULL, nos_ipgrp_dev_name);
	if (!nos_ipgrp_dev) {
		retval = -EINVAL;
		goto device_create_failed;
	}

	ipgrp_conf_init();

	return 0;

	//device_destroy(nos_ipgrp_class, devno);
device_create_failed:
	class_destroy(nos_ipgrp_class);
class_create_failed:
	cdev_del(&nos_ipgrp_cdev);
cdev_add_failed:
	unregister_chrdev_region(devno, number_of_devices);

	return retval;
}

void nos_ipgrp_exit(void)
{
	dev_t devno;

	ipgrp_conf_exit();

	devno = MKDEV(nos_ipgrp_major, nos_ipgrp_minor);
	device_destroy(nos_ipgrp_class, devno);
	class_destroy(nos_ipgrp_class);
	cdev_del(&nos_ipgrp_cdev);
	unregister_chrdev_region(devno, number_of_devices);
	return;
}
