#include "tbq.h"
#include "nxjson.h"


enum {
	TBQ_CMD_NONE = 0,
	TBQ_CMD_ENABLE,
	TBQ_CMD_DISABLE,
};

static int tbq_rule_match_app(const struct tbq_rule *rule, uint16_t app)
{
	int i;

	if (rule->nr_app_rule == 0)
		return 1;

	for (i = 0; i < rule->nr_app_rule; i++) {
		if (app == rule->app_rules[i])
			return 1;
	}

	return 0;
}

uint32_t tbq_app_match(uint16_t app, uint32_t all_mask, uint8_t *weight)
{
	uint32_t rule_mask = 0;
	int i;

	TBQ_RULE_MASK_FOR_EACH(i, all_mask) {
		const struct tbq_rule *rule = &tbq.config.rules[i];
		weight[i] = tbq_rule_match_app(rule, app);
		if (weight[i] != 0) {
			TBQ_RULE_MASK_SET(rule_mask, i);
		}
	}

	return rule_mask;
}

static void tbq_rule_cleanup(struct tbq_rule *rule)
{
	kfree(rule->name);
	kfree(rule->wan_rules);
	kfree(rule->ip_rules);
	kfree(rule->app_rules);
	memset(rule, 0, sizeof(struct tbq_rule));
}

void tbq_config_cleanup(struct tbq_config *config)
{
	int i;

	for (i = 0; i < config->nr_rule; i++) {
		tbq_rule_cleanup(&config->rules[i]);
	}

	kfree(config->rules);

	memset(config, 0, sizeof(struct tbq_config));
}

static void tbq_rule_dump(struct tbq_rule *rule)
{
	int i;

	TBQ_INFO("~~~~~~~~~ TBQ RULE [%s] ~~~~~~~~~\n", rule->name);

	for (i = 0; i < rule->nr_ip_rule; i++) {
		struct tbq_ip_rule *ip_rule = &rule->ip_rules[i];
		TBQ_INFO("ip rule %d: [%pI4h, %pI4h], weight: %u\n",
			i, &ip_rule->min, &ip_rule->max, ip_rule->weight);
	}

	for (i = 0; i < rule->nr_app_rule; i++) {
		uint16_t app = rule->app_rules[i];
		TBQ_INFO("app rule %d: %u\n", i, (uint32_t)app);
	}

	for (i = 0; i < 2; i++) {
		const char *dir = i == 0 ? "out" : "in";
		struct tbq_token_rule *tr = &rule->token_rules[i];
		TBQ_INFO("global %s tokens_per_jiffy: %d\n", dir, tr->global.tokens_per_jiffy);
		TBQ_INFO("user   %s tokens_per_jiffy: %d\n", dir, tr->user.tokens_per_jiffy);
	}
}

static void tbq_config_dump(struct tbq_config *config)
{
	int i;

	TBQ_INFO("--------------- TBQ CONFIG ---------------\n");

	for (i = 0; i < config->nr_rule; i++) {
		tbq_rule_dump(&config->rules[i]);
	}

	TBQ_INFO("max_backlog_packets:	%u\n", config->max_backlog_packets);
	TBQ_INFO("latency_shift:		%u\n", config->latency_shift);
	TBQ_INFO("disable_timeout:		%u\n", config->disable_timeout);

	TBQ_INFO("------------------------------------------\n");
}

static int tbq_nxjson_verify(const nx_json *js_root)
{
	const nx_json *js;
	int i;

	if (js_root->length < 0) {
		TBQ_ERROR("nxjson bug, js.length < 0: %d\n", js_root->length);
		return -1;
	}

	switch (js_root->type) {
	case NX_JSON_ARRAY:
	case NX_JSON_OBJECT:
		i = 0;
		for (js = js_root->child; js != NULL; js = js->next) {
			i++;
			if (tbq_nxjson_verify(js) != 0)
				return -1;
		}
		if (i != js_root->length) {
			TBQ_ERROR("nxjson bug, js.length mismatch: %d/%d\n",
				i, js_root->length);
			return -1;
		}
		break;
	default:
		// TODO: check other type
		break;
	}

	return 0;
}

static int tbq_json_string_map(
	char **res, const nx_json *j_string,
	const char *name, int max_length)
{
	int len;

	*res = NULL;

	if (j_string->type == NX_JSON_NULL) {
		TBQ_INFO("%s not set\n", name);
		len = 0;
		goto copy;
	}

	if (j_string->type != NX_JSON_STRING) {
		TBQ_ERROR("%s is not string\n", name);
		return -1;
	}

	len = (int)strlen(j_string->text_value);
	if (len > max_length) {
		TBQ_ERROR("%s.length == %d, out of range: [0, %d]\n",
			name, len, max_length);
		return -1;
	}

copy:
	*res = TBQ_NEW_N(char, len + 1);
	if (*res == NULL) {
		TBQ_ERROR("%s.length == %d, out of memory\n", name, len);
		return -1;
	}

	memcpy(*res, j_string->text_value, len);
	(*res)[len] = 0;
	return 0;
}

static int tbq_json_integer_map(
	long *res, const nx_json *j_integer,
	const char *name, long min, long max)
{
	*res = 0;

	if (j_integer->type == NX_JSON_NULL) {
		TBQ_INFO("%s not set\n", name);
		return 0;
	}

	if (j_integer->type != NX_JSON_INTEGER) {
		TBQ_ERROR("%s is not integer\n", name);
		return -1;
	}

	if (j_integer->int_value < min || j_integer->int_value > max) {
		TBQ_ERROR("%s == %ld, out of range: [%ld, %ld]\n",
			name, j_integer->int_value, min, max);
		return -1;
	}

	*res = j_integer->int_value;
	return 0;
}

static int tbq_json_array_map(
	void **res,
	int *nr_res,
	const nx_json *j_array,
	const char *name,
	int max_length,
	int elem_size,
	int (* elem_ctor)(void *elem, const nx_json *js),
	void (* elem_dtor)(void *elem))
{
	const nx_json *js;
	char *array;
	int i;

	*res = NULL;
	*nr_res = 0;

	if (j_array->type == NX_JSON_NULL) {
		TBQ_INFO("%s not set\n", name);
		return 0;
	}

	if (j_array->type != NX_JSON_ARRAY) {
		TBQ_ERROR("%s is not array\n", name);
		return -1;
	}

	if (j_array->length > max_length) {
		TBQ_ERROR("%s.length == %d, out of range: [0, %d]\n",
			name, j_array->length, max_length);
		return -1;
	}

	if (j_array->length == 0) {
		TBQ_INFO("%s is empty\n", name);
		return 0;
	}

	array = kzalloc(elem_size * j_array->length, GFP_KERNEL);
	if (array == NULL) {
		TBQ_ERROR("%s.length == %d, out of memory\n", name, j_array->length);
		return -1;
	}

	i = 0;
	for (js = j_array->child; js != NULL; js = js->next, i++) {
		if (elem_ctor(array + i * elem_size, js) != 0) {
			TBQ_ERROR("%s[%d] init failed, total: %d\n", name, i, j_array->length);
			if (elem_dtor != NULL) {
				while (--i >= 0) {
					elem_dtor(array + i * elem_size);
				}
			}
			kfree(array);
			return -1;
		}
	}

	*res = array;
	*nr_res = j_array->length;
	return 0;

}

#define tbq_json_array_map(res, nr_res, j_array, name, max_length, elem_type, ctor, dtor) \
	((void)(*(res) == (elem_type *)NULL), \
		(void)((ctor) == (int (*)(elem_type *, const nx_json *))NULL), \
		(void)((dtor) == (void (*)(elem_type *))NULL), \
		tbq_json_array_map((void **)(res), (nr_res), (j_array), \
			(name), (max_length), sizeof(elem_type), \
			(int (*)(void *, const nx_json *))(ctor), \
			(void (*)(void *))(dtor)))

static int tbq_str_to_ip(const char *str, uint32_t *ip)
{
	unsigned int a,b,c,d;
	char tmp;

	if (sscanf(str, "%u.%u.%u.%u %c", &a, &b, &c, &d, &tmp) != 4 ||
		a > 255 || b > 255 || c > 255 || d > 255) {
		*ip = 0;
		return -1;
	}

	*ip = (a << 24) | (b << 16) | (c << 8) | d;
	return 0;
}

static int tbq_str_to_weight(
	const char *str,
	uint32_t *weight,
	uint32_t min,
	uint32_t max)
{
	char tmp;

	if (sscanf(str, "%u %c", weight, &tmp) != 1) {
		TBQ_ERROR("bad weight: [%s]\n", str);
		return -1;
	}
	if (*weight < min || *weight > max) {
		TBQ_ERROR("weight == %u, out of range: [%u, %u]\n", *weight, min, max);
		return -1;
	}
	return 0;
}

static int tbq_ip_rule_init(struct tbq_ip_rule *ip_rule, const nx_json *js)
{
	int ret = -1;
	char *ip_desc;
	char *p;

	if (tbq_json_string_map(&ip_desc, js,
			"config.Rules[n].IpInclude[n]", 256) != 0) {
		return -1;
	}

	p = strrchr(ip_desc, ':');
	if (p == NULL) {
		ip_rule->weight = 1;
	} else {
		*p = 0;
		if (tbq_str_to_weight(p + 1, &ip_rule->weight, 1, TBQ_DRR_WEIGHT_MAX) != 0)
			goto out;
	}

	p = strchr(ip_desc, '-');
	if (p == NULL) {
		if (tbq_str_to_ip(ip_desc, &ip_rule->min) != 0) {
			TBQ_ERROR("bad ip: [%s]\n", ip_desc);
			goto out;
		}
		ip_rule->max = ip_rule->min;
		TBQ_INFO("\"%s\" => \"%pI4h - %pI4h\"\n",
			ip_desc, &ip_rule->min, &ip_rule->max);
	} else {
		*p = 0;
		if (tbq_str_to_ip(ip_desc, &ip_rule->min) != 0) {
			TBQ_ERROR("bad ip: [%s]\n", ip_desc);
			goto out;
		}
		if (tbq_str_to_ip(p + 1, &ip_rule->max) != 0) {
			TBQ_ERROR("bad ip: [%s]\n", p + 1);
			goto out;
		}
		if (ip_rule->min > ip_rule->max) {
			swap(ip_rule->min, ip_rule->max);
			TBQ_WARN("IpMin > IpMax, swapped to: %pI4h - %pI4h\n",
				&ip_rule->min, &ip_rule->max);
		}
		TBQ_INFO("\"%s-%s\" => \"%pI4h - %pI4h\"\n",
			ip_desc, p + 1, &ip_rule->min, &ip_rule->max);
	}

	ret = 0;
out:
	kfree(ip_desc);
	return ret;
}

static int tbq_app_rule_init(uint16_t *app_rule, const nx_json *js)
{
	long app_id;

	if (tbq_json_integer_map(&app_id, js,
			"config.Rules[n].AppRules[n]",
			0, 256) != 0) {
		return -1;
	}

	*app_rule = app_id;
	return 0;
}

static int tbq_token_config_init(
	struct tbq_token_config *tc,
	const nx_json *js)
{
	int ret;
	char *desc = NULL;
	unsigned long long bytes_per_sec;
	char unit;
	char tmp;

	if (tbq_json_string_map(&desc, js, "RateLimit", 64) != 0) {
		ret = -1;
		goto out;
	}

	ret = sscanf(desc, "%llu %c %c", &bytes_per_sec, &unit, &tmp);
	if (ret != 2) {
		TBQ_ERROR("bad rate limit: [%s]\n", desc);
		ret = -1;
		goto out;
	}

#define CHECK_OVERFLOW() \
do { \
	if (bytes_per_sec > TBQ_BYTES_PER_SEC_MAX) { \
		TBQ_ERROR("rate limit [%s] out of range: [0, %u]\n", \
			desc, TBQ_BYTES_PER_SEC_MAX); \
		ret = -1; \
		goto out; \
	} \
} while (0)

#define MUL() \
do { \
	bytes_per_sec *= 1000; \
	CHECK_OVERFLOW(); \
} while (0)

	CHECK_OVERFLOW();

	switch (unit) {
	case 'G':
		MUL();
	case 'M':
		MUL();
	case 'K':
		MUL();
		break;
	default:
		TBQ_ERROR("bad rate limit: [%s]\n", desc);
		ret = -1;
		goto out;
	}

#undef MUL
#undef CHECK_OVERFLOW

	if (bytes_per_sec == 0) {
		bytes_per_sec = TBQ_BYTES_PER_SEC_MAX;
	}

	TBQ_DEBUG("rate limit [%s] => %llu bytes per sec\n", desc, bytes_per_sec);
	tc->tokens_per_jiffy = (int32_t)bytes_per_sec / HZ;
	ret = 0;
out:
	kfree(desc);
	return ret;
}

static int tbq_token_rule_init(
	struct tbq_token_rule *token_rule,
	const nx_json *js)
{
	if (js->type == NX_JSON_NULL) {
		TBQ_INFO("token_rule not set\n");
		return 0;
	}
	if (js->type != NX_JSON_OBJECT) {
		TBQ_ERROR("token_rule is not object\n");
		return -1;
	}
	if (tbq_token_config_init(&token_rule->global,
			nx_json_get(js, "Shared")) != 0) {
		return -1;
	}
	if (tbq_token_config_init(&token_rule->user,
			nx_json_get(js, "PerIp")) != 0) {
		return -1;
	}
	return 0;
}

static int tbq_rule_init(struct tbq_rule *rule, const nx_json *js)
{
	memset(rule, 0, sizeof(struct tbq_rule));

	if (tbq_json_string_map(&rule->name,
			nx_json_get(js, "Name"),
			"config.Rules[n].Name",
			TBQ_RULE_NAME_MAX) != 0) {
		goto fail;
	}

	if (tbq_json_array_map(&rule->ip_rules, &rule->nr_ip_rule,
			nx_json_get(js, "IpIncluded"),
			"config.Rules[n].IpIncluded",
			TBQ_IP_RULE_COUNT_MAX,
			struct tbq_ip_rule, tbq_ip_rule_init, NULL) != 0) {
		goto fail;
	}

	if (tbq_json_array_map(&rule->app_rules, &rule->nr_app_rule,
			nx_json_get(js, "AppIncluded"),
			"config.Rules[n].AppIncluded",
			TBQ_APP_RULE_COUNT_MAX,
			uint16_t, tbq_app_rule_init, NULL) != 0) {
		goto fail;
	}

	if (tbq_token_rule_init(&rule->token_rules[0],
			nx_json_get(js, "UploadLimit")) != 0) {
		TBQ_ERROR("config.Rules[n].UploadLimit parse failed\n");
		goto fail;
	}

	if (tbq_token_rule_init(&rule->token_rules[1],
			nx_json_get(js, "DownloadLimit")) != 0) {
		TBQ_ERROR("config.Rules[n].DownloadLimit parse failed\n");
		goto fail;
	}

	return 0;

fail:
	tbq_rule_cleanup(rule);
	return -1;
}

static void init_iface(struct tbq_config *config, const nx_json *j_opt, struct tbq_iface *iface)
{

	const char *p = j_opt->text_value, *e = j_opt->text_value + strlen(j_opt->text_value);

	BUG_ON(iface->cur != 0);

	while (p <= e) {
		const char *p2 = strchr(p, '\t');
		if (!p2 || p2 > e || p2 - p <= 0)
			break;

		BUG_ON(iface->cur > TBQ_MAX_IFACE_COUNT || p2 - p >= TBQ_MAX_IFNAME_SIZE);
		memcpy(iface->ifname[iface->cur], p, p2 - p);
		iface->cur++;
		p = p2 + 1;
	}
	/*
	{
		int i = 0;
		for (; i < iface->cur; i++) {
			printk("%d--%s--\n", i, iface->ifname[i]);
		}
	}*/
}

static int tbq_config_init(struct tbq_config *config, const nx_json *js)
{
	const nx_json *j_opt;

	memset(config, 0, sizeof(struct tbq_config));

	if (js->type != NX_JSON_OBJECT) {
		TBQ_ERROR("config is not object\n");
		goto fail;
	}

	j_opt = nx_json_get(js, "LAN");
	if (j_opt->type == NX_JSON_NULL) {
		memcpy(&config->lan, &tbq.config.lan, sizeof(struct tbq_iface));
	} else if (j_opt->type != NX_JSON_STRING) {
		TBQ_ERROR("LAN is not string\n");
		goto fail;
	} else {
		init_iface(config, j_opt, &config->lan);
	}

	j_opt = nx_json_get(js, "WAN");
	if (j_opt->type == NX_JSON_NULL) {
		memcpy(&config->wan, &tbq.config.wan, sizeof(struct tbq_iface));
	} else if (j_opt->type != NX_JSON_STRING) {
		TBQ_ERROR("WAN is not string\n");
		goto fail;
	} else {
		init_iface(config, j_opt, &config->wan);
	}

	j_opt = nx_json_get(js, "Rules");
	if (j_opt->type == NX_JSON_NULL) {
		config->rules = tbq.config.rules;
		config->nr_rule = tbq.config.nr_rule;
	} else {
		int nr_rule;
		if (tbq_json_array_map(&config->rules, &nr_rule, j_opt, "config.Rules",
			TBQ_RULE_COUNT_MAX, struct tbq_rule, tbq_rule_init, tbq_rule_cleanup) != 0) {
			goto fail;
		}
		config->nr_rule = nr_rule;
	}

#define INIT_UINT_PARAM(field, name, max) \
	j_opt = nx_json_get(js, #name); \
	if (j_opt->type == NX_JSON_NULL) { \
		config->field = tbq.config.field; \
	} else { \
		long value; \
		if (tbq_json_integer_map(&value, j_opt, "config." #name, 0, (max)) != 0) { \
			goto fail; \
		} \
		config->field = value; \
		tbq.config.field = value; \
		TBQ_INFO(#name " set to: %ld\n", value); \
	}

	INIT_UINT_PARAM(max_backlog_packets, MaxBacklogPackets,	TBQ_BACKLOG_PACKETS_MAX)
	INIT_UINT_PARAM(latency_shift,		 LatencyShift,		TBQ_LATENCY_SHIFT_MAX)
	INIT_UINT_PARAM(disable_timeout,	 DisableTimeout,	TBQ_DISABLE_TIMEOUT_MAX)

#undef INIT_UINT_PARAM

	return 0;

fail:
	if (config->rules != tbq.config.rules) {
		tbq_config_cleanup(config);
	}
	return -1;
}

static int tbq_parse_config(struct tbq_config *config, const char *json, size_t size)
{
	int ret = -1;
	char *json_data = NULL;
	const nx_json *js = NULL;

	memset(config, 0, sizeof(struct tbq_config));

	json_data = TBQ_NEW_N(char, size + 1);
	if (json_data == NULL) {
		TBQ_ERROR("tbq_parse_config failed: out of memory\n");
		goto out;
	}

	memcpy(json_data, json, size);
	json_data[size] = 0;

	js = nx_json_parse_utf8(json_data);
	if (js == NULL) {
		TBQ_ERROR("config parse failed\n");
		goto out;
	}

	if (tbq_nxjson_verify(js) != 0) {
		TBQ_ERROR("nxjson verify failed\n");
		goto out;
	}

	if (js->type == NX_JSON_BOOL || js->type == NX_JSON_INTEGER) {
		ret = js->int_value ? TBQ_CMD_ENABLE : TBQ_CMD_DISABLE;
		goto out;
	}

	if (tbq_config_init(config, js) != 0) {
		TBQ_ERROR("tbq_config_init failed\n");
		goto out;
	}

	tbq_config_dump(config);
	ret = 0;
out:
	if (js != NULL) {
		nx_json_free(js);
	}
	if (json_data != NULL) {
		kfree(json_data);
	}
	return ret;
}

static void tbq_enable(void)
{
	BUG_ON(!tbq_status_is(TBQ_STATUS_STOPPED));

	tbq_status_set(TBQ_STATUS_RUNNING);

	TBQ_INFO("tbq enabled\n");
}

static int tbq_disable(void)
{
	int ret;

	BUG_ON(!tbq_status_is(TBQ_STATUS_RUNNING));

	TBQ_INFO("disabling tbq ...\n");
	tbq_status_set(TBQ_STATUS_STOPPING);

	TBQ_INFO("tbq enqueue handlers is disabled\n");
	tbq_status_set(TBQ_STATUS_WAITING_STOP);

	init_completion(&tbq.disable_done);
	ret = wait_for_completion_interruptible_timeout(
		&tbq.disable_done, tbq.config.disable_timeout * HZ);
	if (ret <= 0) {
		if (ret == 0) {
			TBQ_ERROR("disable timeout\n");
			ret = -ETIMEDOUT;
		} else if (ret == -ERESTARTSYS) {
			TBQ_ERROR("disable canceled on signal\n");
		} else {
			TBQ_ERROR("disable failed, unknown error: %d\n", ret);
		}
		// TODO: bug ?
		tbq_status_set(TBQ_STATUS_RUNNING);
		return ret;
	}

	TBQ_INFO("tbq backlog is cleared\n");

	tbq_status_set(TBQ_STATUS_STOPPED);

	TBQ_INFO("tbq disabled\n");

	return 0;
}

static int tbq_reload_config(struct tbq_config *config)
{
	int ret;
	int need_enable = 0;

	BUG_ON(!tbq_status_is(TBQ_STATUS_RUNNING) && !tbq_status_is(TBQ_STATUS_STOPPED));

	TBQ_INFO("reloading tbq ...\n");

	if (tbq_status_is(TBQ_STATUS_RUNNING)) {
		need_enable = 1;
		ret = tbq_disable();
		if (ret != 0) {
			tbq_config_cleanup(config);
			return ret;
		}
	}

	tbq_global_set_config(config);

	if (need_enable) {
		tbq_enable();
	}

	TBQ_INFO("tbq reloaded\n");

	return 0;
}

static int tbq_handle_command(int cmd)
{
	int ret = 0;

	BUG_ON(cmd <= 0);
	BUG_ON(!tbq_status_is(TBQ_STATUS_RUNNING) && !tbq_status_is(TBQ_STATUS_STOPPED));

	switch (cmd) {
	case TBQ_CMD_ENABLE:
		if (tbq_status_is(TBQ_STATUS_RUNNING)) {
			TBQ_INFO("tbq is running\n");
		} else {
			tbq_enable();
		}
		break;
	case TBQ_CMD_DISABLE:
		if (tbq_status_is(TBQ_STATUS_RUNNING)) {
			ret = tbq_disable();
		} else {
			TBQ_INFO("tbq is not running\n");
		}
		break;
	default:
		TBQ_ERROR("unknown tbq cmd: %d\n", cmd);
		ret = -EINVAL;
	}

	return ret;
}

static struct mutex tbq_sysfs_mutex;

static ssize_t tbq_sysfs_attr_show(
	struct module_attribute *mattr,
	struct module_kobject *mod,
	char *buf)
{
	const char *status_desc[TBQ_STATUS_COUNT];
	status_desc[TBQ_STATUS_RUNNING] = "running";
	status_desc[TBQ_STATUS_STOPPED] = "stopped";
	status_desc[TBQ_STATUS_STOPPING] = "stopping";
	status_desc[TBQ_STATUS_WAITING_STOP] = "waiting stop";
	return sprintf(buf, "tbq status: %s\n", status_desc[tbq.status]);
}

static ssize_t tbq_sysfs_attr_store(
	struct module_attribute *mattr,
	struct module_kobject *mod,
	const char *buf,
	size_t count)
{
	int ret;
	struct tbq_config config;

	mutex_lock(&tbq_sysfs_mutex);
	ret = tbq_parse_config(&config, buf, count);
	if (ret == 0 && config.rules != tbq.config.rules) {
		ret = tbq_reload_config(&config);
	} else if (ret > 0) {
		ret = tbq_handle_command(ret);
	}
	BUG_ON(ret > 0);
	mutex_unlock(&tbq_sysfs_mutex);

	return ret < 0 ? ret : count;
}

static struct module_attribute tbq_sysfs_attr =
	__ATTR(tbq, 0644, tbq_sysfs_attr_show, tbq_sysfs_attr_store);

int tbq_sysfs_register(void)
{
	mutex_init(&tbq_sysfs_mutex);
	return sysfs_create_file(&THIS_MODULE->mkobj.kobj, &tbq_sysfs_attr.attr);
}

void tbq_sysfs_unregister(void)
{
	if (tbq_status_is(TBQ_STATUS_RUNNING)) {
		tbq_disable();
	}
}


static int tbq_param_set_uint(const char *valstr, const struct kernel_param *kp)
{
	int (* fn)(uint32_t, char *) = kp->arg;
	uint32_t value;
	char tmp;

	if (sscanf(valstr, "%u %c", &value, &tmp) != 1) {
		size_t len = 0;
		const char *p = strrchr(valstr, '\n');
		if (p == NULL)
			len = strlen(valstr);
		else
			len = p - valstr;
		TBQ_ERROR("bad uint parameter: [%.*s]\n", (int)len, valstr);
		return -EINVAL;
	}

	return fn(value, NULL);
}

static int tbq_param_get_uint(char *valstr, const struct kernel_param *kp)
{
	int (* fn)(uint32_t, char *) = kp->arg;

	return fn(0, valstr);
}

static struct kernel_param_ops tbq_param_ops_uint = {
	.set = tbq_param_set_uint,
	.get = tbq_param_get_uint,
};

#define TBQ_PARAM_UINT(name, min, max) \
static int tbq_param_set_##name(uint32_t value, char *valstr) \
{ \
	if (valstr != NULL) { \
		return sprintf(valstr, "%u", tbq.config.name); \
	} \
	if (value < (min) || value > (max)) { \
		TBQ_ERROR("bad " #name ": %u, out of range: [%d, %d]\n", value, (min), (max)); \
		return -EINVAL; \
	} \
	tbq.config.name = value; \
	TBQ_INFO(#name " set to %u\n", value); \
	return 0; \
} \
module_param_cb(tbq_##name, &tbq_param_ops_uint, tbq_param_set_##name, 0600)

TBQ_PARAM_UINT(max_backlog_packets, 0, TBQ_BACKLOG_PACKETS_MAX);
TBQ_PARAM_UINT(latency_shift, 0, TBQ_LATENCY_SHIFT_MAX);
TBQ_PARAM_UINT(disable_timeout, 0, TBQ_DISABLE_TIMEOUT_MAX);


module_param_named(backlog_packets, tbq.backlog_packets, uint, 0400);

char tbq_version[] = "0.9.0";
module_param_string(version, tbq_version, sizeof(tbq_version), 0400);
