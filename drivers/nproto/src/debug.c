#include <linux/proc_fs.h>

#include "nproto_private.h"

#define PROC_DNAME_DBG 	DRIVER_NAME
#define PROC_FNAME_DBG 	"debug"
#define PROC_FNAME_DUMP	"dump"
#define CMD_S_TRACE 	"trace_id="

#define PROC_DBG_BUFF_SIZE (1024*8)

static struct mutex io_lock;
static struct proc_dir_entry *nproto_proc_dir;
static int nproto_open(struct inode *inode, struct file *file)
{
	int err;
	void *p = file->private_data;

	mutex_lock(&io_lock);
	if(p) {
		np_error("not nil private data\n");
		err = -EINVAL;
		goto __error_out;
	}
	p = kzalloc(PROC_DBG_BUFF_SIZE, GFP_KERNEL);
	if (!p) {
		np_error("alloc failed, %d\n", PROC_DBG_BUFF_SIZE);
		err = -ENOMEM;
		goto __error_out;
	}
	file->private_data = p;

	return 0;
__error_out:

	return err;
}

static int nproto_release(struct inode *inode, struct file *file)
{
	void *p = file->private_data;
	if(p) {
		kfree(p);
	}
	file->private_data = NULL;
	mutex_unlock(&io_lock);
	return 0;
}

static ssize_t nproto_write(struct file *file,
					 const char __user *buffer,
					 size_t count, loff_t *offset)
{
	int err = 0;
	const char *cmd;
	char *buf = file->private_data;

	if(count > PROC_DBG_BUFF_SIZE) {
		np_error("io buffer overflow: %d->%d\n", PROC_DBG_BUFF_SIZE, (unsigned int)count);
		return -EIO;
	}
	if (copy_from_user(buf, buffer, count)) {
		err = -EFAULT;
		goto __error_out;
	}
	/* parse the cmdline */
	cmd = strstr(buf, CMD_S_TRACE);
	if(cmd) {
		int value;
		if(sscanf(cmd + sizeof(CMD_S_TRACE), "%d", &value) != 1) {
			np_error("parse trace id err[%s]\n", cmd);
			goto __error_out;
		}
		rule_trace_id = value;
	}

 __error_out:
	if (err < 0)
		return err;
	return count;
}

static ssize_t nproto_read(struct file *file, char __user *buffer,
				   size_t count, loff_t * offset)
{
	int size = 0;

	if(*offset != 0) {
		return 0;
	}

	size = snprintf(buffer, count, "trace_id=\n"
		"\ttrace_id: %u\n", rule_trace_id);

	*offset += size;
	return size;
}

static const struct file_operations debug_ops = {
	.owner		= THIS_MODULE,
	.open		= nproto_open,
	.release	= nproto_release,
	.write		= nproto_write,
	.read		= nproto_read,
};

static ssize_t nproto_dump_wr(struct file *file,
					 const char __user *buffer,
					 size_t count, loff_t *offset)
{
	return count;
}

static ssize_t nproto_dump_rd(struct file *file, char __user *buffer,
				   size_t count, loff_t * offset)
{
	void *p = file->private_data;
	int size = 0;

	size = nproto_rules_dump_name(buffer, count, p, PROC_DBG_BUFF_SIZE, *offset);
	if(size < 0) {
		np_error("dump rules name failed: %d\n", size);
		return 0;
	}

	np_debug("offset: %lu, size: %d\n", (unsigned long)*offset, size);
	*offset += size;
	return size;
}

static const struct file_operations dump_ops = {
	.owner		= THIS_MODULE,
	.open		= nproto_open,
	.release	= nproto_release,
	.write		= nproto_dump_wr,
	.read		= nproto_dump_rd,
};

int nproto_proc_init(void)
{
	struct proc_dir_entry *dir, *file;

	mutex_init(&io_lock);
	/* create proc dir */
	if(nproto_proc_dir) {
		np_error("re-inited ...\n");
		return -EINVAL;
	}
	dir = proc_mkdir(PROC_DNAME_DBG, NULL);
	if(!dir) {
		np_error("create dir failed.\n");
		return -EINVAL;
	}
	file = proc_create_data(PROC_FNAME_DBG, 655, dir, &debug_ops, NULL);
	if(!file) {
		np_error("create debug file failed.\n");
		remove_proc_entry(PROC_DNAME_DBG, NULL);
		return -EINVAL;
	}
	file = proc_create_data(PROC_FNAME_DUMP, 655, dir, &dump_ops, NULL);
	if(!file) {
		np_error("create dump file failed.\n");
		remove_proc_entry(PROC_FNAME_DBG, nproto_proc_dir);
		remove_proc_entry(PROC_DNAME_DBG, NULL);
		return -EINVAL;
	}

	nproto_proc_dir = dir;
	return 0;
}

void nproto_proc_exit(void)
{
	remove_proc_entry(PROC_FNAME_DUMP, nproto_proc_dir);
	remove_proc_entry(PROC_FNAME_DBG, nproto_proc_dir);
	remove_proc_entry(PROC_DNAME_DBG, NULL);
}
