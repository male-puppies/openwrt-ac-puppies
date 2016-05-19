#include <linux/module.h>
#include <linux/vmalloc.h>
#include <linux/netfilter.h>
#include <linux/ip.h>

#include <linux/netfilter/xt_set.h>

#include <net/ip.h>
#include <net/netfilter/nf_conntrack.h>

#include <ntrack_auth.h>
#include <ntrack_log.h>

#include "nxjson.h"

void ntrack_conf_free(G_AUTHCONF_t *conf)
{
	/* FIXME: rcu need */
	synchronize_rcu();
	vfree(conf);
}

static G_AUTHCONF_t *G_AuthConf = NULL;
int ntrack_conf_sync(char *conf_str)
{
	int i, j;
	auth_rule_t rule;
	struct ip_set *set;
	ip_set_id_t idx;
	const nx_json *json = NULL, *node;
	G_AUTHCONF_t *conf_tmp;

	conf_tmp = vmalloc(sizeof(G_AUTHCONF_t));
	if(!conf_tmp) {
		nt_error("vmalloc failed.\n");
	}
	memset(conf_tmp, 0, sizeof(G_AUTHCONF_t));

	json = nx_json_parse_utf8(conf_str);
	if (!json || (json && json->type != NX_JSON_ARRAY)) {
		nt_error("parse json failed or not array.\n");
		return -EINVAL;
	}

	i = 0;
	while((node = nx_json_item(json, i++)) != NULL) {
		const nx_json *str, *sets, *flags;

		if (node->type == NX_JSON_NULL) {
			break;
		}
		memset(&rule, 0, sizeof(rule));
		if (node->type != NX_JSON_OBJECT) {
			nt_error("conf item not obj[%d].\n", node->type);
			continue;
		}
		
		/* ipset sets */
		sets = nx_json_get(node, "IPSets");
		if (sets->type != NX_JSON_ARRAY) {
			nt_error("ipsets nil or not string[].\n");
			continue;
		}

		/* fill name */
		str = nx_json_get(node, "Name");
		if(str->type == NX_JSON_STRING) {
			strncpy(rule.name, str->text_value, RULE_NAME_SIZE);
		}

		/* apply sets. */
		j = 0;
		while((str = nx_json_item(sets, j++)) != NULL) {
			if(str->type == NX_JSON_NULL) {
				break;
			}
			if(str->type != NX_JSON_STRING) {
				nt_error("name nil or not string.\n");
				continue;
			}
			idx = ip_set_get_byname(&init_net, str->text_value, &set);
			if (idx == IPSET_INVALID_ID) {
				nt_error("ipset[%s] not found.\n", str->text_value);
				continue;
			}
			nt_info("ipset[%s] add to rule[%s]\n", str->text_value, rule.name);

			rule.uset_idx[rule.num_idx] = idx;
			rule.num_idx ++;
			if(rule.num_idx > MAX_USR_SET) {
				nt_error("ipset rule num overflow.\n");
				break;
			}
		}

		/* get Redirect flags */
		flags = nx_json_get(node, "Flags");
		if(flags->type == NX_JSON_INTEGER) {
			rule.flags = flags->int_value;
		} else {
			nt_error("rule: %i, flag type error.\n", i);
		}
		rule.magic = jiffies;

		/* save rule to Global configure. */
		if (rule.num_idx) {
			nt_info("rule:[%s], num: %d idx0: %d valid added.\n", 
				rule.name, rule.num_idx, rule.uset_idx[0]);
			conf_tmp->rules[conf_tmp->num_rules] = rule;
			conf_tmp->num_rules ++;
			if(conf_tmp->num_rules > MAX_URL_RULES) {
				nt_error("rules overflow.\n");
				break;
			}
		}
	}
	nt_info("num rules: %d set.\n", conf_tmp->num_rules);

	if(G_AuthConf) {
		G_AUTHCONF_t *tmp = G_AuthConf;
		rcu_assign_pointer(G_AuthConf, NULL);
		ntrack_conf_free(tmp);
	}
	rcu_assign_pointer(G_AuthConf, conf_tmp);

	nx_json_free(json);
	return 0;
}

/* ipset hash:ip hash:mac check src address from skb. */
int ntrack_user_match(user_info_t *ui, struct sk_buff *skb)
{
	int ret = 0, i, j;
	struct ip_set_adt_opt opt;
	struct xt_action_param par;
	struct net_device *indev, *dev;
	struct iphdr *iph;
	// const struct xt_set_info *set = (const void *) em->data;

	G_AUTHCONF_t *conf = rcu_dereference(G_AuthConf);
	if(!conf) {
		return 0;
	}

	if(!conf->num_rules) {
		return 0;
	}

	iph = ip_hdr(skb);
	if(l3filter(iph)) {
		return 0;
	}

	// memset(&par, 0, sizeof(par));
	// memset(&opt, 0, sizeof(opt));

	par.family = NFPROTO_IPV4;
	par.thoff = ip_hdrlen(skb);
	par.hooknum = 0;
#if (LINUX_VERSION_CODE > KERNEL_VERSION(3,18,20))
	par.net = &init_net;
#endif

	opt.family = par.family;
	opt.dim = IPSET_DIM_THREE;
	opt.flags = IPSET_DIM_ONE_SRC;
	opt.cmdflags = 0;
	opt.ext.timeout = ~0u;

	rcu_read_lock();
	dev = skb->dev;
	if (dev && skb->skb_iif)
		indev = dev_get_by_index_rcu(dev_net(dev), skb->skb_iif);

	/* conntrack init (pre routing) */
	par.in      = indev ? indev : dev;
	par.out     = dev;

	/* find addr & do match */
	for (i = 0; i < conf->num_rules; ++i) {
		auth_rule_t *rule = &conf->rules[i];
		for (j = 0; j < rule->num_idx; ++j) {
			ret = ip_set_test(rule->uset_idx[j], skb, &par, &opt);
			if (ret) {
				ui->hdr.group_id = -1; /* set user mark for group identity */
				ui->hdr.rule_idx = i;
				ui->hdr.rule_magic = rule->magic;
				nt_debug("[%pI4] ipset [%s] match: %d\n", &ui->ip, rule->name, ret);
				goto __matched;
			}
			// nt_debug("no match: [%s] %pI4 -> %pI4\n", rule->name, &iph->saddr, &iph->daddr);
		}
	}

__matched:
	rcu_read_unlock();
	return ret; //not user
}

static inline auth_rule_t *user_get_rule(user_info_t *ui, G_AUTHCONF_t *conf)
{
	int8_t idx = ui->hdr.rule_idx;

	if(idx >= conf->num_rules) {
		nt_error("idx: %d overflow vs rule num: %d\n", idx, conf->num_rules);
		return NULL;
	}
	return &conf->rules[idx];
}

int user_need_redirect(user_info_t *ui, struct sk_buff *skb)
{
	int ret;
	G_AUTHCONF_t *conf = rcu_dereference(G_AuthConf);
	auth_rule_t *rule;

	if(!conf) {
		nt_debug("url conf not found.\n");
		return 0;
	}

	if(conf->num_rules <= 0) {
		nt_debug("ipset nil rule.\n");
		return 0;
	}

	if(!ui->hdr.rule_magic) {
		/* ipset not matched yet */
		if(!ntrack_user_match(ui, skb)) {
			nt_warn("nil magic, not match user.\n");
			return 0;
		}
	} 
	rule = user_get_rule(ui, conf);

	/* check rule magic */
	if(ui->hdr.rule_magic != rule->magic) {
		nt_warn("ipset conf updated re-match.\n");
		if(!ntrack_user_match(ui, skb)) {
			nt_warn("invalid magic, re-match failed.\n");
			return 0;
		}
		rule = user_get_rule(ui, conf);
	}

	/* redirect rule found> ? */
	if(!rule) {
		nt_error(FMT_USER_STR" nil rule matched.\n", FMT_USER(ui));
		return 0;
	}

	/* check ui auth status */
	if (nt_auth_status(ui) <= AUTH_REQ) {
		if (rule->flags) {
			nt_auth_set_status(ui, AUTH_REQ);
			return 1;
		} else { /* auto auth */
			nt_auth_set_status(ui, AUTH_OK);
			return 0;
		}
	}

	return 0;
}

/* config netlink sockets */
static struct sock *nl_sock = NULL;
struct {
    __u32 pid;
}user_process;

void nl_recv(struct sk_buff *__skb)
{
	struct sk_buff *skb;
	struct nlmsghdr *nlh = NULL;
	char *json_str = NULL;

	skb = skb_get(__skb);

	if(skb->len >= sizeof(struct nlmsghdr)){
        nlh = (struct nlmsghdr *)skb->data;
        if(NLMSG_OK(nlh, __skb->len)) {
        	int len = nlh->nlmsg_len - NLMSG_HDRLEN;
            user_process.pid = nlh->nlmsg_pid;
            json_str = ((char *)kzalloc((len + 1) * sizeof(char), GFP_NOWAIT));
            if (!json_str) {
                goto finish;
            }
            nt_info("pid: %d, dlen=%d\n", user_process.pid, len);
            memcpy(json_str, (char *)NLMSG_DATA(nlh), len);
			ntrack_conf_sync(json_str);
        }
    }

finish:
	if(json_str){
		kfree(json_str);
	}
	kfree_skb(skb);
}

int ntrack_conf_init(void)
{
	struct netlink_kernel_cfg cfg = {
		.input	= nl_recv,
	};

	nl_sock = netlink_kernel_create(&init_net, NETLINK_NTRACK, &cfg);
	if(!nl_sock) {
		nt_error("netlink create failed.\n");
		return -EINVAL;
	}

	return 0;
}

void ntrack_conf_exit(void)
{
	if (nl_sock) {
		netlink_kernel_release(nl_sock);
	}
}
