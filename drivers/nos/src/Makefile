# build modules
#EXTRA_CFLAGS = -Wall
obj-m += nos.o

nos-y += nos_main.o nos_auth.o nos_zone.o nos_ipgrp.o nos_log.o

EXTRA_CFLAGS += -Wall -Werror

PWD ?= $(shell pwd)

ifndef KERNELRELEASE
KERNELRELEASE := $(shell uname -r)
endif
    
KERNELDIR = /home/terminator/Sources/openwrt/linux-stable
#KERNELDIR ?= /lib/modules/$(KERNELRELEASE)/build
KMAKE := $(MAKE) -C $(KERNELDIR) M=$(PWD)

all: modules

modules:
	$(KMAKE) modules

modules_install:
	$(KMAKE) modules_install

install: modules_install
	depmod

clean:
	$(KMAKE) clean
