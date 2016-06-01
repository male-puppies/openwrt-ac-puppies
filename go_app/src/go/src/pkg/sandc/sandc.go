package sandc 

/*
#cgo LDFLAGS: -L. -lrdsparser
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdint.h>

#include "rdsparser.h"
typedef struct str_arr {
	int idx;
	int count;
	rds_str *arr;
} str_arr;

void str_arr_prepare(str_arr *ins, int count) {
	ins->arr = (rds_str *)malloc(count * sizeof(rds_str));
	if (!ins->arr) {
		fprintf(stderr, "%s %d malloc fail\n", __FILE__, __LINE__);
		exit(-1);
	}
	memset(ins->arr, 0, count * sizeof(rds_str));
	ins->count = count;
}

void str_arr_free(str_arr *ins) {
	int i;
	for (i = 0; i < ins->count; i++) {
		if (ins->arr[i].p) {
			free(ins->arr[i].p);
		}
	}
	free(ins->arr);
}

void str_arr_push(str_arr *ins, const char *base, int len) {
	int i = ins->idx;
	if (i >= ins->count) {
		fprintf(stderr, "%s %d ERROR\n", __FILE__, __LINE__);
		exit(-1);
	}
	char *p = (char *)malloc(len);
	if (!p) {
		fprintf(stderr, "%s %d malloc fail\n", __FILE__, __LINE__);
		exit(-1);
	}
	memcpy(p, base, len);
	ins->arr[i].p = p;
	ins->arr[i].len = len;
	ins->idx++;
}

int64_t getTickCount() {
	struct timespec t = {0, 0};  
	if (clock_gettime(CLOCK_MONOTONIC, &t)) {
		fprintf(stderr, "%s %d clock_gettime fail\n", __FILE__, __LINE__);
		exit(-1);
	}

	return t.tv_sec;
}

char *get_res_result(rds_result *res, int idx, int *out) {
	*out = res->res_arr[idx].len;
	return res->res_arr[idx].p;
}

*/
import "C"

import (
	"fmt"
	"net"
	"sync"
	"time"
	"errors"
	"unsafe"
	"strings"
)

const (
	st_new = "new"
	st_run = "run"
	st_stop = "stop"
)

type SandCParam struct {
	clientid string
	username string
	password string
	version string 
	keepalive int64 
	topics []string
	connect_topic string
	connect_payload string
	will_topic string
	will_payload string
}

type MsgCallBack func(ins *SandC, m map[string]string)

func numb(ins *SandC, m map[string]string) {}

type SandC struct {
	param SandCParam
	conn *net.TCPConn
	active int64
	on_message MsgCallBack
	state string
	rds *C.struct_rdsst
	wlock sync.Mutex
	on_connect MsgCallBack
	on_disconnect MsgCallBack
}

func (ins *SandC) SetMsgCallback(f MsgCallBack) {
	(*ins).on_message = f
}

func rds_build(mp *map[string]string) []byte {
	m := *mp

	sar_len := C.int(len(m))
	sar := C.struct_str_arr{0, sar_len, nil} 
	C.str_arr_prepare(&sar, sar_len)
	
	for k, v := range m {
		s := k + v
		C.str_arr_push(&sar, C.CString(s), C.int(len(s)))
	}

	var reslen C.int
	res := C.rds_encode(sar.arr, sar_len, &reslen)
	C.str_arr_free(&sar)

	return C.GoBytes(unsafe.Pointer(res), reslen)
}


func sendN(conn *net.TCPConn, buf []byte) error {
	conn.SetWriteDeadline(time.Now().Add(3 * time.Second))
	
	for {
		n, err := conn.Write(buf)
		if err != nil {
			return err
		}
		if n == len(buf) {
			break
		}
		buf = buf[n:]
	}

	return nil
}

func (ins *SandC) Running() bool {
	return ins.state != st_stop
}

func (ins *SandC) Close() {
	panic("not implement")
}


func (ins *SandC) timeoutPing() {
	last := int64(C.getTickCount())
	m := map[string]string {
		"id" : "pi",
	}
	b := rds_build(&m)
	keepalive := (*ins).param.keepalive

	for {
		now := int64(C.getTickCount())
		for {
			time.Sleep(1 * time.Second)

			now = int64(C.getTickCount())
			if ins.Running() == false {
				fmt.Println("---- finish timeoutPing")
				return 
			}
 			
 			// fmt.Println(now, last, now - last, keepalive)
			if now - last > 2*keepalive {
				panic("keepalive timeout ")  //TODO
			} 

			if now - last >= keepalive {
				break
			}
		}

		last = now
		// fmt.Println("send ping", last, string(b))
		err := sendN(ins.conn, b)
		if err != nil {
			panic("SendN ping fail " + err.Error())  //TODO
		}
	}
}

func (ins *SandC) ReadInternel() {
	buf := make([]byte, 8096)
	for {
	 	if ins.Running() == false {
	 		fmt.Println("---- finish ReadInternel")
	 		return
	 	}

		n, err := (*ins).conn.Read(buf)
		if err != nil {
			panic(err) //TODO 
		}
		// fmt.Println(string(buf[0:n]))

		(*ins).active = int64(C.getTickCount())

		res := ins.rds_decode_all(buf[0:n])
		if len(res) == 0 {
			fmt.Println("test not read enough")
			continue
			//panic("error connect result " + string(buf[0:n]))
		}
		
		for _, rr := range res {
			mm := arr2map(rr)
			v, ok := mm["id"]
			if ok == false {
				panic("invalid result " + string(buf[0:n]))
			}

			switch(v) {
			case "po": 
			case "pb":
				(*ins).on_message(ins, mm)
			default:
				panic("invalid result " + string(buf[0:n]))
			}
		} 
	}

}
func (ins *SandC) Run() {
	go ins.timeoutPing()
	go ins.ReadInternel()
}

func (ins *SandC) Publish(topic, payload string) error {
	if ins.Running() == false {
		return errors.New("invalid state " + ins.state)
	}

	m := map[string]string {
		"id" : "pb",
		"tp" : topic,
		"pl" : payload,
	}
	b := rds_build(&m)

	(*ins).wlock.Lock()
	defer (*ins).wlock.Unlock()

	err := sendN((*ins).conn, b)
	if err != nil {
		panic(err)
	}
	// fmt.Println("Publish ok ", string(b))
	return nil
}

func (ins *SandC) Connect(addr string) error {
	tcpAddr, err := net.ResolveTCPAddr("tcp4", addr)
	if err != nil {
		return err
	}

	conn, err := net.DialTCP("tcp", nil, tcpAddr)
	if err != nil {
	 	return err
	}
 
	m := map[string]string {
		"id" : "cn",
		"cd" : (*ins).param.clientid,
		"vv" : (*ins).param.version,
		"un" : (*ins).param.username,
		"pw" : (*ins).param.password,
		"kp" : fmt.Sprintf("%d", (*ins).param.keepalive),
		"tp" : strings.Join((*ins).param.topics, "\t"),
		"ct" : (*ins).param.connect_topic,
		"cp" : (*ins).param.connect_payload,
		"wt" : (*ins).param.will_topic,
		"wp" : (*ins).param.will_payload,
	}

	b := rds_build(&m)
	// fmt.Println(string(b))
	err = sendN(conn, b)
	if err != nil {
		fmt.Println("SendN fail", err)
		conn.Close()
		return err
	}

	buf := make([]byte, 8096)
//	conn.SetReadDeadline(time.Now().Add(3 * time.Second))
	n, err := conn.Read(buf)
	if err != nil {
		fmt.Println("recv connect result fail", err)
		conn.Close()
		return err
	}

//	conn.SetReadDeadline(time.Now().Add(0))
	res := ins.rds_decode_all(buf[0:n])
	if len(res) != 1 {
		panic("error connect result " + string(buf[0:n]))
	}

	mm := arr2map(res[0])

	if v, ok := mm["id"]; ok == false || v != "ca" {
		panic("error connect result " + string(buf[0:n]))
	}

	if v, ok := mm["st"]; ok == false || v != "0" {
		fmt.Println("connect fail", string(buf[0:n]))
		conn.Close()
		return errors.New("auth fail " + mm["da"])
	}

	(*ins).conn = conn

	fmt.Println("connect ok")
	return nil
}

func arr2map(res []string) map[string]string {
	m := map[string]string {}
	for _, v := range res {
		if len(v) < 3 {
			panic("invalid res " + v)
		}
		m[v[0:2]] = v[2:]
	}
	return m
}

type rds_res_arr []string
func (ins *SandC) rds_decode_all(buf []byte) []rds_res_arr{
	var result []rds_res_arr

	s := string(buf)
	rds_res := C.struct_rds_result{}
	ret := C.rds_decode(ins.rds, C.CString(s), C.int(len(buf)), &rds_res)
	
	for {
		if ret == -1 {
			panic("decode fail " + s)
		}

		if ret == 1 {
			return result
		}

		var cslen C.int
		var tmp []string
		
		for i := 0; i < int(rds_res.res_count); i++ {
			cs := C.get_res_result(&rds_res, C.int(i), &cslen)
			tmp = append(tmp, C.GoStringN(cs, cslen))
		}

		result = append(result, tmp)

		C.rds_result_free(&rds_res)
		ret = C.rds_decode(ins.rds, C.CString(s), C.int(0), &rds_res)
	} 
}

func (ins *SandC) SetAuth(username,  password string)  {
	(*ins).param.username = username
	(*ins).param.password = password
}

func (ins *SandC) PreSubscribe(topics []string) {
	(*ins).param.topics = topics
}

func (ins *SandC) SetKeepalive(kp int64) {
	(*ins).param.keepalive = kp
}

func (ins *SandC) SetConnect(topic, payload string) {
	(*ins).param.connect_topic = topic
	(*ins).param.connect_payload = payload
}

func (ins *SandC) SetWill(topic, payload string) {
	(*ins).param.will_topic = topic
	(*ins).param.will_payload = payload
}

func NewSandC(clientid string) *SandC {
	ins := &SandC{
		state : st_new,
		active : int64(C.getTickCount()),
		on_message : numb,
		on_connect : numb,
		on_disconnect : numb,
	}
	ins.param = SandCParam{
		clientid : clientid,
		version : "v0.1",
		keepalive : 30,
	}
	ins.rds = C.rds_new()
	return ins
}
