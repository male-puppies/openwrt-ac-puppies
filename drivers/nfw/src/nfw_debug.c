#include <linux/proc_fs.h>

#include "nfw_private.h"

#define DRIVER_NAME "nfw"
typedef struct {

	struct proc_dir_entry *proc;
} nfw_debug_t;

static nfw_debug_t GDBG;
int nfw_dbg_init(void)
{
	/* create proc dir */
	if(GDBG.proc) {
		fw_error("re-inited ...\n");
		return -EINVAL;
	}
	GDBG.proc = proc_mkdir(DRIVER_NAME, NULL);
	
}