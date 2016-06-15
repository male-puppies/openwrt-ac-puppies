src = dump.c luawrap.c main.c rdsparser.c

all:rdsparser.so

rdsparser.so: $(src)
	$(CC) $(src) $(CFLAGS) $(LDFLAGS) -o rdsparser.so -fpic -shared -llua

.PHONY: clean all

clean:
	-rm -f *.o
	-rm -f rdsparser.so
	