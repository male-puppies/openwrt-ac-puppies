/**/
#ifndef _RULE_PRINT_H
#define _RULE_PRINT_H
#include <stdio.h>
#define AC_PRINT(format,...)	do { fprintf(stdout, format, ##__VA_ARGS__); } while(0)
#define AC_DEBUG(format,...)	do { fprintf(stdout, "%s:%d %s"format, __FILE__, __LINE__, __func__, ##__VA_ARGS__); } while(0)
#define AC_INFO(format,...)		do { fprintf(stdout, "%s:%d %s"format, __FILE__, __LINE__, __func__, ##__VA_ARGS__); } while(0)
#define AC_ERROR(format,...)	do { fprintf(stderr, "%s:%d %s"format, __FILE__, __LINE__, __func__, ##__VA_ARGS__); } while(0)
#endif