#include "nos.h"
#include "nos_debug.h"

static struct mutex nos_sysfs_mutex;

/* ---------------------------------------- start timer ------------------------------------------- */
void nos_timer_func(unsigned long data)
{
	mod_timer(&g_nos.timer.ktimer, jiffies + 30*NOS_TIMER_INTERVAL);
}

void nos_timer_init(struct nos_timer *timer)
{
	timer->jiffies = jiffies; 

	setup_timer(&timer->ktimer, nos_timer_func, 0);
	mod_timer(&timer->ktimer, jiffies + NOS_TIMER_INTERVAL);
}

void nos_timer_cleanup(struct nos_timer *timer)
{
	del_timer_sync(&timer->ktimer);
}

/* ---------------------------------------- start user ------------------------------------------- */
int check_dir(const char *inname, const char *outname) {
	if (!inname || !outname)
		return 0;
	if (!strncmp(inname, "br-lan", 6) && !strncmp(outname, "eth0.5", 6))
		return 1;
	return 0;
}
static void user_hash_init(void)
{
	unsigned int i;  
	for (i = 0; i < NOS_MAX_USER; i++) {
		INIT_HLIST_HEAD(&g_nos.users[i]);
	}
}

static void user_hash_fini(void)
{
	unsigned int i;  
	for (i = 0; i < NOS_MAX_USER; i++) { 
		struct user_node *p, *tmp; 
		struct hlist_head *bkt = &g_nos.users[i];
		hlist_for_each_entry_safe(p, tmp, bkt, node) { 
			hlist_del(p);
			kfree(p); 
		}
	}
}

static inline uint32_t hash_num(void *mac)
{
	return jhash(mac, ETH_ALEN, 0) % NOS_MAX_USER;
}

struct user_node *user_hash_find(void *mac) 
{
	struct user_node *p = NULL;
	struct hlist_head *bkt = NULL;
	bkt = &g_nos.users[hash_num(mac)];
	hlist_for_each_entry(p, bkt, node) {
		if (!memcmp(p->mac, mac, ETH_ALEN)) {
			return p;
		}
	}
	return NULL;
}

int user_hash_add(struct user_node *n)
{
	if (user_hash_find(n->mac)) {
		return 0;
	}

	hlist_add_head(n, &g_nos.users[hash_num(n->mac)]);
	return 1;
}

static int user_hash_del(void *mac) 
{
	struct user_node *p, *tmp; 
	struct hlist_head *bkt;
	if (!user_hash_find(mac)) {
		return 0;
	}
	
	bkt = &g_nos.users[hash_num(mac)];
	hlist_for_each_entry_safe(p, tmp, bkt, node) {
		if (!memcmp(p->mac, mac, ETH_ALEN)) {
			hlist_del(p);
			kfree(p);
			return 1;
		}
	}
	
	BUG_ON(1);
	return 0;
}

static void user_hash_show(void)
{
	unsigned int i;  
	loginfo("show users\n");
	for (i = 0; i < NOS_MAX_USER; i++) { 
		struct user_node *p;
		struct hlist_head *bkt = &g_nos.users[i];
		hlist_for_each_entry(p, bkt, node) {
			loginfo("%u %u %u %u\n", p->mac, p->ip, p->jf, p->status);
		}
	}
}

/* ---------------------------------------- start init and gc ------------------------------------------- */

void nos_global_init(void)
{
	memset(&g_nos, 0, sizeof(g_nos));
	
	spin_lock_init(&g_nos.lock); 
	nos_timer_init(&g_nos.timer);
	
	user_hash_init();
	nos_status_set(NOS_STATUS_RUN);
}

void nos_config_cleanup(struct nos_config *config)
{
	if (!config)
		return;
	//memset(&config, 0, sizeof(struct nos_config));
}
 
void nos_global_set_config(struct nos_config *config) 
{
	nos_config_cleanup(&g_nos.config);
}


void nos_global_cleanup(void)
{
	nos_status_set(NOS_STATUS_STOP);
	nos_timer_cleanup(&g_nos.timer);
	nos_global_set_config(NULL);
	user_hash_fini();
}

static ssize_t nos_sysfs_attr_show(
	struct module_attribute *mattr,
	struct module_kobject *mod,
	char *buf)
{ 
	return sprintf(buf, "tbq status: %s\n", "...");
}

static ssize_t nos_sysfs_attr_store(
	struct module_attribute *mattr,
	struct module_kobject *mod,
	const char *buf,
	size_t count)
{
	int ret;

	mutex_lock(&nos_sysfs_mutex); 
	/* do config update */
	mutex_unlock(&nos_sysfs_mutex);

	return ret < 0 ? ret : count;
}

static struct module_attribute nos_sysfs_attr =
	__ATTR(auth, 0644, nos_sysfs_attr_show, nos_sysfs_attr_store);

int nos_sysfs_register(void)
{
	mutex_init(&nos_sysfs_mutex); 
	return sysfs_create_file(&THIS_MODULE->mkobj.kobj, &nos_sysfs_attr.attr);
}

void nos_sysfs_unregister(void)
{
	sysfs_remove_file(&THIS_MODULE->mkobj.kobj, &nos_sysfs_attr.attr);    
}

char nos_version[] = "0.9.0";
module_param_string(version, nos_version, sizeof(nos_version), 0400);
