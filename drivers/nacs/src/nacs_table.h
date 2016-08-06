#ifndef _NACS_TABLE_H
#define _NACS_TABLE_H

int nacs_table_init(void);
void nacs_table_fini(void);

int do_replace_table(const void __user *user, unsigned int len);
int do_replace_set(const void __user *user, unsigned int len);

int do_get_table_info(void __user *user, int *len);
int do_get_set_info(void __user *user, int *len);
int do_get_entries(void __user *user, int *len) ;
int do_get_sets(void __user *user, int *len);
#endif