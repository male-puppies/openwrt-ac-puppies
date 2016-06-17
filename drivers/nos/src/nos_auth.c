/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Wed, 15 Jun 2016 11:14:16 +0800
 */
#include "nos_auth.h"

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
#include <linux/netfilter/ipset/ip_set.h>
#include "nos.h"
#include "nos_auth.h"
#include "nos_zone.h"
#include "nos_ipgrp.h"

/*XXX: default redirect_ip 1.0.0.8 */
unsigned int redirect_ip = __constant_htonl((1<<24)|(0<<16)|(0<<8)|(8<<0));

static int nos_auth_major = 0;
static int nos_auth_minor = 0;
static int number_of_devices = 1;
static struct cdev nos_auth_cdev;
const char *nos_auth_dev_name = "nos_auth_ctl";
static struct class *nos_auth_class;
static struct device *nos_auth_dev;

static struct auth_conf auth_conf;
static inline void auth_conf_init(void)
{
	memset(&auth_conf, 0, sizeof(auth_conf));
}

static inline void nos_auth_cleanup(void)
{
	nos_hook_disable = 1;
	synchronize_rcu();
	memset(&auth_conf, 0, sizeof(auth_conf));
	g_conf_magic++;
	nos_hook_disable = 0;
}

static inline void auth_conf_exit(void)
{
	nos_auth_cleanup();
}

static inline int nos_auth_set(const struct auth_rule_t *auth)
{
	int i;

	if (auth->id >= MAX_AUTH)
		return -EINVAL;
	if (auth->src_zone_id >= INVALID_ZONE_ID)
		return -EINVAL;
	if (auth->src_ipgrp_id >= MAX_IPGRP)
		return -EINVAL;

	if (auth_conf.num == MAX_AUTH)
		return -ENOSPC;
	for (i = 0; i < auth_conf.num; i++)
	{
		if (auth_conf.auth[i].id == auth->id)
			break;
	}

	nos_hook_disable = 1;
	synchronize_rcu();
	memcpy(&auth_conf.auth[i], auth, sizeof(struct auth_rule_t));
	if (i == auth_conf.num)
		auth_conf.num = i + 1;
	g_conf_magic++;
	nos_hook_disable = 0;

	return 0;
}

static inline int nos_auth_delete(const struct auth_rule_t *auth)
{
	int i;
	for (i = 0; i < auth_conf.num; i++)
	{
		if (auth_conf.auth[i].id == auth->id) {
			nos_hook_disable = 1;
			synchronize_rcu();
			if (i + 1 < auth_conf.num) {
				memmove(&auth_conf.auth[i], &auth_conf.auth[i+1], sizeof(struct auth_rule_t) * (auth_conf.num - 1 - i));
			}
			auth_conf.num = auth_conf.num - 1;
			g_conf_magic++;
			nos_hook_disable = 0;
			return 0;
		}
	}

	return -ENOENT;
}

void *nos_auth_get(loff_t idx)
{
	if (idx < auth_conf.num)
		return &auth_conf.auth[idx];
	return NULL;
}

static char nos_auth_ctl_buffer[PAGE_SIZE];
static void *nos_auth_start(struct seq_file *m, loff_t *pos)
{
	int n = 0;

	if ((*pos) == 0) {
		n = snprintf(nos_auth_ctl_buffer,
				sizeof(nos_auth_ctl_buffer) - 1,
				"# Usage:\n"
				"#    id=<idx>,szone=<idx>,sip=<idx>,type=web/auto[,ipwhite=<name>][,macwhite=<name>] -- set one auth\n"
				"#    delete auth_id=<idx> -- delete one auth\n"
				"#    clean -- remove all existing auth(s)\n"
				"#    redirect_ip=a.b.c.d -- set the redirect ip\n"
				"#\n"
				"# Info:\n"
				"#    redirect_ip=%pI4\n"
				"#\n"
				"# Reload cmd:\n"
				"\n"
				"clean\n"
				"\n"
				"redirect_ip=%pI4\n",
				&redirect_ip,
				&redirect_ip);
		nos_auth_ctl_buffer[n] = 0;
		return nos_auth_ctl_buffer;
	} else if ((*pos) > 0) {
		struct auth_rule_t *auth = (struct auth_rule_t *)nos_auth_get((*pos) - 1);

		if (auth) {
			n = snprintf(nos_auth_ctl_buffer,
					sizeof(nos_auth_ctl_buffer) - 1,
					"auth_id=%u,src_zone=%u,src_ipgrp=%u,auth_type=%s\n",
					auth->id, auth->src_zone_id, auth->src_ipgrp_id, auth->auth_type == AUTH_TYPE_AUTO ? "auto" : "web");
			nos_auth_ctl_buffer[n] = 0;
			return nos_auth_ctl_buffer;
		}
	}

	return NULL;
}

static void *nos_auth_next(struct seq_file *m, void *v, loff_t *pos)
{
	int n;

	(*pos)++;
	if ((*pos) > 0) {
		struct auth_rule_t *auth = (struct auth_rule_t *)nos_auth_get((*pos) - 1);

		if (auth) {
			n = snprintf(nos_auth_ctl_buffer,
					sizeof(nos_auth_ctl_buffer) - 1,
					"auth_id=%u,src_zone=%u,src_ipgrp=%u,auth_type=%s\n",
					auth->id, auth->src_zone_id, auth->src_ipgrp_id, auth->auth_type == 0 ? "auto" : "web");
			nos_auth_ctl_buffer[n] = 0;
			return nos_auth_ctl_buffer;
		}
	}
	return NULL;
}

static void nos_auth_stop(struct seq_file *m, void *v)
{
}

static int nos_auth_show(struct seq_file *m, void *v)
{
	seq_printf(m, "%s", (char *)v);
	return 0;
}

const struct seq_operations nos_auth_seq_ops = {
	.start = nos_auth_start,
	.next = nos_auth_next,
	.stop = nos_auth_stop,
	.show = nos_auth_show,
};

static ssize_t nos_auth_read(struct file *file, char __user *buf, size_t buf_len, loff_t *offset)
{
	return seq_read(file, buf, buf_len, offset);
}

static ssize_t nos_auth_write(struct file *file, const char __user *buf, size_t buf_len, loff_t *offset)
{
	int err = 0;
	int n, l;
	int cnt = 256;
	struct auth_rule_t auth;
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
		printk("nos_auth_cleanup\n");
		nos_auth_cleanup();
		goto done;
	} else if (strncmp(data, "auth_id=", 8) == 0) {
		printk("id=<idx>,szone=<idx>,sip=<idx>,type=web/auto[,ipwhite=<name>][,macwhite=<name>]\n");
		memset(&auth, 0, sizeof(auth));
		n = sscanf(data, "id=%u,szone=%u,sip=%u",
				&auth.id,
				&auth.src_zone_id,
				&auth.src_ipgrp_id);
		if (n == 3) {
			int i = 0;
			int j = 0;
			int found = 1;
			do {
				if (found && j == 3) {
					found = 0;
					if (strncmp(data + i, "type=web", 8) == 0) {
						auth.auth_type = AUTH_TYPE_WEB;
					} else if (strncmp(data + i, "type=auto", 9) == 0) {
						auth.auth_type = AUTH_TYPE_AUTO;
					} else {
						err = -EINVAL;
						break;
					}
				}
				if (found && (j == 4 || j == 5)) {
					found = 0;
					if (strncmp(data + i, "ipwhite=", 8) == 0) {
						int k = 0;
						char buf[256];
						buf[0] = 0;
						i += 8;
						while (i < 256 && data[i] && data[i] != ',' && data[i] != '\n') {
							buf[k++] = data[i];
							i++;
						}
						buf[k] = 0;
						if (buf[0]) {
							ip_set_id_t id;
							struct ip_set *set;
							id = ip_set_get_byname(&init_net, buf, &set);
							if (id != IPSET_INVALID_ID) {
								auth.ip_white_list_id = id;
								auth.ip_white_list_set = set;
							} else {
								err = -EINVAL;
								break;
							}
						}
					} else if (strncmp(data + i, "macwhite=", 9) == 0) {
						int k = 0;
						char buf[256];
						i += 9;
						while (i < 256 && data[i] && data[i] != ',' && data[i] != '\n') {
							buf[k++] = data[i];
							i++;
						}
						buf[k] = 0;
						if (buf[0]) {
							ip_set_id_t id;
							struct ip_set *set;
							id = ip_set_get_byname(&init_net, buf, &set);
							if (id != IPSET_INVALID_ID) {
								auth.mac_white_list_id = id;
								auth.mac_white_list_set = set;
							} else {
								err = -EINVAL;
								break;
							}
						}
					} else {
						err = -EINVAL;
						break;
					}
				}
				if (data[i] == ',') {
					found = 1;
					j++;
				} else {
					found = 0;
				}
				if (data[i] == '\n')
					break;
				i++;
			} while (i < 256);
			if (err == 0) {
				if ((err = nos_auth_set(&auth)) == 0)
					goto done;
			}
			if (auth.ip_white_list_set)
				ip_set_put_byindex(&init_net, auth.ip_white_list_id);
			if (auth.mac_white_list_set)
				ip_set_put_byindex(&init_net, auth.mac_white_list_id);
			printk("nos_auth_set() failed ret=%d\n", err);
		}
	} else if (strncmp(data, "delete ", 7) == 0) {
		printk("delete <idx>\n");
		n = sscanf(data, "delete %u\n", &auth.id);
		if (n == 1) {
			if ((err = nos_auth_delete(&auth)) == 0)
				goto done;
			printk("nos_auth_delete() failed ret=%d\n", err);
		}
	} else if (strncmp(data, "redirect_ip=", 12) == 0) {
		unsigned int a, b, c ,d;
		n = sscanf(data, "redirect_ip=%u.%u.%u.%u", &a, &b, &c, &d);
		if ( n == 4 &&
				(((a & 0xff) == a) &&
				 ((b & 0xff) == b) &&
				 ((c & 0xff) == c) &&
				 ((d & 0xff) == d)) ) {
			redirect_ip = htonl((a<<24)|(b<<16)|(c<<8)|(d<<0));
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

static int nos_auth_open(struct inode *inode, struct file *file)
{
	int ret = seq_open(file, &nos_auth_seq_ops);
	if (ret)
		return ret;
	//set nonseekable
	file->f_mode &= ~(FMODE_LSEEK | FMODE_PREAD | FMODE_PWRITE);

	return 0;
}

static int nos_auth_release(struct inode *inode, struct file *file)
{
	return seq_release(inode, file);
}

static struct file_operations nos_auth_fops = {
	.owner = THIS_MODULE,
	.open = nos_auth_open,
	.release = nos_auth_release,
	.read = nos_auth_read,
	.write = nos_auth_write,
	.llseek  = seq_lseek,
};

int nos_auth_init(void)
{
	int retval = 0;
	dev_t devno;

	if (nos_auth_major>0) {
		devno = MKDEV(nos_auth_major, nos_auth_minor);
		retval = register_chrdev_region(devno, number_of_devices, nos_auth_dev_name);
	} else {
		retval = alloc_chrdev_region(&devno, nos_auth_minor, number_of_devices, nos_auth_dev_name);
	}
	if (retval < 0) {
		printk("alloc_chrdev_region failed!\n");
		return retval;
	}
	nos_auth_major = MAJOR(devno);
	nos_auth_minor = MINOR(devno);
	printk("nos_auth_major=%d, nos_auth_minor=%d\n", nos_auth_major, nos_auth_minor);

	cdev_init(&nos_auth_cdev, &nos_auth_fops);
	nos_auth_cdev.owner = THIS_MODULE;
	nos_auth_cdev.ops = &nos_auth_fops;

	retval = cdev_add(&nos_auth_cdev, devno, 1);
	if (retval) {
		printk("adding chardev, error=%d\n", retval);
		goto cdev_add_failed;
	}

	nos_auth_class = class_create(THIS_MODULE,"nos_auth_class");
	if (IS_ERR(nos_auth_class)) {
		printk("failed in creating class\n");
		retval = -EINVAL;
		goto class_create_failed;
	}

	nos_auth_dev = device_create(nos_auth_class, NULL, devno, NULL, nos_auth_dev_name);
	if (!nos_auth_dev) {
		retval = -EINVAL;
		goto device_create_failed;
	}

	auth_conf_init();

	return 0;

	//device_destroy(nos_auth_class, devno);
device_create_failed:
	class_destroy(nos_auth_class);
class_create_failed:
	cdev_del(&nos_auth_cdev);
cdev_add_failed:
	unregister_chrdev_region(devno, number_of_devices);

	return retval;
}

void nos_auth_exit(void)
{
	dev_t devno;

	auth_conf_exit();

	devno = MKDEV(nos_auth_major, nos_auth_minor);
	device_destroy(nos_auth_class, devno);
	class_destroy(nos_auth_class);
	cdev_del(&nos_auth_cdev);
	unregister_chrdev_region(devno, number_of_devices);
	return;
}
