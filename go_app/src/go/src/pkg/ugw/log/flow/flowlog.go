package flowlog

import (
	"pkg/ugw/log"
)

var (
	writer = ugwlog.NewWriter("flow", Record{})
)

type Record struct {
	GroupName string      //组名
	UserName  string      //用户名
	L7Type    uint16      //协议号
	Up        uint64      //上行
	Down      uint64      //下行
	Time      ugwlog.Time //日志产生时间
}

func Close() {
	writer.Close()
}

func Write(record *Record) {
	writer.Write(record)
}
