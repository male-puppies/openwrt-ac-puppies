#include <stdlib.h>
#include <string.h>
#include "rule_print.h"
#include "nxjson.h"


#define ALLOC_NEW(type) \
	CALLOC_NEW_N(1, type)

#define CALLOC_NEW_N(n, type) \
	((type *)calloc((n), sizeof(type)))


int nx_json_verify(const nx_json *js_root)
{
	int i;
	const nx_json *js;

	if (js_root->length < 0)
	{
		AC_ERROR("nxjson bug, js.length < 0: %d\n", js_root->length);
		return -1;
	}

	switch (js_root->type) {
	case NX_JSON_ARRAY:
	case NX_JSON_OBJECT:
		{
			i = 0;
			for (js = js_root->child; js != NULL; js = js->next)
			{
				i++;
				if (nx_json_verify(js) != 0)
					return -1;
			}
			if (i != js_root->length)
			{
				AC_ERROR("nxjson bug, js.length mismatch: %d/%d\n",
					i, js_root->length);
				return -1;
			}
			break;
		}
	default:
		// TODO: check other type
		break;
	}

	return 0;
}


int nx_json_integer_map(unsigned int *res, const nx_json *j_integer,
	const char *name, unsigned int min, unsigned int max)
{
	*res = 0;

	if (j_integer->type == NX_JSON_NULL)
	{
		AC_INFO("%s not set.\n", name);
		return 0;
	}

	if (j_integer->type != NX_JSON_INTEGER)
	{
		AC_ERROR("%s is not integer.\n", name);
		return -1;
	}

	if (j_integer->int_value < min || j_integer->int_value > max)
	{
		AC_ERROR("%s == %u, out of range: [%u, %u].\n",
			name, j_integer->int_value, min, max);
		return -1;
	}

	*res = j_integer->int_value;
	return 0;
}


int nx_json_string_map(char **res, const nx_json *j_string,
	const char *name, int max_length)
{
	int len = 0;

	*res = NULL;
	if (j_string->type == NX_JSON_NULL)
	{
		AC_INFO("%s not set.\n", name);
		len = 0;
		goto copy;
	}

	if (j_string->type != NX_JSON_STRING)
	{
		AC_ERROR("%s is not string.\n", name);
		return -1;
	}

	len = (int)strlen(j_string->text_value);
	if (len > max_length)
	{
		AC_ERROR("%s.length == %d, out of range: [0, %d].\n",
			name, len, max_length);
		return -1;
	}

copy:
	*res = CALLOC_NEW_N((len + 1), char);
	if (*res == NULL)
	{
		AC_ERROR("%s.length == %d, out of memory\n", name, len);
		return -1;
	}
	memcpy(*res, j_string->text_value, len);
	(*res)[len] = 0;
	return 0;
}


int nx_json_array_map(
	void **res,
	int *nr_res,
	const nx_json *j_array,
	const char *name,
	int max_length,
	int elem_size,
	int (* elem_ctor)(void *elem, const nx_json *js),
	void (* elem_dtor)(void *elem))
{
	const nx_json *js = NULL;
	char *array = NULL;
	int i = 0;

	*res = NULL;
	*nr_res = 0;

	if (j_array->type == NX_JSON_NULL)
	{
		AC_INFO("%s not set.\n", name);
		return 0;
	}

	if (j_array->type != NX_JSON_ARRAY)
	{
		AC_ERROR("%s is not array.\n", name);
		return -1;
	}

	if (j_array->length > max_length)
	{
		AC_ERROR("%s.length == %d, out of range: [0, %d].\n",
			name, j_array->length, max_length);
		return -1;
	}

	if (j_array->length == 0)
	{
		AC_INFO("%s is empty.\n", name);
		return 0;
	}

	array = CALLOC_NEW_N(elem_size * j_array->length, char);
	if (array == NULL)
	{
		AC_ERROR("%s.length == %d, out of memory.\n", name, j_array->length);
		return -1;
	}

	for (js = j_array->child; js != NULL; js = js->next, i++)
	{
		if (elem_ctor(array + i * elem_size, js) != 0)
		{
			AC_ERROR("%s[%d] init failed, total: %d.\n", name, i, j_array->length);
			if (elem_dtor != NULL)
			{
				while (--i >= 0)
				{
					elem_dtor(array + i * elem_size);
				}
			}
			free(array);
			return -1;
		}
	}

	*res = array;
	*nr_res = j_array->length;
	return 0;

}


#define nx_json_array_map(res, nr_res, j_array, name, max_length, elem_type, ctor, dtor) \
	((void)(*(res) == (elem_type *)NULL), \
		(void)((ctor) == (int (*)(elem_type *, const nx_json *))NULL), \
		(void)((dtor) == (void (*)(elem_type *))NULL), \
		nx_json_array_map((void **)(res), (nr_res), (j_array), \
			(name), (max_length), sizeof(elem_type), \
			(int (*)(void *, const nx_json *))(ctor), \
			(void (*)(void *))(dtor)))


