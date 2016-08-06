
#ifndef _RULE_IPC_H
#define _RULE_IPC_H

int do_rule_ipc_set(int cmd, void *data, unsigned int len);
int do_rule_ipc_get(int cmd, void *data, unsigned int len);
#endif