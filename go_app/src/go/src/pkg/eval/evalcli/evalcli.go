package evalcli

import (
	"encoding/json"
	"net/rpc"
	"sync"
)

var (
	ErrShutdown = rpc.ErrShutdown
)

type EvalClient struct {
	conn *rpc.Client
	lock sync.Mutex
	net  string
	addr string
}

func NewEvalClient(net, addr string) *EvalClient {
	return &EvalClient{net: net, addr: addr}
}

func (cli *EvalClient) Eval(cmd string, res interface{}) (err error) {
	cli.lock.Lock()
	defer cli.lock.Unlock()

	if cli.conn == nil {
		if err = cli.dial(); err != nil {
			return err
		}
	}

	var jsonres []byte

	err = cli.conn.Call("EvalServer.Eval", &cmd, &jsonres)
	if err == ErrShutdown { // retry once
		cli.conn.Close() // ignore error
		if err = cli.dial(); err != nil {
			return err
		}
		err = cli.conn.Call("EvalServer.Eval", &cmd, &jsonres)
		if err == ErrShutdown {
			cli.conn.Close()
			cli.conn = nil
		}
	}

	if err != nil {
		return err
	}

	return json.Unmarshal(jsonres, res)
}

func (cli *EvalClient) dial() (err error) {
	cli.conn, err = rpc.Dial(cli.net, cli.addr)
	return err
}
