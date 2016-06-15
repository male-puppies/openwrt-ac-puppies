src = dump.c luawrap.c lz4.c libencrypt.c

all:encrypt.so

encrypt.so: $(src)
	$(CC) $(src) $(CFLAGS) $(LDFLAGS) -o encrypt.so -fpic -shared -llua

.PHONY: clean all

clean:
	-rm -f *.o
	-rm -f encrypt.so
	