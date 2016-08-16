/**/
#ifndef _JSON_UTILITY_H
#define _JSON_UTILITY_H
#include "nxjson.h"

int nx_json_verify(const nx_json *js_root);

int nx_json_integer_map(unsigned int *res, 
	const nx_json *j_integer,
	const char *name, 
	unsigned int min, 
	unsigned int max);

int nx_json_string_map(
	char **res, 
	const nx_json *j_string,
	const char *name, 
	int max_length);

int nx_json_array_map(
	void **res,
	int *nr_res,
	const nx_json *j_array,
	const char *name,
	int max_length,
	int elem_size,
	int (* elem_ctor)(void *elem, const nx_json *js),
	void (* elem_dtor)(void *elem));


#define nx_json_array_map(res, nr_res, j_array, name, max_length, elem_type, ctor, dtor) \
	((void)(*(res) == (elem_type *)NULL), \
		(void)((ctor) == (int (*)(elem_type *, const nx_json *))NULL), \
		(void)((dtor) == (void (*)(elem_type *))NULL), \
		nx_json_array_map((void **)(res), (nr_res), (j_array), \
			(name), (max_length), sizeof(elem_type), \
			(int (*)(void *, const nx_json *))(ctor), \
			(void (*)(void *))(dtor))) 

#endif