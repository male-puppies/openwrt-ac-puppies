package ugwlog

import (
	"bufio"
	"fmt"
	"log"
	"net"
	"reflect"
	"time"
)

var (
	netProto = "tcp4"
	netAddr  = "127.0.0.1:12345"
)

type Ip struct {
	value uint32
}

func MakeIp4(ip uint32) Ip {
	return Ip{value: ip}
}

type Time struct {
	value int64
}

func TimeFromNanosecond(ns int64) Time {
	return Time{value: ns / 1e9}
}

func TimeFromSecond(sec int64) Time {
	return Time{value: sec}
}

func (time *Time) AddSecond(sec int) {
	time.value += int64(sec)
}

func fieldToBuffer(field interface{}, buf []byte) []byte {
	switch v := field.(type) {
	default:
		log.Panicln("FieldToBuffer: not support " + reflect.TypeOf(field).String())
	case int8:
		buf = append(buf, byte(v))
	case int16:
		buf = append(buf, byte(v), byte(v>>8))
	case int32:
		buf = append(buf, byte(v), byte(v>>8), byte(v>>16), byte(v>>24))
	case int64:
		buf = append(buf, byte(v), byte(v>>8), byte(v>>16), byte(v>>24),
			byte(v>>32), byte(v>>40), byte(v>>48), byte(v>>56))
	case uint8:
		buf = append(buf, byte(v))
	case uint16:
		buf = append(buf, byte(v), byte(v>>8))
	case uint32:
		buf = append(buf, byte(v), byte(v>>8), byte(v>>16), byte(v>>24))
	case uint64:
		buf = append(buf, byte(v), byte(v>>8), byte(v>>16), byte(v>>24),
			byte(v>>32), byte(v>>40), byte(v>>48), byte(v>>56))
	case Ip:
		ip := v.value
		buf = append(buf, byte(ip), byte(ip>>8), byte(ip>>16), byte(ip>>24))
	case Time:
		t := v.value
		buf = append(buf, byte(t), byte(t>>8), byte(t>>16), byte(t>>24),
			byte(t>>32), byte(t>>40), byte(t>>48), byte(t>>56))
	case string:
		size := len(v)
		buf = append(buf, byte(size), byte(size>>8), byte(size>>16), byte(size>>24))
		buf = append(buf, v...)
	}
	return buf
}

func recordToBuffer(rec reflect.Value, typ reflect.Type) []byte {
	buf := make([]byte, 0, 1024)
	buf = append(buf, 0, 0, 0, 0) // for auto id field
	n := typ.NumField()
	for i := 0; i < n; i++ {
		field := rec.Field(i).Interface()
		buf = fieldToBuffer(field, buf)
	}
	return buf
}

type logWorker struct {
	name string
	conn net.Conn
	buf  *bufio.Writer
}

func (worker *logWorker) log(format string, values ...interface{}) {
	msg := fmt.Sprintf("logWorker[%s] ", worker.name)
	msg += fmt.Sprintf(format, values...)
	log.Println(msg)
}

func (worker *logWorker) connect() bool {
	if worker.conn != nil {
		return true
	}

	worker.log("connecting %s://%s ...", netProto, netAddr)

	conn, err := net.Dial(netProto, netAddr)
	if err != nil {
		worker.log("connect error: %s", err)
		return false
	}

	if _, err := fmt.Fprintln(conn, "1.0", worker.name); err != nil {
		conn.Close()
		worker.log("connect send header error: %s", err)
		return false
	}

	worker.conn = conn
	worker.buf = bufio.NewWriterSize(conn, 1<<20)
	return true
}

func (worker *logWorker) disconnect() {
	if worker.conn != nil {
		if err := worker.conn.Close(); err != nil {
			worker.log("disconnect error: %s", err)
		}
		worker.conn = nil
		worker.buf = nil
	}
}

func (worker *logWorker) write(data []byte) {
	if worker.connect() {
		n, err := worker.buf.Write(data)
		if n != len(data) {
			worker.log("write error: %s", err)
			worker.disconnect()
		}
	}
}

func (worker *logWorker) flush() {
	if worker.buf != nil {
		bufsize := worker.buf.Buffered()
		if bufsize == 0 {
			return
		}

		if err := worker.buf.Flush(); err != nil {
			worker.log("flush %d bytes error: %s", bufsize, err)
			worker.disconnect()
		} else {
			worker.log("flush %d bytes OK", bufsize)
		}
	}
}

func startLogWorker(name string, close <-chan chan bool, data <-chan []byte) {
	worker := logWorker{name: name}

	worker.log("start")

	timer := time.Tick(1 * time.Second)

	for {
		select {
		case <-timer:
			worker.flush()
		case rec := <-data:
			worker.write(rec)
		case done := <-close:
			worker.flush()
			worker.disconnect()
			worker.log("exit")
			done <- true
			return
		}
	}
}

type LogWriter struct {
	name  string
	typ   reflect.Type
	close chan chan bool
	data  chan []byte
}

func (writer *LogWriter) Close() {
	done := make(chan bool)
	writer.close <- done
	<-done
}

func (writer *LogWriter) Write(recordPtr interface{}) {
	recVal := reflect.ValueOf(recordPtr).Elem()
	recType := recVal.Type()

	if recType != writer.typ {
		log.Fatalf("LogWriter[%s] write record: type mismatch\n", writer.name)
	}

	writer.data <- recordToBuffer(recVal, recType)
}

func NewWriter(name string, record interface{}) *LogWriter {
	close := make(chan chan bool)
	data := make(chan []byte)

	go startLogWorker(name, close, data)

	return &LogWriter{
		name:  name,
		typ:   reflect.ValueOf(record).Type(),
		close: close,
		data:  data,
	}
}
