INSTALL=install
INSTALL_FLAGS=
MKDIR=mkdir
MKDIR_FLAGS=-p
DESTDIR=
prefix?=/usr
sbindir=$(prefix)/lib/lua

all:
	$(CC) luv.c -fPIC -shared -o luv.so -llua -luv  $(CFLAGS)

install:
	$(MKDIR) $(MKDIR_FLAGS) $(DESTDIR)$(prefix)/lib/lua
	$(INSTALL) $(INSTALL_FLAGS) luv.so $(DESTDIR)$(prefix)/lib/lua/
clean:
	$(RM) -f luv.so