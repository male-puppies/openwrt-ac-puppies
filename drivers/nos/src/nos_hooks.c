#include "nos.h"
#include "nos_debug.h"

#define DRV_VERSION	"0.1.1"
#define DRV_DESC	"nos package mangle & auth driver"

static unsigned int nodes_usage_expamples(struct nos_track* nos, struct sk_buff* skb)
{
	unsigned int ret = NF_ACCEPT;
	void *priv;

	struct nos_flow_info *flow = nos_get_flow_info(nos);
	struct nos_user_info *user = nos_get_user_info(nos);
	struct nos_user_info *peer = nos_get_peer_info(nos);

	if(!flow || !user || !peer) {
		goto __finished;
	}

	/* example of debug show flow */
	if(net_ratelimit()){
		loginfo("FLOW "FMT_FLOW_STR"\n", FMT_FLOW(flow));
	}

	priv = nos_flow_info_priv(flow);
	/* 140 bytes you can use */

	priv = nos_user_info_priv(user);
	/* 200 bytes you can use */

	priv = nos_user_info_priv(peer);
	/* 200 bytes you can use */


__finished:
	return ret;
}

static unsigned int nos_hook_fw(const struct nf_hook_ops *ops, 
		struct sk_buff *skb,
		const struct net_device *in,
		const struct net_device *out, 
		int (*okfn)(struct sk_buff *))
{
	unsigned int res = NF_ACCEPT;
	
	struct nf_conn *ct;
	struct iphdr *iph;
	struct sk_buff *linear_skb = NULL, *use_skb = NULL;
	enum ip_conntrack_info ctinfo;

	struct nos_track* nos;
	
	ct = nf_ct_get(skb, &ctinfo);
	if (!ct) {
		//NOS_DBG("null ct.\n");
		return NF_ACCEPT;
	}

	if(nf_ct_is_untracked(ct)) {
		//NOS_DBG("untracked ct.\n");
		return NF_ACCEPT;
	}

	//TCP, UDP, ICMP, supported.
	iph = ip_hdr(skb);
	if ((iph->protocol != IPPROTO_TCP) 
		&& (iph->protocol != IPPROTO_UDP) 
		&& (iph->protocol != IPPROTO_ICMP)) {
		return NF_ACCEPT;
	}

	//loopback, lbcast filter.
	if (ipv4_is_lbcast(iph->saddr) || 
		ipv4_is_lbcast(iph->daddr) ||
			ipv4_is_loopback(iph->saddr) || 
			ipv4_is_loopback(iph->daddr) ||
			ipv4_is_multicast(iph->saddr) ||
			ipv4_is_multicast(iph->daddr) || 
			ipv4_is_zeronet(iph->saddr) ||
			ipv4_is_zeronet(iph->daddr))
	{
		return NF_ACCEPT;
	}

	//这里如果不线性化检查, OUTPUT抓取的数据包, 数据区可能为空.
	if(skb_is_nonlinear(skb)) {
		linear_skb = skb_copy(skb, GFP_ATOMIC);
		if (linear_skb == NULL) {
			NOS_DBG("skb cpy linear failed.\n");
			return NF_ACCEPT;
		}
		use_skb = linear_skb;
	} else {
		use_skb = skb;
	}

	nos = nos_track_get(ct);
	if (!nos) {
		//模块调试, 插入时该连接已经无法跟踪了.
		NOS_DBG("flow track node not found.");
		goto __failed_out;
	}

	/* 存取flow & user & peer 节点 */
	res = nodes_usage_expamples(nos, use_skb);

__failed_out:
	if(linear_skb) {
		kfree_skb(linear_skb);
	}

	return res;
}

static struct nf_hook_ops nos_nf_hook_ops[] = {
	{
		.hook = nos_hook_fw,
		.owner = THIS_MODULE,
		.pf = NFPROTO_IPV4,
		.hooknum = NF_INET_FORWARD,
		.priority = NF_IP_PRI_LAST,
	},
};

static int __init nos_module_init(void)
{
	int ret = 0;

	ret = nos_sysfs_register();
	if (ret != 0) {
		goto cleanup_global;
	}
	
	ret = nf_register_hooks(nos_nf_hook_ops, ARRAY_SIZE(nos_nf_hook_ops));
	if (ret != 0) {
		logerr("nf_register_hook failed: %d\n", ret);
		goto unregister_sysfs;
	}

	loginfo("nos_init() OK\n");
	return 0;

unregister_sysfs:
	nos_sysfs_unregister();
cleanup_global:
	return ret;
}

static void __exit nos_module_fini(void)
{
	nos_sysfs_unregister();
	nf_unregister_hooks(nos_nf_hook_ops, ARRAY_SIZE(nos_nf_hook_ops));
	loginfo("nos_fini() OK\n");
}

module_init(nos_module_init);
module_exit(nos_module_fini);

MODULE_DESCRIPTION(DRV_DESC);
MODULE_VERSION(DRV_VERSION);
MODULE_AUTHOR("Gabor Juhos <juhosg@openwrt.org>");
MODULE_LICENSE("GPL v2");
