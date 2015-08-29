#include "nos.h"
#include "nos_debug.h"

static struct mutex nos_sysfs_mutex;

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
	__ATTR(tbq, 0644, nos_sysfs_attr_show, nos_sysfs_attr_store);

int nos_sysfs_register(void)
{
	mutex_init(&nos_sysfs_mutex);
	return sysfs_create_file(&THIS_MODULE->mkobj.kobj, &nos_sysfs_attr.attr);
}

void nos_sysfs_unregister(void)
{
}

char nos_version[] = "0.9.0";
module_param_string(version, nos_version, sizeof(nos_version), 0400);
