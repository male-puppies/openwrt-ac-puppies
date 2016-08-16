/*
	Administration tool of Acess control in userspace.
	It contains three functions:
	1.Parse config string which is a json string
	2.Commit config to kernel
	3.Fetch config from kernel for checking whether config is right in kernel
*/
#include <unistd.h>
#include <string.h>
#include <getopt.h>
#include "rule_table.h"
#include "rule_print.h"
#include "rule_core.h"

extern char *optarg;
extern int optind, opterr, optopt;

static const char *version = "v1.0";		/*tool version*/
static const char *opt_string = "s:gt:h?";	/*support -s -g -t -h -? */


/*parse config, and then, commit to kernel*/
static int commit_config(const char *config_str)
{
	if (config_str == NULL || strlen(config_str) <= 1) {
		AC_DEBUG("invalid parameter\n");
		return -1;
	}

	AC_DEBUG("****************COMMIT CONFIG START****************\n");
	if (do_commit_config(config_str, strlen(config_str)) != 0) {
		AC_ERROR("commit failed...\n");
		return -1;
	}
	AC_DEBUG("****************COMMIT CONFIG END****************\n\n");
	return 0;
}


/*fetch config from kernel, and then, print config*/
static int fetch_config()
{
	AC_DEBUG("****************FETCH CONFIG START****************\n");
	if (do_fetch_config() != 0) {
		AC_ERROR("fetch config failed...\n");
		return -1;
	}
	AC_DEBUG("****************FETCH CONFIG END****************\n\n");
	return 0;
}


/*parse config, and then, print config*/
static int parse_config(const char *config_str)
{
	if (config_str == NULL || strlen(config_str) <= 1) {
		AC_DEBUG("invalid parameter\n");
		return -1;
	}

	AC_DEBUG("will parse config\n");
	if (do_parse_config(config_str, strlen(config_str)) != 0) {
		AC_ERROR("parse failed\n");
		return -1;
	}
	return 0;
}


/**/
static void display_version()
{
	AC_PRINT("ruletable: %s\n", version);
}


/**/
static void display_usage()
{
	AC_PRINT("Usage: /usr/sbin/ruletable <option> <parameter>\n");
	AC_PRINT("Option:\n");
	AC_PRINT("	-s config_string 	Parse and commit config to kernel\n");
	AC_PRINT("	-g 				 	Fetch config from kernel\n");
	AC_PRINT("	-t config_string 	Parse config, but don't commit to kernel\n");
	AC_PRINT("	-v 				 	Print version\n");
	AC_PRINT("	-h 				 	Display this help\n");
}


int main(int argc, char **argv)
{
	int opt = 0;

	opt = getopt(argc, argv, opt_string);
	if (opt == -1) {
		display_usage();
		return 0;
	}
	while(opt != -1) {
		switch(opt) {
			case 's':
				commit_config(optarg);
				break;
				
			case 'g':
				fetch_config();
				break;
				
			case 't':
				parse_config(optarg);
				break;
			
			case 'v':
				display_version();
				break;

			case 'h':	
				display_usage();
				break;
				
			default:
				display_usage();
				break;
		}
		opt = getopt(argc, argv, opt_string);
	}
	return 0;
}