#include <linux/proc_fs.h>
#include <linux/inet.h>

#include "nfw_private.h"

#define DRIVER_NAME "nfw"
#define PROC_DBG_FNAME "debug"
#define PROC_DBG_DNAME DRIVER_NAME

#define CMD_S_IPADDR	"addr="
#define CMD_S_PORT		"port="
#define CMD_S_BYPASS		"bypass="

#define PROC_DBG_BUFF_SIZE 512

typedef struct {
	struct mutex lock;
	uint32_t addr, mask;
	uint16_t port, bypass;
	struct proc_dir_entry *proc_dir, *proc_file_dbg;
} nfw_debug_t;

static nfw_debug_t GDBG;

int nfw_droplist_match(flow_info_t *fi)
{
	uint16_t port, bypass;
	uint32_t addr, mask;

	addr = GDBG.addr;
	mask = GDBG.mask;
	port = GDBG.port;
	bypass = GDBG.bypass;

	/* TODO: match the ip/mask & port */
	if(addr && (flow_srcip(fi) & mask) != (addr & mask)) {
		return 0;
	}
	if(port && flow_sport(fi) != port && flow_dport(fi) != port) {
		return 0;
	}
	/* filter matched. */
	if(GDBG.bypass) {
		/* BYPASS */
		return 1;
	}
	/* DROP */
	return -1;
}

static int fw_debug_set_addr(uint32_t addr, uint32_t mask)
{
	GDBG.addr = addr;
	GDBG.mask = mask;
	return 0;
}

static int fw_debug_set_port(uint16_t port)
{
	GDBG.port = port;
	return 0;
}

static int fw_debug_set_bypass(uint16_t bypass)
{
	GDBG.bypass = bypass;
	return 0;
}

static int nfw_open(struct inode *inode, struct file *file)
{
	mutex_lock(&GDBG.lock);
	return 0;
}

static int nfw_release(struct inode *inode, struct file *file)
{
	mutex_unlock(&GDBG.lock);
	return 0;
}

static ssize_t nfw_write(struct file *file,
					 const char __user *buffer,
					 size_t count, loff_t *offset)
{
	char *buf = NULL;
	const char *cmd;
	int err = 0;

	if(count > PROC_DBG_BUFF_SIZE) {
		fw_error("io buffer overflow: %d->%d\n", PROC_DBG_BUFF_SIZE, count);
		return -EIO;
	}

	buf = kzalloc(PROC_DBG_BUFF_SIZE, GFP_KERNEL);
	if (!buf) {
		fw_error("alloc failed, %d\n", PROC_DBG_BUFF_SIZE);
		return -ENOMEM;
	}
	if (copy_from_user(buf, buffer, count)) {
		err = -EFAULT;
		goto __error_out;
	}
	/* parse the cmdline */
	cmd = strstr(buf, CMD_S_IPADDR);
	if(cmd) {
		const char *cmd_end;
		uint32_t addr, mask = 0;

		mask = in4_pton(cmd + sizeof(CMD_S_IPADDR),
			count - (cmd - buf + sizeof(CMD_S_IPADDR)),
			(uint8_t*)&addr, ' ', &cmd_end);
		if(mask) {
			fw_error("parse addr err[%s]: %d\n", cmd, mask);
			goto __error_out;
		}
		if(*cmd_end =='/') {
			/* net mask */
			cmd = cmd_end++;
			if(strlen(cmd) >= 1) {
				if(sscanf(cmd, "%u", &mask) != 1) {
					fw_error("parse mask failed [%s].\n", cmd);
				}
			}
			if(mask>32) {
				mask = 0;
			}
			mask = 0xFFFFFFFFU << (32 - mask);
		}
		fw_debug_set_addr(addr, mask);
	}
	cmd = strstr(buf, CMD_S_PORT);
	if(cmd) {
		uint32_t port;
		if(sscanf(cmd + sizeof(CMD_S_PORT), "%u", &port) != 1) {
			fw_error("parse port err[%s]\n", cmd);
			goto __error_out;
		}
		fw_debug_set_port((uint16_t)port);
	}
	cmd = strstr(buf, CMD_S_BYPASS);
	if(cmd) {
		uint32_t bypass;
		if(sscanf(cmd + sizeof(CMD_S_BYPASS), "%u", &bypass) != 1) {
			fw_error("parse bypass err[%s]\n", cmd);
			goto __error_out;
		}
		fw_debug_set_bypass((uint16_t)bypass);
	}

 __error_out:
	if(buf) {
		kfree(buf);
	}
	if (err < 0)
		return err;
	return count;
}

static ssize_t nfw_read(struct file *file, char __user *buffer,
				   size_t count, loff_t * offset)
{
	int size = 0;

	if(*offset != 0) {
		return 0;
	}

	size = snprintf(buffer, count, "addr=x.x.x.x/mask port=xx\n"
		"\t%u.%u.%u.%u/%u.%u.%u.%u:%u, bypass: %u\n",
		NIPQUAD(GDBG.addr), NIPQUAD(GDBG.mask), ntohs(GDBG.port), GDBG.bypass);

	*offset += size;
	return size;
}

static const struct file_operations debug_ops = {
	.owner		= THIS_MODULE,
	.open		= nfw_open,
	.release	= nfw_release,
	.write		= nfw_write,
	.read		= nfw_read,
	.llseek		= seq_lseek,
};

int nfw_dbg_init(void)
{
	struct proc_dir_entry *dir, *file;

	memset(&GDBG, 0, sizeof(GDBG));
	mutex_init(&GDBG.lock);
	/* create proc dir */
	if(GDBG.proc_dir) {
		fw_error("re-inited ...\n");
		return -EINVAL;
	}
	dir = proc_mkdir(PROC_DBG_DNAME, NULL);
	if(!dir) {
		fw_error("create dir failed.\n");
		return -EINVAL;
	}
	file = proc_create_data(PROC_DBG_FNAME, 655, dir, &debug_ops, NULL);
	if(!file) {
		fw_error("create debug file failed.\n");
		remove_proc_entry(PROC_DBG_DNAME, NULL);
		return -EINVAL;
	}

	GDBG.proc_dir = dir;
	GDBG.proc_file_dbg = file;
	return 0;
}

void nfw_dbg_exit(void)
{
	remove_proc_entry(PROC_DBG_FNAME, GDBG.proc_dir);
	remove_proc_entry(PROC_DBG_DNAME, NULL);
}
