#ifndef _NACS_DEBUG_H
#define _NACS_DEBUG_H
#include <linux/printk.h>

#define NACS_ERR_LVL    	0 	/* error conditions */
#define NACS_WARNING_LVL    1 	/* warning conditions */
#define NACS_INFO_LVL   	2		/* informational */
#define NACS_DEBUG_LVL  	3   	/* debug-level messages */
#define NACS_ALL_LVL		4		/* all*/

/*
*when set cur_loglevel to 0, disable print log
*when set cur_loglevel to 4, print all log
*/
extern uint8_t cur_loglevel;
#define NAC_PRINT_DEBUG(format,...)   do { if (NACS_DEBUG_LVL < cur_loglevel) printk(KERN_DEBUG format, ##__VA_ARGS__); } while(0)
#define NACS_DEBUG(format,...)   do { if (NACS_DEBUG_LVL < cur_loglevel) printk(KERN_DEBUG "%s "format, __func__, ##__VA_ARGS__); } while(0)
#define NACS_INFO(format,...)   do { if (NACS_INFO_LVL < cur_loglevel) printk(KERN_INFO "%s "format, __func__, ##__VA_ARGS__); } while(0)
#define NACS_WARN(format,...)   do { if (NACS_WARNING_LVL < cur_loglevel) printk(KERN_WARNING "%s "format, __func__, ##__VA_ARGS__); } while(0)
#define NACS_ERROR(format,...)   do { if (NACS_ERR_LVL < cur_loglevel) printk(KERN_ERR "%s "format, __func__, ##__VA_ARGS__); } while(0)
#endif