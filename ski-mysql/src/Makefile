src = dump.c luawrap.c

all:luasha1.so

luasha1.so: $(src)
	$(CC) $(src) $(CFLAGS) $(LDFLAGS) -o luasha1.so -fpic -shared -llua -lcrypto

.PHONY: clean all

clean:
	-rm -f *.o
	-rm -f luasha1.so
	