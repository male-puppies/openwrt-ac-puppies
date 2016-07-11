src = main.c

all:luanos.so

luanos.so: $(src)
	$(CC) $(src) $(CFLAGS) $(LDFLAGS) -o luanos.so -fpic -shared -llua

.PHONY: clean all

clean:
	-rm -f *.o
	-rm -f luanos.so
