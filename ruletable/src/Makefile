src = *.c

CFLAGS="$(CFLAGS) -g"

all:ruletable

ruletable: $(src)
	$(CC) $(src) $(CFLAGS) $(LDFLAGS) -o $@

.PHONY: clean all

clean:
	-rm -f *.o
	-rm -f ruletable
	
