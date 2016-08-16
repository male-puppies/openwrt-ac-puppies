#include <linux/err.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include "rule_table.h"
#include "nacs_ipc.h"
#include "nacs_table.h"
#include "nacs_debug.h"


static int __init nacs_init(void)
{
	if (nacs_table_init() < 0) {
		NACS_ERROR("nacs_table_init failed\n");
		goto failed;
	}

	if (nacs_ipc_init() < 0) {
		NACS_ERROR("nac_ipc_init failed\n");
		goto failed;
	}

	NACS_INFO("nacs_init success\n");
	return 0;
	
failed:
	nacs_table_fini();
	NACS_INFO("nacs_init failed\n");
	return -1;
}


static void __exit nacs_fini(void)
{
	nacs_ipc_fini();
	nacs_table_fini();
	NACS_INFO("nacs_fini successs\n");
}

module_init(nacs_init);
module_exit(nacs_fini);

MODULE_DESCRIPTION("nacs");
MODULE_VERSION("1.0");
MODULE_AUTHOR("Ivan <itgb1989@gmail.com>");
MODULE_LICENSE("GPL v2");
