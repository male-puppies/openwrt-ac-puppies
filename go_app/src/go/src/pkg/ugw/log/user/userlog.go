package userlog

import (
	"pkg/ugw/log"
)

var (
	writer = ugwlog.NewWriter("user", Record{})
)

type Record struct {
	Mac  string
	Host string
	Time      ugwlog.Time
}

func Close() {
	writer.Close()
}

func Write(record *Record) {
	writer.Write(record)
}
