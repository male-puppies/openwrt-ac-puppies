src = main.c pcap.c statistics.c dump.c

all:nquery

nquery: $(src)
	$(CC) $(src) $(CFLAGS) $(LDFLAGS) -o $@

.PHONY: clean all

clean:
	-rm -f *.o
	-rm -f nquery
	