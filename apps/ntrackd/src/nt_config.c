#include <unistd.h>

/* just for test. */
char *auth_conf = " \
	{ \
		\"Type\": \"AuthRules\", \
		\"Rules\": [{\
			\"Name\": \"Web\", \
			\"IPSets\": [\"WebAuth\", \"Default\"], \
			\"Flags\": 1 \
		}, \
		{ \
			\"Name\": \"Auto\", \
			\"IPSets\": [\"AutoAuth\"], \
			\"Flags\": 0 \
		}] \
	}";

char *weix_conf = " \
	{ \
		\"Type\": \"WeiXin\", \
		[] \
	}";
	