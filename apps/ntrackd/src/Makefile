src = main.c

all:ntrackd

ntrackd: $(src)
	$(CC) $(src) $(CFLAGS) $(LDFLAGS) -o $@

.PHONY: clean all

clean:
	-rm -f *.o
	-rm -f ntrackd
	