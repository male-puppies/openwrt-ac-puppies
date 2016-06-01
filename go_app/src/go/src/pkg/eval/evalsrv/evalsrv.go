package evalsrv

import (
	"encoding/json"
	"net"
	"net/rpc"
	"pkg/eval"
	"sync"
)

type EvalServer struct {
	env  *eval.EvalEnv
	lock sync.Mutex
}

func NewEvalServer() *EvalServer {
	return &EvalServer{env: eval.NewEvalEnv()}
}

func (srv *EvalServer) AddVar(name string, value interface{}) {
	srv.lock.Lock()
	defer srv.lock.Unlock()
	srv.env.AddVar(name, value)
}

func (srv *EvalServer) OnDirty(cb func() bool) {
	srv.lock.Lock()
	defer srv.lock.Unlock()
	srv.env.OnDirty(cb)
}

func (srv *EvalServer) Listen(proto, addr string) {
	listener, err := net.Listen(proto, addr)
	if err != nil {
		panic(err)
	}
	if err = rpc.RegisterName("EvalServer", (*evalServer)(srv)); err != nil {
		panic(err)
	}
	for {
		conn, err := listener.Accept()
		if err == nil {
			go rpc.ServeConn(conn)
		}
	}
}

type evalServer EvalServer

func (srv *evalServer) Eval(cmd *string, res *[]byte) error {
	srv.lock.Lock()
	defer srv.lock.Unlock()
	var obj interface{}
	err := srv.env.Eval(*cmd, &obj)
	if err != nil {
		return err
	}
	*res, err = json.Marshal(obj)
	return err
}
