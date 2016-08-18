#include <linux/netfilter.h>
#include <net/sock.h>
#include <rule_table.h>
#include "nacs_ipc.h"
#include "nacs_table.h"
#include "nacs_debug.h"

static int do_ac_set_ctl(struct sock *sk, int cmd, void __user *user, unsigned int len)
{
	int ret = 0;

	printk(KERN_WARNING "do_ac_set_ctl");
	if (!ns_capable(sock_net(sk)->user_ns, CAP_NET_ADMIN)) {
		NACS_WARN("unpermmited request:cmd[%i]\n", cmd);
		printk(KERN_WARNING "unpermmited request:cmd[%i]\n", cmd);
		return -EPERM;
	}
	printk(KERN_WARNING "do_ac_set_ctl %i\n", cmd);
	switch (cmd) {
	case AC_SO_SET_REPLACE_TABLE:
		ret = do_replace_table(user, len);
		break;

	case AC_SO_SET_REPLACE_SET:
		ret = do_replace_set(user, len);
		break;

	default:
		NACS_WARN("unknown request:cmd=[%i]\n", cmd);
		ret = -EINVAL;
	}

	return ret;
}


static int do_ac_get_ctl(struct sock *sk, int cmd, void __user *user, int *len)
{
	int ret = 0;

	if (!ns_capable(sock_net(sk)->user_ns, CAP_NET_ADMIN)) {
		NACS_WARN("unpermmited request:cmd[%i]\n", cmd);
		return -EPERM;
	}

	switch (cmd) {
	case AC_SO_GET_TABLE_INFO:
		ret = do_get_table_info(user, len);
		break;

	case AC_SO_GET_SET_INFO:
		ret = do_get_set_info(user, len);
		break;

	case AC_SO_GET_ENTRIES:
		ret = do_get_entries(user, len);
		break;

	case AC_SO_GET_SETS:
		ret = do_get_sets(user, len);
		break;

	default:
		NACS_WARN("unknown request:cmd=[%i]\n", cmd);
		ret = -EINVAL;
	}

	return ret;
}


/*sockopt:communicate with userspace*/
static struct nf_sockopt_ops ac_sockopts = {
	.pf			= PF_INET,
	.set_optmin	= AC_SO_BASE_CTL,
	.set_optmax	= AC_SO_SET_MAX + 1,
	.set		= do_ac_set_ctl,
	.get_optmin	= AC_SO_BASE_CTL,
	.get_optmax	= AC_SO_GET_MAX + 1,
	.get		= do_ac_get_ctl,
};


int nacs_ipc_init(void)
{
	int ret = -1;

	/* Register setsockopt */
	ret = nf_register_sockopt(&ac_sockopts);
	if (ret < 0) {
		NACS_ERROR("Unable to register sockopts.\n");
		return ret;
	}
	NACS_INFO("nacs_ipc_init [base_cmd=%d] success\n", AC_SO_BASE_CTL);
	return ret;
}


void nacs_ipc_fini(void)
{
	nf_unregister_sockopt(&ac_sockopts);
	NACS_INFO("nacs_ipc_fini success\n");
}