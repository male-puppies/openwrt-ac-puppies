package main

/*
#include <stdio.h>
*/
import "C"
import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/rpc"
	"os"
	"os/exec"
	//"runtime"
	"strings"
	"sync"
	"time"
	"pkg/ugw/log/sys"
)

type AppMgrConfig struct {
	Apps []*AppInfo
}

type AppInfo struct {
	Name    string
	Path    string
	Cwd     string
	Args    []string
	mutex   sync.Mutex
	dogquit chan chan bool
	status  *appStatus
}

type appStatus struct {
	pid       int
	starttime time.Time
}

var (
	appMgrConf AppMgrConfig
)

func main() {

	go func() {
		for {
			//fmt.Println("goroutine count:", runtime.NumGoroutine())
			time.Sleep(1 * time.Second)
		}
	}()

	log.SetOutput(os.Stderr)
	loadAppMgrConfig()
	killAllApps()
	startAppMgr()
}

func startAppMgr() {
	if listener, err := net.Listen("tcp", "127.0.0.1:1988"); err != nil {
		log.Println("listen() error:", err)
		os.Exit(1)
	} else {
		rpc.Register(new(AppMgr))
		rpc.Accept(listener)
	}
}

func loadAppMgrConfig() {
	config, err := ioutil.ReadFile("/ugw/etc/appmgr/appmgr.conf")
	if err == nil {
		err = json.Unmarshal([]byte(config), &appMgrConf)
		if err == nil {
			return
		}
	}
	log.Println("loadAppMgrConfig() error:", err)
	os.Exit(1)
}

func killAllApps() {
	args := []string{"-9"}
	for _, app := range appMgrConf.Apps {
		args = append(args, app.Name)
	}
	log.Println("killall", args)
	cmd := exec.Command("killall", args...)
	if output, err := cmd.CombinedOutput(); err != nil {
		log.Printf("killAllApps() error: %s\n%s\n", err, string(output))
	}
}

func waitProcess(name string, cmd *exec.Cmd, dogquit <-chan chan bool) bool {
	exit := make(chan bool)
	go func() {
		if err := cmd.Wait(); err != nil {
			log.Printf("[%s] exited with error: %s\n", name, err)
			syslog.Info("[%s] exited with error: %s", name, err)
		} else {
			log.Printf("[%s] exited\n", name)
			syslog.Info("[%s] exited", name)
		}
		exit <- true
		log.Printf("[%s] cmd stop waiting\n", name)
		syslog.Info("[%s] cmd stop waiting", name)
	}()

	select {
	case <-exit:
		log.Printf("[%s] need restart\n", name)
		syslog.Info("[%s] need restart", name)
	case done := <-dogquit:
		log.Printf("[%s] send SIGINT\n", name)
		syslog.Info("[%s] send SIGINT", name)
		cmd.Process.Signal(os.Interrupt)
		select {
		case <-exit:
			log.Printf("[%s] interrupted\n", name)
			syslog.Info("[%s] interrupted", name)
		case <-time.After(3 * time.Second):
			log.Printf("[%s] send SIGKILL\n", name)
			syslog.Info("[%s] send SIGKILL", name)
			cmd.Process.Signal(os.Kill)
			<-exit
			log.Printf("[%s] killed\n", name)
			syslog.Info("[%s] killed", name)
		}
		done <- true
		log.Printf("[%s] not need restart\n", name)
		syslog.Info("[%s] not need restart", name)
		return false
	}

	return true
}

func startWatchdog(app *AppInfo, dogerr chan<- error, dogquit <-chan chan bool) {
	for {
		cmd := exec.Command(app.Path, app.Args...)
		cmd.Dir = app.Cwd
		//cmd.Stdin = os.Stdin
		//cmd.Stdout = os.Stdout
		//cmd.Stderr = os.Stderr

		err := cmd.Start()

		starttime := time.Now()

		if err != nil {
			app.status = &appStatus{starttime: starttime, pid: -1}
		} else {
			app.status = &appStatus{starttime: starttime, pid: cmd.Process.Pid}
		}

		if dogerr != nil {
			dogerr <- err
			dogerr = nil
			if err != nil {
				return
			}
		}

		//TODO: what if err != nil

		needRestart := waitProcess(app.Name, cmd, dogquit)

		app.status.pid = -1

		if !needRestart {
			goto quit
		}

		runsec := time.Now().Sub(starttime).Seconds()
		log.Printf("[%s] last running: %.2f sec\n", app.Name, runsec)
		syslog.Info("[%s] last running: %.2f sec", app.Name, runsec)
		if runsec < 30 {
			log.Printf("[%s] will automatically restart in 30 sec\n", app.Name)
			syslog.Info("[%s] will automatically restart in 30 sec", app.Name)
			select {
			case <-time.After(30 * time.Second):
			case done := <-dogquit:
				log.Printf("[%s] cancel restarting\n", app.Name)
				done <- true
				goto quit
			}
		}

		log.Printf("[%s] restarting...\n", app.Name)
		syslog.Info("[%s] restarting...", app.Name)
	}

quit:
	log.Printf("[%s] watchdog quit\n", app.Name)
}

func (app *AppInfo) Start() error {
	if app.dogquit != nil {
		return fmt.Errorf("'%s' is already started", app.Name)
	}

	log.Printf("[%s] starting...\n", app.Name)
	syslog.Info("[%s] starting...\n", app.Name)
	dogerr := make(chan error)
	dogquit := make(chan chan bool)
	go startWatchdog(app, dogerr, dogquit)
	if err := <-dogerr; err != nil {
		log.Printf("[%s] start error: %s\n", app.Name, err)
		return err
	}
	app.dogquit = dogquit
	log.Printf("[%s] started\n", app.Name)
	syslog.Info("[%s] started", app.Name)
	return nil
}

func (app *AppInfo) Stop() error {
	if app.dogquit == nil {
		return fmt.Errorf("'%s' is not started", app.Name)
	}

	done := make(chan bool)
	app.dogquit <- done
	log.Printf("[%s] stopping...\n", app.Name)
	syslog.Info("[%s] stopping...", app.Name)
	<-done
	app.dogquit = nil
	log.Printf("[%s] stopped\n", app.Name)
	syslog.Info("[%s] stopping...", app.Name)
	return nil
}

func (app *AppInfo) Status() string {
	// TODO: show apps in restarting state
	var pid int
	var starttime string
	if app.dogquit != nil {
		status := app.status
		pid = status.pid
		starttime = status.starttime.Format("Monday 2006-01-02 15:04:05")
	} else {
		pid = -1
		starttime = "-"
	}
	return fmt.Sprintf("[%s]\tpid: %d\tsince: %s", app.Name, pid, starttime)
}

////////////////////////////////////////////////////////////////////////////////

type AppMgr struct{}

type Command struct {
	Action string
	App    string
}

func (am *AppMgr) Exec(cmd *Command, result *string) error {
	action := strings.ToLower(cmd.Action)
	handler, ok := CommandHandlers[action]
	if !ok {
		return fmt.Errorf("not support command '%s'", action)
	}

	*result = ""
	appname := strings.ToLower(cmd.App)

	if appname == "all" {
		output := make(chan string)
		done := make(chan bool)
		for _, app := range appMgrConf.Apps {
			go func(app *AppInfo) {
				var res string
				app.mutex.Lock()
				err := handler(app, &res)
				app.mutex.Unlock()
				output <- res
				if err != nil {
					output <- err.Error() + "\n"
				}
				done <- true
			}(app)
		}
		go func() {
			for i := 0; i < len(appMgrConf.Apps); i++ {
				<-done
			}
			close(output)
		}()
		for res := range output {
			*result += res
		}
	} else {
		for _, app := range appMgrConf.Apps {
			if app.Name == appname {
				app.mutex.Lock()
				err := handler(app, result)
				app.mutex.Unlock()
				return err
			}
		}
		return fmt.Errorf("'%s' not found in appmgr.conf", appname)
	}

	return nil
}

var CommandHandlers = map[string]func(*AppInfo, *string) error{
	"start": func(app *AppInfo, result *string) error {
		return app.Start()
	},
	"stop": func(app *AppInfo, result *string) error {
		return app.Stop()
	},
	"restart": func(app *AppInfo, result *string) error {
		app.Stop() // ignore errors
		return app.Start()
	},
	"show": func(app *AppInfo, result *string) error {
		*result = app.Status() + "\n"
		return nil
	},
}
