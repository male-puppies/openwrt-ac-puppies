// 环形缓冲区
package ringbuf

/*
#include <stdint.h>
#include "ringbuf.h"
*/
import "C"

import (
	"log"
	"net"
	"os"
	"pkg/ugw/log/sys"
	"time"
	"unsafe"
)

type Ringbuf struct {
	rb *C.ringbuf_t
}

func dogSrv(path string) {

	for {

		if err := os.Remove(path + ".sock"); err != nil && !os.IsNotExist(err) {
			log.Fatal("remove file %s failed, %s", path+".sock", err)
		}

		unix_addr, err := net.ResolveUnixAddr("unix", path+".sock")
		if err != nil {
			log.Fatal("create unix sock failed", err)
		}

		l, err := net.ListenUnix("unix", unix_addr)
		if err != nil {
			log.Fatal("listen failed:", err)
		}

		log.Println("start listen at ", path)
		syslog.Debug("start listen at %s", path)

		conn, err := l.AcceptUnix()
		if err != nil {
			log.Fatal(err)
		}

		l.Close()

		if err := conn.SetWriteBuffer(1); err != nil {
			log.Fatal(err)
		}

		for {
			/*if path == "/tmp/tracer_ring" {
				log.Println("start write heart beat for dpf")
				syslog.Warn("start write heart beat for dpf")
			}*/

			/*t := time.Now()
			t.Add(3 * time.Second)
			if err := conn.SetWriteDeadline(t); err != nil {
				log.Println("dogSrv SetWriteDeadline failed!", err)
				syslog.Warn("dogSrv SetWriteDeadline failed! %s", err)
				conn.Close()
				break
			}*/
			var buf [1]byte = [1]byte{'A'}
			if n, err := conn.Write(buf[:]); err != nil || n != 1 {
				log.Println("dogSrv send heart beat failed!", err)
				syslog.Warn("dogSrv send heart beat failed! %s", err)
				conn.Close()
				break
			}
			time.Sleep(5 * time.Second)
		}
	}

}

func dogCli(path string) {

	unix_addr, err := net.ResolveUnixAddr("unix", path+".sock")
	if err != nil {
		log.Fatal("create unix sock failed", err)
	}

	conn, err := net.DialUnix("unix", nil, unix_addr)
	if err != nil {
		log.Println("bad!, program is already running!", err)
		syslog.Warn("bad!, program is already running: %s!", err)
		os.Exit(1)
	}

	if err := conn.SetReadBuffer(1); err != nil {
		log.Fatal(err)
	}

	go func() {
		var buf [1]byte
		for {
			if n, err := conn.Read(buf[:]); err != nil || n != 1 {
				log.Println("dispatcher is unrunning or restarted!", err, n)
				syslog.Debug("dispatcher is unrunning or restarted!: %s[%v]", err, n)
				conn.Close()
				os.Exit(2)
			} else {
				//log.Println("read heart beat ok")
				/*if path == "/tmp/tracer_ring" {
					log.Println(" read heart beat for dpf")
					syslog.Warn(" read heart beat for dpf")
				}*/
			}
		}

	}()
}

// 创建一个环形缓冲区. 创建失败返回nil
//  path: 环形缓冲区对应的mmap文件全路径
//  size: 环形缓冲区的容量，按byte计算
func Create(path string, size int) *Ringbuf {
	c_path := C.CString(path)
	defer C.free(unsafe.Pointer(c_path))
	rb := C.ringbuf_create(c_path, C.int(size))
	if rb == nil {
		return nil
	}

	go dogSrv(path)

	return &Ringbuf{rb}
}

// 打开已有的环形缓冲区. 打开失败返回nil
//  path: 环形缓冲区对应的mmap文件全路径
func Open(path string) *Ringbuf {

	dogCli(path)

	//time.Sleep(1 * time.Second)

	c_path := C.CString(path)
	defer C.free(unsafe.Pointer(c_path))
	rb := C.ringbuf_open(c_path)
	if rb == nil {
		return nil
	}
	return &Ringbuf{rb}
}

// 准备读操作, 返回当前可读的缓冲区
func (this *Ringbuf) ReadPrepare() []byte {
	var size C.int
	buf := C.ringbuf_read_prepare(this.rb, &size)

	sl := struct {
		addr uintptr
		len  int
		cap  int
	}{uintptr(buf), int(size), int(size)}

	return *(*[]byte)(unsafe.Pointer(&sl))
}

// 提交读操作, 调用ReadPrepare()之后调用此函数提交实际读取的字节数.
// 一次ReadPrepare()之后可以调用多次ReadCommit(), 但提交的总字节数不能超过可读的缓冲区总大小
//  size: 从ReadPrepare()返回的缓冲区中读取了多少字节
func (this *Ringbuf) ReadCommit(size int) {
	C.ringbuf_read_commit(this.rb, C.int(size))
}

// 准备写操作, 返回当前可写的缓冲区
func (this *Ringbuf) WritePrepare() []byte {
	var size C.int
	buf := C.ringbuf_write_prepare(this.rb, &size)
	if buf == nil {
		return nil
	}

	sl := struct {
		addr uintptr
		len  int
		cap  int
	}{uintptr(buf), int(size), int(size)}

	return *(*[]byte)(unsafe.Pointer(&sl))
}

// 提交写操作, 调用WritePrepare()之后调用此函数提交实际写入的字节数.
// 一次WritePrepare()之后可以调用多次WriteCommit(), 但提交的总字节数不能超过可写的缓冲区总大小
//  size: 在WritePrepare()返回的缓冲区中写入了多少字节
func (this *Ringbuf) WriteCommit(size int) {
	C.ringbuf_write_commit(this.rb, C.int(size))
}
