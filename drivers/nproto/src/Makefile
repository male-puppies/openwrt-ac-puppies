#
# Makefile for the kernel packets identify modules.
#

obj-${CONFIG_NPROTO} += nproto.o
nproto-y	+= main.o rules.o rules-inner.o \
	wu-manber.o mwm.o bmh.o QSORT.o \
	test.o

# pcre2 in kernel
KLIBS_DEBUG ?= 0
CODE_WIDTH ?= 8
LIBC := ${PWD}

ifeq ($(KLIBS_DEBUG), 1)
ccflags-y += -ggdb -O0 -DDEBUG
else
ccflags-y += -O2 -s
endif
ccflags-y += -I${LIBC} \
    -DHAVE_CONFIG_H -DPCRE2_CODE_UNIT_WIDTH=${CODE_WIDTH}

nproto-y += pcre.o
nproto-y += pcre2/main.o 
nproto-y += pcre2/libc.o
nproto-y += pcre2/pcre2_context.o 
nproto-y += pcre2/pcre2_jit_compile.o 
nproto-y += pcre2/pcre2_compile.o
nproto-y += pcre2/pcre2_match_data.o
nproto-y += pcre2/pcre2_match.o
nproto-y += pcre2/pcre2_string_utils.o
nproto-y += pcre2/pcre2_newline.o
nproto-y += pcre2/pcre2_tables.o
nproto-y += pcre2/pcre2_ord2utf.o
nproto-y += pcre2/pcre2_valid_utf.o
nproto-y += pcre2/pcre2_xclass.o
nproto-y += pcre2/pcre2_ucd.o
nproto-y += pcre2/pcre2_study.o
nproto-y += pcre2/pcre2_chartables.o
nproto-y += pcre2/pcre2_auto_possess.o
nproto-y += pcre2/pcre2_find_bracket.o
nproto-y += pcre2/pcre2_substring.o
nproto-y += pcre2/pcre2_error.o
# end pcre2

# rules build-in.
nproto-y += rules/http.o
nproto-y += rules/http-svn.o
nproto-y += rules/http-flv.o
nproto-y += rules/mail.o
nproto-y += rules/ssh.o
nproto-y += rules/ssl.o
nproto-y += rules/ftp.o
nproto-y += rules/dhcp.o
nproto-y += rules/RDP.o
nproto-y += rules/SIP.o
nproto-y += rules/SMB.o
nproto-y += rules/NTP.o
nproto-y += rules/VNC.o
nproto-y += rules/GTalk.o
# end rules built-in
