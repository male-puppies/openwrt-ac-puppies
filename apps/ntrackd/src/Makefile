src = main.c nt_netlink.c nt_unotify.c nt_config.c

all:ntrackd

ntrackd: $(src)
	$(CC) $(src) $(CFLAGS) $(LDFLAGS) -o $@

.PHONY: clean all

clean:
	-rm -f *.o
	-rm -f ntrackd
	