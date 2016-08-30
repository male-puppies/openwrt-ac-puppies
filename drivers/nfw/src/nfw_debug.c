#include <linux/kernel.h>
#include <linux/vmalloc.h>
#include <linux/proc_fs.h>
#include <linux/inet.h>

#include "nfw_private.h"

#define DRIVER_NAME "nfw"
#define PROC_DBG_FNAME "debug"
#define PROC_DBG_DNAME DRIVER_NAME

#define CMD_S_addr	"addr="
#define CMD_S_port		"port="
#define CMD_S_bypass	"bypass="

#define DBG_CMD_BUFF_SZ (512)
#define DBG_IO_BUFF_SZ 	(1024 * 16)

typedef struct {
	struct mutex lock;
	uint32_t addr, mask;
	uint16_t port, bypass;
	struct proc_dir_entry *proc_dir, *proc_file_dbg;
} nfw_debug_t;

static void *io_buff = NULL;
static int32_t io_length = 0, io_offset = 0;
static DEFINE_SPINLOCK(io_lock);

static nfw_debug_t GDBG;

void fw_log(const char *fmt, ...)
{
	int32_t len, room;
	int32_t total_len = DBG_IO_BUFF_SZ;
	va_list args;

	if(!spin_trylock_bh(&io_lock)) {
		return;
	}

	va_start(args, fmt);
	room = total_len - io_offset;
	len = vsnprintf(io_buff + io_offset, room, fmt, args);
	if(len > room) {
		/* rollback */
		io_offset = 0;
	} else {
		io_offset += len;
	}
	io_length += len;
	if(io_length >= DBG_IO_BUFF_SZ) {
		io_length = DBG_IO_BUFF_SZ;
	}
	va_end(args);

	spin_unlock_bh(&io_lock);
}

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
	const char *cmd = NULL;

	if(count < 2){
		/* filter \r\n */
		return count;
	}

	if(count > DBG_CMD_BUFF_SZ) {
		fw_error("io buffer overflow: %d->%d\n", DBG_CMD_BUFF_SZ, (int)count);
		return -EIO;
	}

	buf = kzalloc(DBG_CMD_BUFF_SZ, GFP_KERNEL);
	if (!buf) {
		fw_error("alloc failed, %d\n", DBG_CMD_BUFF_SZ);
		return -ENOMEM;
	}
	if (copy_from_user(buf, buffer, count)) {
		goto __error_out;
	}
	/* parse the cmdline */
	cmd = strstr(buf, CMD_S_addr);
	if(cmd) {
		int ret, len;
		const char *cmd_start, *cmd_end;
		uint32_t addr, mask = 0;

		cmd_start = cmd + strlen(CMD_S_addr);
		len = strchr(cmd, '/') - cmd_start;
		ret = in4_pton(cmd_start, len, (uint8_t*)&addr, -1, &cmd_end);
		if(ret != 1) { /* shit, 1==success */
			fw_error("parse addr err[%s]: %d\n", cmd_start, ret);
			goto __error_out;
		}
		if(*cmd_end =='/') {
			/* net mask */
			cmd = cmd_end + 1;
			if(strlen(cmd) >= 1) {
				if(sscanf(cmd, "%u", &mask) != 1) {
					fw_error("parse mask failed [%s].\n", cmd);
				}
			}
			if(mask>32) {
				/* default 255.255.255.255 */
				mask = 32;
			}
			mask = 0xFFFFFFFFU << (32 - mask);
		}
		fw_debug_set_addr(addr, mask);
	}
	cmd = strstr(buf, CMD_S_port);
	if(cmd) {
		uint32_t port;
		if(sscanf(cmd + strlen(CMD_S_port), "%u", &port) != 1) {
			fw_error("parse port err[%s]\n", cmd);
			goto __error_out;
		}
		fw_debug_set_port((uint16_t)port);
	}
	cmd = strstr(buf, CMD_S_bypass);
	if(cmd) {
		uint32_t bypass;
		if(sscanf(cmd + strlen(CMD_S_bypass), "%u", &bypass) != 1) {
			fw_error("parse bypass err[%s]\n", cmd);
			goto __error_out;
		}
		fw_debug_set_bypass((uint16_t)bypass);
	}

	/* review */
	printk("usage: echo 'addr=x.x.x.x/xx port=xxxx' > /proc/nfw/debug \n"
		"\t%u.%u.%u.%u/%u.%u.%u.%u:%u, bypass: %u\n",
			NIPQUAD(GDBG.addr), NIPQUAD(GDBG.mask), ntohs(GDBG.port), GDBG.bypass);

 __error_out:
	if(buf) {
		kfree(buf);
	}
	return count;
}

static ssize_t nfw_read(struct file *file, char __user *buffer,
				   size_t count, loff_t * offset)
{
	int size = 0, buff_off = 0, ret = 0;

	/* read buff to userspace. */
	spin_lock_bh(&io_lock);
	if(!io_length) {
		/* empty */
		goto __out;
	}
	buff_off = io_offset - io_length;
	if(buff_off < 0) {
		/* rollback */
		buff_off += DBG_IO_BUFF_SZ;
		size = DBG_IO_BUFF_SZ - buff_off;
	} else {
		size = io_length;
	}
	if(size > count) {
		size = count;
	}
	ret = copy_to_user(buffer, io_buff + buff_off, size);
	if(ret) {
		size -= ret;
	}
	io_length -= size;
	*offset += size;

__out:
	spin_unlock_bh(&io_lock);
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
	GDBG.mask=0xFFFFFFFFU;

	/* alloc mem */
	io_buff = vmalloc(DBG_IO_BUFF_SZ);
	if(!io_buff) {
		fw_error("alloc io buffer %d failed\n", DBG_IO_BUFF_SZ);
		return -ENOMEM;
	}

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
	if(io_buff) {
		vfree(io_buff);
	}
}
