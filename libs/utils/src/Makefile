
PPS_OBJ = utils.o nt_message.o nt_traversal.o nt_statistics.o
LIB_BIN = libpps.so
FPIC = -fPIC

CFLAGS += -std=gnu99

%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(FPIC) -c -o $@ $<


%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) $(LUA_CFLAGS) $(IP_CFLAGS) $(FPIC) -c -o $@ $<

compile: $(PPS_OBJ)
	$(CC) $(LDFLAGS) -shared -o $(LIB_BIN) $(PPS_OBJ)

clean:
	rm -f *.o *.so
