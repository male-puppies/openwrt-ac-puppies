package main

/*
#include <stdio.h>
*/
import "C"
import (
	"fmt"
	"net/rpc"
	"os"
	"pkg/eval/evalcli"
)

var (
	appctl *rpc.Client
)

func main() {
	/*if len(os.Args) != 3 {
		usage()
	}*/
	cli := evalcli.NewEvalClient("tcp", "127.0.0.1:19999")
	fmt.Println(cli)
	connectToAppMgr()
	execAppCommand(os.Args[1], os.Args[2])
}

func usage() {
	fmt.Println("Usage: appctl [start|stop|restart|show] app")
	os.Exit(1)
}

func connectToAppMgr() {
	client, err := rpc.Dial("tcp", "127.0.0.1:1988")
	if err != nil {
		fmt.Println("rpc.Dial() error:", err)
		os.Exit(1)
	}
	appctl = client
}

////////////////////////////////////////////////////////////////////////////////

type Command struct {
	Action, App string
}

func execAppCommand(action, app string) {
	defer appctl.Close()

	var result string
	err := appctl.Call("AppMgr.Exec", &Command{Action: action, App: app}, &result)
	if err != nil {
		fmt.Println("rpc.Call() error:", err)
		os.Exit(1)
	}

	if result == "" {
		fmt.Println("[OK]", action, app)
	} else {
		fmt.Println(result)
	}
}
