#include "nquery.h"

static ntrack_t ntrack;
ntrack_t *pntrack = NULL;

static int set_flow_flags(uint32_t fid, uint32_t magic, uint32_t flags)
{
	flow_info_t *fi = nt_get_flow_by_id(pntrack, fid, magic);
	if(!fi) {
		nt_error("flow: %u-%u not found.\n", fid, magic);
		return -EINVAL;
	}
	nt_print(FMT_FLOW_STR "[0x%08x]\n", FMT_FLOW(fi), nt_flow_flags(fi));

	nt_flow_flags_set(fi, flags);
	return 0;
}

static int set_user_status(uint32_t uid, uint32_t magic, uint32_t status)
{
	uint32_t s_prev;
	user_info_t *ui = nt_get_user_by_id(pntrack, uid, magic);
	if(!ui) {
		nt_error("user: %u-%u not found.\n", uid, magic);
		return -EINVAL;
	}
	nt_print(FMT_USER_STR"\n", FMT_USER(ui));

	s_prev = nt_auth_set_status(ui, status);
	nt_info("status: %u->%u\n", s_prev, status);
	return 0;
}

int main(int argc, char *argv[])
{
	if(argc < 2) {
		nt_error("nquery <flow|user|pcap|set|stat>\n");
		exit(0);
	}

	if(strcmp(argv[1], "pcap") == 0) {
		extern int pcap_run(char *, int);
		extern int pcap_init(void);
		if(argc < 3) {
			nt_error("nquery pcap file.pcap <count: 'number of packet to send.'>\n");
			exit(0);
		}
		if(pcap_init()) {
			nt_error("pcap init failed.\n");
			exit(0);
		}
		return pcap_run(argv[2], argc > 3 ? atoi(argv[3]) : 0);
	}

	if (nt_base_init(&ntrack)) {
		nt_error("nquery message init failed.\n");
		return 0;
	}
	pntrack = &ntrack;

	/* debug */
	// nt_dump(pntrack->ui_base, 64, "user base: %p\n", pntrack->ui_base);
	// nt_dump(pntrack->fi_base, 64, "flow base: %p\n", pntrack->fi_base);

	if(strcmp(argv[1], "flow") == 0) {
		if(argc >= 3) {
			if(strcmp(argv[2], "set") == 0 && argc >= 6) {
				return set_flow_flags(atoi(argv[3]), atoi(argv[4]), atoi(argv[5]));
			} 
			nt_error("nquery flow set <fid> <magic> <flags>\n");
			return -EINVAL;
		} else {
			dump_flowinfo(-1, -1);
		}
	}

	if(strcmp(argv[1], "user") == 0) {
		if(argc >= 4){
			dump_userinfo(atoi(argv[2]), atoi(argv[3]));
		} else {
			dump_userinfo(-1, -1);
		}
	}

	if(strcmp(argv[1], "set") == 0) {
		if (argc < 5) {
			nt_error("nquery set <uid> <magic> <status>\n");
			exit(0);
		}
		return set_user_status(atoi(argv[2]), atoi(argv[3]), atoi(argv[4]));
	}

	if(strcmp(argv[1], "stat") == 0) {
		if(argc < 3) {
			nt_error("nquery stat <user/flow>\n");
			exit(0);
		}
		return ntrack_stat(strcmp(argv[2], "flow") == 0 ? 1 : 0);
	}
	return 0;
}
