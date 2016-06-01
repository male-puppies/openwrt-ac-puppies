package sandc 
import (
	"fmt"
	"errors"
	"time"
	"encoding/json" 
)

type ProxyMsgCb func(ins *SandCProxy, topic, payload string) 

type SandCProxy struct {
	seq int32
	sc *SandC
	srv_topics []string
	cli_topics []string
	on_message ProxyMsgCb
	out_seq_map map[int32] chan interface{}
}

type ProxyRequest struct {
	Mod string 						`json:"mod"`
	Seq int32  						`json:"seq"`	
	Pld map[string] interface{} 	`json:"pld"`
}

func NewSandCProxy(clientid string) *SandCProxy {
	sc := NewSandC(clientid)
	ins := &SandCProxy{
		sc:sc,
		seq:1,
		on_message:func(psc *SandCProxy, topic, payload string) {},
	}
	ins.out_seq_map = make(map[int32]chan interface{})

	(*sc).SetMsgCallback(func(ig *SandC, m map[string]string) {
		tp, ok := m["tp"]
		if ok == false {
			return
		}

		pl, ok := m["pl"]
		if ok == false {
			return
		}
		
		is_client_topic := false 
		for _, topic := range (*ins).cli_topics {
			if topic == tp {
				is_client_topic = true
				break
			}
		}

		if is_client_topic == false {
			(*ins).on_message(ins, tp, pl)
			return
		}

		var p ProxyRequest
		err := json.Unmarshal([]byte(pl), &p)
		if err != nil {
			panic(err)
		}

		seq := p.Seq 	
		if seq <= 0 {
			panic("invalid seq " + string(seq))
		}
		
		ch, ok := ins.out_seq_map[seq]
		if ok == false {
			fmt.Println("missing seq", seq)
		} else {
			ch <- p.Pld
			close(ch)
			delete(ins.out_seq_map, seq)
		}
	})
	return ins
}

func (ins *SandCProxy) Run() {
	(*ins).sc.Run()
}

func (ins *SandCProxy) Query(topic string, data map[string] interface{}, timeout time.Duration) (interface{}, error) {
	seq := (*ins).seq;
	(*ins).seq = (*ins).seq + 1

	r := ProxyRequest {
		Mod : (*ins).cli_topics[0],
		Seq : seq,
		Pld : data,
	}

	b, err := json.Marshal(r)
	if err != nil {
		panic("Marshal fail")
	}

	ch := make(chan interface{})
	(*ins).out_seq_map[seq] = ch

	var res interface{}
	err = (*ins).sc.Publish(topic, string(b))
	if err != nil {
		return res, err
	}

	select {
	case res = <- ch:
	case <- time.After(timeout*time.Second):
		close(ch)
		err = errors.New("timeout")
		delete((*ins).out_seq_map, seq)
	}

	if len((*ins).out_seq_map) > 20 {
		panic("too many wait " + string(len((*ins).out_seq_map)))
	}

	return res, err 
}

func (ins *SandCProxy) SetMsgCallback(f ProxyMsgCb) {
	(*ins).on_message = f
}

func (ins *SandCProxy) Publish(topic, payload string) error {
	return (*ins).sc.Publish(topic, payload)
}

func (ins *SandCProxy) PreSubscribe(client_topics, server_topics []string) {
	(*ins).srv_topics = server_topics
	(*ins).cli_topics = client_topics
	tmp := client_topics
	for _, v := range server_topics {
		tmp = append(tmp, v)
	}
	(*ins).sc.PreSubscribe(tmp)
}

func (ins *SandCProxy) SetKeepalive(kp int64) {
	(*ins).sc.SetKeepalive(kp)
}

func (ins *SandCProxy) SetConnect(topic, payload string) {
	(*ins).sc.SetConnect(topic, payload)
}

func (ins *SandCProxy) SetWill(topic, payload string) {
	(*ins).sc.SetWill(topic, payload)
}

func (ins *SandCProxy) Connect(addr string) error {
	return (*ins).sc.Connect(addr)
}

func (ins *SandCProxy) SetAuth(username,  password string) {
	(*ins).sc.SetAuth(username, password)
}

