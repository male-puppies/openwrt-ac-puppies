package main

import (
	"fmt"
	"os/exec"
	"time"
)

var goThJourLogRuning bool

func blockAndFetchJourLog(fname string) {
	if goThJourLogRuning {
		return
	}
	goThJourLogRuning = true
	exec.Command("sh", "-c", "journalctl -f >> "+fname).Run()
	goThJourLogRuning = false
}

func BlackBoxThread() {
	//stop journalctl
	goThJourLogRuning = false
	exec.Command("killall", "journalctl").Run()

	cur := time.Now()
	_, _, dd_pre := cur.Date()
	for {
		cur = time.Now()
		_, mm, dd := cur.Date()

		//dd changed
		if dd_pre != dd {
			//日志跨天了, 压缩并删掉上一天日志
			F_LOG_PRE := fmt.Sprintf("%s/%d", F_BLACK_BOX_DIR, dd_pre)
			err := exec.Command("tar", "czvf", fmt.Sprintf("%s/%d-%d.tar.gz", F_BLACK_BOX_DIR, mm, dd_pre), F_LOG_PRE).Run()
			if err != nil {
				fmt.Println(err)
			}
			err = exec.Command("rm", "-r", F_LOG_PRE).Run()
			if err != nil {
				fmt.Println(err)
			}
			//停止之前的jourctrol进程
			err = exec.Command("killall", "journalctl").Run()
			dd_pre = dd
		}

		//hh, min, sec := cur.Clock()
		F_LOG_DIR := fmt.Sprintf("%s/%d", F_BLACK_BOX_DIR, dd)

		err := exec.Command("mkdir", "-p", F_LOG_DIR).Run()
		if err != nil {
			fmt.Println(err)
			return
		}
		F_LOG_PS := F_LOG_DIR + "/ps.log"
		F_LOG_MEM := F_LOG_DIR + "/mem.log"
		F_LOG_IFACE := F_LOG_DIR + "/iface.log"

		F_LOG_JOUR := F_LOG_DIR + "/jour.log"
		go blockAndFetchJourLog(F_LOG_JOUR)

		err = exec.Command("sh", "-c", "date >> "+F_LOG_PS).Run()
		err = exec.Command("sh", "-c", "ps auxf >> "+F_LOG_PS).Run()

		err = exec.Command("sh", "-c", "date >> "+F_LOG_IFACE).Run()
		err = exec.Command("sh", "-c", "ifconfig >> "+F_LOG_IFACE).Run()

		err = exec.Command("sh", "-c", "date >> "+F_LOG_MEM).Run()
		err = exec.Command("sh", "-c", "free -m >> "+F_LOG_MEM).Run()
		err = exec.Command("sh", "-c", "cat /proc/slabinfo >> "+F_LOG_MEM).Run()

		if err != nil {
			fmt.Println(err)
		}

		//one min
		time.Sleep(time.Second * 60)
	}
}
