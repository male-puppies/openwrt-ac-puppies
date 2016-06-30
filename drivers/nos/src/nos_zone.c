/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Wed, 15 Jun 2016 18:31:41 +0800
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
#include "nos_zone.h"

static int nos_zone_major = 0;
static int nos_zone_minor = 0;
static int number_of_devices = 1;
static struct cdev nos_zone_cdev;
const char *nos_zone_dev_name = "nos_zone_ctl";
static struct class *nos_zone_class;
static struct device *nos_zone_dev;

static unsigned int if_zone_map[MAX_IF_INDEX];
static inline void zone_conf_init(void)
{
	int i;
	for (i = 0; i < MAX_IF_INDEX; i++) {
		if_zone_map[i] = INVALID_ZONE_ID;
	}
}

static inline void nos_zone_cleanup(void)
{
	int i;
	nos_hook_disable = 1;
	synchronize_rcu();
	for (i = 0; i < MAX_IF_INDEX; i++) {
		if_zone_map[i] = INVALID_ZONE_ID;
	}
	nos_hook_disable = 0;
}

static inline void zone_conf_exit(void)
{
	nos_zone_cleanup();
}

static inline int nos_zone_set(const struct zone_t *zone)
{
	struct net_device *dev;

	if (zone->id >= INVALID_ZONE_ID)
		return -EINVAL;
	dev = dev_get_by_name(&init_net, zone->if_name);
	if (dev == NULL)
		return -EINVAL;
	if (dev->ifindex >= MAX_IF_INDEX) {
		dev_put(dev);
		return -EINVAL;
	}
	nos_hook_disable = 1;
	synchronize_rcu();
	if_zone_map[dev->ifindex] = zone->id;
	nos_hook_disable = 0;
	dev_put(dev);

	return 0;
}

static inline int nos_zone_delete(const struct zone_t *zone)
{
	int i;
	int found = 0;

	nos_hook_disable = 1;
	synchronize_rcu();
	for (i = 0; i < MAX_IF_INDEX; i++)
	{
		if (if_zone_map[i] == zone->id) {
			if_zone_map[i] = INVALID_ZONE_ID;
			found = 1;
		}
	}
	nos_hook_disable = 0;

	if (found == 0)
		return -ENOENT;
	return 0;
}

/* @return dev zone id */
unsigned int nos_zone_match(const struct net_device *dev)
{
	if (dev->ifindex < MAX_IF_INDEX)
		return if_zone_map[dev->ifindex];

	return INVALID_ZONE_ID;
}

void *nos_zone_get(loff_t idx)
{
	if (idx < MAX_IF_INDEX)
		return &if_zone_map[idx];
	return NULL;
}

static char nos_zone_ctl_buffer[PAGE_SIZE];
static void *nos_zone_start(struct seq_file *m, loff_t *pos)
{
	int n = 0;

	if ((*pos) == 0) {
		n = snprintf(nos_zone_ctl_buffer,
				sizeof(nos_zone_ctl_buffer) - 1,
				"# Usage:\n"
				"#    zone <id>=<if_name> -- set interface zone\n"
				"#    delete <id> -- delete one zone\n"
				"#    clean -- remove all existing zone(s)\n"
				"#\n"
				"# Info: "
				"#  VALID ZONE ID RANGE: 0~%u\n"
				"#  MAX ZONE: %u\n"
				"#\n"
				"# Reload cmd:\n"
				"\n"
				"clean\n"
				"\n",
				INVALID_ZONE_ID - 1, INVALID_ZONE_ID);
		nos_zone_ctl_buffer[n] = 0;
		return nos_zone_ctl_buffer;
	} else if ((*pos) > 0) {
		unsigned int *zone_id = (unsigned int *)nos_zone_get((*pos) - 1);

		if (zone_id) {
			nos_zone_ctl_buffer[0] = 0;
			if (*zone_id != INVALID_ZONE_ID) {
				struct net_device *dev = dev_get_by_index(&init_net, ((*pos) - 1));
				if (dev) {
					n = snprintf(nos_zone_ctl_buffer,
							sizeof(nos_zone_ctl_buffer) - 1,
							"zone %u=%s\n",
							*zone_id, dev->name);
					dev_put(dev);
					nos_zone_ctl_buffer[n] = 0;
				}
			}
			return nos_zone_ctl_buffer;
		}
	}

	return NULL;
}

static void *nos_zone_next(struct seq_file *m, void *v, loff_t *pos)
{
	int n;

	(*pos)++;
	if ((*pos) > 0) {
		unsigned int *zone_id = (unsigned int *)nos_zone_get((*pos) - 1);

		if (zone_id) {
			nos_zone_ctl_buffer[0] = 0;
			if (*zone_id != INVALID_ZONE_ID) {
				struct net_device *dev = dev_get_by_index(&init_net, ((*pos) - 1));
				if (dev) {
					n = snprintf(nos_zone_ctl_buffer,
							sizeof(nos_zone_ctl_buffer) - 1,
							"zone %u=%s\n",
							*zone_id, dev->name);
					dev_put(dev);
					nos_zone_ctl_buffer[n] = 0;
				}
			}
			return nos_zone_ctl_buffer;
		}
	}
	return NULL;
}

static void nos_zone_stop(struct seq_file *m, void *v)
{
}

static int nos_zone_show(struct seq_file *m, void *v)
{
	seq_printf(m, "%s", (char *)v);
	return 0;
}

const struct seq_operations nos_zone_seq_ops = {
	.start = nos_zone_start,
	.next = nos_zone_next,
	.stop = nos_zone_stop,
	.show = nos_zone_show,
};

static ssize_t nos_zone_read(struct file *file, char __user *buf, size_t buf_len, loff_t *offset)
{
	return seq_read(file, buf, buf_len, offset);
}

static ssize_t nos_zone_write(struct file *file, const char __user *buf, size_t buf_len, loff_t *offset)
{
	int err = 0;
	int n, l;
	int cnt = 256;
	struct zone_t zone;
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
		nos_zone_cleanup();
		goto done;
	} else if (strncmp(data, "zone ", 5) == 0) {
		n = sscanf(data, "zone %u=%s\n", &zone.id, zone.if_name);
		if (n == 2) {
			if ((err = nos_zone_set(&zone)) == 0)
				goto done;
			printk("nos_zone_set() failed ret=%d\n", err);
		}
	} else if (strncmp(data, "delete ", 7) == 0) {
		n = sscanf(data, "delete %u\n", &zone.id);
		if (n == 1) {
			if ((err = nos_zone_delete(&zone)) == 0)
				goto done;
			printk("nos_zone_delete() failed ret=%d\n", err);
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

static int nos_zone_open(struct inode *inode, struct file *file)
{
	int ret = seq_open(file, &nos_zone_seq_ops);
	if (ret)
		return ret;
	//set nonseekable
	file->f_mode &= ~(FMODE_LSEEK | FMODE_PREAD | FMODE_PWRITE);

	return 0;
}

static int nos_zone_release(struct inode *inode, struct file *file)
{
	return seq_release(inode, file);
}

static struct file_operations nos_zone_fops = {
	.owner = THIS_MODULE,
	.open = nos_zone_open,
	.release = nos_zone_release,
	.read = nos_zone_read,
	.write = nos_zone_write,
	.llseek  = seq_lseek,
};

int nos_zone_init(void)
{
	int retval = 0;
	dev_t devno;

	if (nos_zone_major>0) {
		devno = MKDEV(nos_zone_major, nos_zone_minor);
		retval = register_chrdev_region(devno, number_of_devices, nos_zone_dev_name);
	} else {
		retval = alloc_chrdev_region(&devno, nos_zone_minor, number_of_devices, nos_zone_dev_name);
	}
	if (retval < 0) {
		printk("alloc_chrdev_region failed!\n");
		return retval;
	}
	nos_zone_major = MAJOR(devno);
	nos_zone_minor = MINOR(devno);
	printk("nos_zone_major=%d, nos_zone_minor=%d\n", nos_zone_major, nos_zone_minor);

	cdev_init(&nos_zone_cdev, &nos_zone_fops);
	nos_zone_cdev.owner = THIS_MODULE;
	nos_zone_cdev.ops = &nos_zone_fops;

	retval = cdev_add(&nos_zone_cdev, devno, 1);
	if (retval) {
		printk("adding chardev, error=%d\n", retval);
		goto cdev_add_failed;
	}

	nos_zone_class = class_create(THIS_MODULE,"nos_zone_class");
	if (IS_ERR(nos_zone_class)) {
		printk("failed in creating class\n");
		retval = -EINVAL;
		goto class_create_failed;
	}

	nos_zone_dev = device_create(nos_zone_class, NULL, devno, NULL, nos_zone_dev_name);
	if (!nos_zone_dev) {
		retval = -EINVAL;
		goto device_create_failed;
	}

	zone_conf_init();

	return 0;

	//device_destroy(nos_zone_class, devno);
device_create_failed:
	class_destroy(nos_zone_class);
class_create_failed:
	cdev_del(&nos_zone_cdev);
cdev_add_failed:
	unregister_chrdev_region(devno, number_of_devices);

	return retval;
}

void nos_zone_exit(void)
{
	dev_t devno;

	zone_conf_exit();

	devno = MKDEV(nos_zone_major, nos_zone_minor);
	device_destroy(nos_zone_class, devno);
	class_destroy(nos_zone_class);
	cdev_del(&nos_zone_cdev);
	unregister_chrdev_region(devno, number_of_devices);
	return;
}
