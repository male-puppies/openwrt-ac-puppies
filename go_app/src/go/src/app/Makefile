all:cfgmgr_ cfgbak_ websrv_ appeval_ appctl_
cfgmgr_:
	$(MAKE) -C cfgmgr 
cfgbak_:
	$(MAKE) -C cfgbak 
websrv_:
	$(MAKE) -C websrv
appeval_:
	$(MAKE) -C appeval 
appctl_:
	$(MAKE) -C appctl 

install:
	${GOROOT}/bin/go install

clean:
	${GOROOT}/bin/go clean

package:

