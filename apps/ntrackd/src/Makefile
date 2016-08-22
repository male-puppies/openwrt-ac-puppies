src = main.c nt_unotify.c auth_notify.c ac_notify.c

all:ntrackd

ntrackd: $(src)
	$(CC) $(src) $(CFLAGS) $(LDFLAGS) -o $@

.PHONY: clean all

clean:
	-rm -f *.o
	-rm -f ntrackd
	
