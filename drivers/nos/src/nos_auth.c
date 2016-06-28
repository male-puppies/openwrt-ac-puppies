/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Wed, 15 Jun 2016 11:14:16 +0800
 */
#include "nos_auth.h"

/*
 * Author: Chen Minqiang <ptpt52@gmail.com>
 *  Date : Thu, 16 Jun 2016 10:32:40 +0800
 */
#include <net/ip.h>
#include <net/tcp.h>
#include <net/protocol.h>
#include <net/checksum.h>
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
	int i;
	nos_hook_disable = 1;
	synchronize_rcu();
	for (i = 0; i < auth_conf.num; i++)
	{
		if (auth_conf.auth[i].ip_white_list_set)
			ip_set_put_byindex(&init_net, auth_conf.auth[i].ip_white_list_id);
		if (auth_conf.auth[i].mac_white_list_set)
			ip_set_put_byindex(&init_net, auth_conf.auth[i].mac_white_list_id);
	}
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

	for (i = 0; i < auth_conf.num; i++)
	{
		if (auth_conf.auth[i].id == auth->id)
			return -EEXIST;
	}
	if (auth_conf.num == MAX_AUTH)
		return -ENOSPC;

	nos_hook_disable = 1;
	synchronize_rcu();
	i = auth_conf.num;
	memcpy(&auth_conf.auth[i], auth, sizeof(struct auth_rule_t));
	auth_conf.num = i + 1;
	g_conf_magic++;
	nos_hook_disable = 0;

	return 0;
}

static inline int nos_auth_delete(const struct auth_rule_t *auth)
{
	int i;
	for (i = 0; i < auth_conf.num; i++) {
		if (auth_conf.auth[i].id == auth->id) {
			nos_hook_disable = 1;
			synchronize_rcu();
			if (auth_conf.auth[i].ip_white_list_set)
				ip_set_put_byindex(&init_net, auth_conf.auth[i].ip_white_list_id);
			if (auth_conf.auth[i].mac_white_list_set)
				ip_set_put_byindex(&init_net, auth_conf.auth[i].mac_white_list_id);
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

void nos_auth_match(const struct net_device *in, const struct net_device *out, struct sk_buff *skb, struct nos_user_info *ui)
{
	int i;
	ui->hdr.type = AUTH_TYPE_UNKNOWN;
	ui->hdr.status = AUTH_BYPASS;
	for (i = 0; i < auth_conf.num; i++) {
		if (ui->hdr.src_zone_id == auth_conf.auth[i].src_zone_id &&
				(ui->hdr.src_ipgrp_bits & (1 << auth_conf.auth[i].src_ipgrp_id)) ) {
			ui->hdr.rule_idx[NOS_RULE_TYPE_AUTH] = i;
			if (auth_conf.auth[i].auth_type == AUTH_TYPE_AUTO) {
				ui->hdr.type = AUTH_TYPE_AUTO;
				ui->hdr.status = AUTH_OK;
			} else {
				ui->hdr.type = AUTH_TYPE_WEB;
				ui->hdr.status = AUTH_NONE;
				if (auth_conf.auth[i].ip_white_list_set) {
					if (ip_set_test_src_ip(in, out, skb, auth_conf.auth[i].ip_white_list_id) > 0) {
						ui->hdr.status = AUTH_BYPASS;
					} else if (ip_set_test_src_mac(in, out, skb, auth_conf.auth[i].mac_white_list_id) > 0) {
						ui->hdr.status = AUTH_BYPASS;
					}
				}
			}
			nos_user_info_hold(ui);
			return;
		}
	}
	ui->hdr.rule_idx[NOS_RULE_TYPE_AUTH] = MAX_AUTH;
}

static inline void nos_auth_reply_payload(const char *payload, int payload_len, struct sk_buff *oskb, const struct net_device *dev)
{
	struct sk_buff *nskb;
	struct ethhdr *neth, *oeth;
	struct iphdr *niph, *oiph;
	struct tcphdr *otcph, *ntcph;
	int len;
	unsigned int csum;
	int offset, header_len;
	char *data;

	oeth = (struct ethhdr *)skb_mac_header(oskb);
	oiph = ip_hdr(oskb);
	otcph = (struct tcphdr *)((void *)oiph + oiph->ihl*4);

	offset = sizeof(struct iphdr) + sizeof(struct tcphdr) + payload_len - oskb->len;
	header_len = offset < 0 ? 0 : offset;
	nskb = skb_copy_expand(oskb, skb_headroom(oskb), header_len, GFP_ATOMIC);
	if (!nskb) {
		printk("alloc_skb fail\n");
		return;
	}

	data = (char *)ip_hdr(nskb) + sizeof(struct iphdr) + sizeof(struct tcphdr);
	memcpy(data, payload, payload_len);

	ntcph = (struct tcphdr *)((char *)ip_hdr(nskb) + sizeof(struct iphdr));
	memset(ntcph, 0, sizeof(struct tcphdr));
	ntcph->source = otcph->dest;
	ntcph->dest = otcph->source;
	ntcph->seq = otcph->ack_seq;
	ntcph->ack_seq = htonl(ntohl(otcph->seq) + ntohs(oiph->tot_len) - (oiph->ihl<<2) - (otcph->doff<<2));
	ntcph->doff = 5;
	ntcph->ack = 1;
	ntcph->psh = 1;
	ntcph->fin = 1;
	ntcph->window = 65535;

	niph = ip_hdr(nskb);
	memset(niph, 0, sizeof(struct iphdr));
	niph->saddr = oiph->daddr;
	niph->daddr = oiph->saddr;
	niph->version = oiph->version;
	niph->ihl = 5;
	niph->tos = 0;
	niph->tot_len = htons(sizeof(struct iphdr) + sizeof(struct tcphdr) + payload_len);
	niph->ttl = 0x80;
	niph->protocol = oiph->protocol;
	niph->id = __constant_htons(0xDEAD);
	niph->frag_off = 0x0;
	ip_send_check(niph);

	len = ntohs(niph->tot_len) - (niph->ihl<<2);
	csum = csum_partial((char*)ntcph, len, 0);
	ntcph->check = tcp_v4_check(len, niph->saddr, niph->daddr, csum);

	neth = eth_hdr(nskb);
	memcpy(neth->h_dest, oeth->h_source, ETH_ALEN);
	memcpy(neth->h_source, oeth->h_dest, ETH_ALEN);
	neth->h_proto = htons(ETH_P_IP);
	nskb->len += offset;
	skb_push(nskb, (char *)niph - (char *)neth);
	nskb->dev = (struct net_device *)dev;
	nskb->ip_summed = CHECKSUM_NONE;

	dev_queue_xmit(nskb);
}

void nos_auth_http_302(const struct net_device *dev, struct sk_buff *skb, const struct nos_user_info *ui)
{
	const char *http_header_fmt = ""
		"HTTP/1.1 302 Moved Temporarily\r\n"
		"Connection: close\r\n"
		"Cache-Control: no-cache\r\n"
		"Content-Type: text/html; charset=UTF-8\r\n"
		"Location: %s\r\n"
		"Content-Length: %u\r\n"
		"\r\n";
	const char *http_data_fmt = ""
		"<HTML><HEAD><meta http-equiv=\"content-type\" content=\"text/html;charset=utf-8\">\r\n"
		"<TITLE>302 Moved</TITLE></HEAD><BODY>\r\n"
		"<H1>302 Moved</H1>\r\n"
		"The document has moved\r\n"
		"<A HREF=\"%s\">here</A>.\r\n"
		"</BODY></HTML>\r\n";
	int n = 0;
	struct ethhdr *eth = eth_hdr(skb);
	struct {
		char location[128];
		char data[384];
		char header[384];
		char payload[0];
	} *http = kmalloc(2048, GFP_ATOMIC);
	if (!http)
		return;

	snprintf(http->location, sizeof(http->location), "http://%pI4/index.html?ip=%pI4&mac=%02X-%02X-%02X-%02X-%02X-%02X&uid=%u&magic=%u&_t=%lu",
			&redirect_ip, &ui->ip,
			eth->h_source[0], eth->h_source[1], eth->h_source[2],
			eth->h_source[3], eth->h_source[4], eth->h_source[5],
			ui->id, ui->magic, jiffies);
	http->location[sizeof(http->location) - 1] = 0;
	n = snprintf(http->data, sizeof(http->data), http_data_fmt, http->location);
	http->data[sizeof(http->data) - 1] = 0;
	snprintf(http->header, sizeof(http->header), http_header_fmt, http->location, n);
	http->header[sizeof(http->header) - 1] = 0;
	n = sprintf(http->payload, "%s%s", http->header, http->data);

	nos_auth_reply_payload(http->payload, n, skb, dev);
}

void nos_auth_convert_tcprst(struct sk_buff *skb)
{
	int offset = 0;
	int len;
	struct iphdr *iph;
	struct tcphdr *tcph;

	iph = ip_hdr(skb);
	if (iph->protocol != IPPROTO_TCP)
		return;
	tcph = (struct tcphdr *)((void *)iph + iph->ihl * 4);
	offset = ntohs(iph->tot_len) - ((iph->ihl << 2) + sizeof(struct tcphdr));
	tcph->ack = 0;
	tcph->psh = 0;
	tcph->rst = 1;
	tcph->fin = 0;
	tcph->window = htons(0);
	tcph->doff = sizeof(struct tcphdr) / 4;

	iph->tot_len = htons(ntohs(iph->tot_len) - offset);
	iph->id = __constant_htons(0xDEAD);
	iph->frag_off = 0;

	skb->tail -= offset;
	skb->len -= offset;

	len = ntohs(iph->tot_len);

	if (skb->ip_summed == CHECKSUM_PARTIAL) {
		iph->check = 0;
		iph->check = ip_fast_csum(iph, iph->ihl);
		tcph->check = 0;
		tcph->check = ~csum_tcpudp_magic(iph->saddr, iph->daddr, skb->len - iph->ihl * 4, IPPROTO_TCP, 0);
		skb->csum_start = (unsigned char *)tcph - skb->head;
		skb->csum_offset = offsetof(struct tcphdr, check);
	} else {
		iph->check = 0;
		iph->check = ip_fast_csum(iph, iph->ihl);
		skb->csum = 0;
		tcph->check = 0;
		skb->csum = skb_checksum(skb, iph->ihl * 4, len - iph->ihl * 4, 0);
		tcph->check = csum_tcpudp_magic(iph->saddr, iph->daddr, len - iph->ihl * 4, iph->protocol, skb->csum);

		skb->ip_summed = CHECKSUM_NONE;
	}
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
				"#    auth id=<id>,szone=<idx>,sipgrp=<idx>,type=web/auto[,ipwhite=<name>][,macwhite=<name>] -- set one auth\n"
				"#    delete <id> -- delete one auth\n"
				"#    clean -- remove all existing auth(s)\n"
				"#    redirect_ip=a.b.c.d -- set the redirect ip\n"
				"#\n"
				"# Info:\n"
				"#    redirect_ip=%pI4\n"
				"#    no_flow_timeout=%u\n"
				"#\n"
				"# Reload cmd:\n"
				"\n"
				"clean\n"
				"\n",
				&redirect_ip,
				nos_auth_no_flow_timeout);
		nos_auth_ctl_buffer[n] = 0;
		return nos_auth_ctl_buffer;
	} else if ((*pos) > 0) {
		struct auth_rule_t *auth = (struct auth_rule_t *)nos_auth_get((*pos) - 1);

		if (auth) {
			n = snprintf(nos_auth_ctl_buffer,
					sizeof(nos_auth_ctl_buffer) - 1,
					"auth id=%u,szone=%u,sipgrp=%u,type=%s%s%s%s%s\n",
					auth->id, auth->src_zone_id, auth->src_ipgrp_id, auth->auth_type == AUTH_TYPE_AUTO ? "auto" : "web",
					auth->ip_white_list_set ? ",ipwhite=" : "", auth->ip_white_list_set ? ip_set_name_byindex(&init_net, auth->ip_white_list_id) :"",
					auth->mac_white_list_set ? ",macwhite=" : "", auth->mac_white_list_set ? ip_set_name_byindex(&init_net, auth->mac_white_list_id) :"");
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
					"auth id=%u,szone=%u,sipgrp=%u,type=%s%s%s%s%s\n",
					auth->id, auth->src_zone_id, auth->src_ipgrp_id, auth->auth_type == AUTH_TYPE_AUTO ? "auto" : "web",
					auth->ip_white_list_set ? ",ipwhite=" : "", auth->ip_white_list_set ? ip_set_name_byindex(&init_net, auth->ip_white_list_id) :"",
					auth->mac_white_list_set ? ",macwhite=" : "", auth->mac_white_list_set ? ip_set_name_byindex(&init_net, auth->mac_white_list_id) :"");
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
		nos_auth_cleanup();
		goto done;
	} else if (strncmp(data, "auth id=", 8) == 0) {
		memset(&auth, 0, sizeof(auth));
		n = sscanf(data, "auth id=%u,szone=%u,sipgrp=%u",
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
			goto done;
		}
	} else if (strncmp(data, "no_flow_timeout=", 16) == 0) {
		unsigned int a;
		n = sscanf(data, "no_flow_timeout=%u", &a);
		if (n == 1) {
			nos_auth_no_flow_timeout = a;
			goto done;
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
