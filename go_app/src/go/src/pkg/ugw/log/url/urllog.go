package urllog

import (
	"pkg/ugw/log"
)

var (
	writer = ugwlog.NewWriter("url", Record{})
)

type Record struct {
	Time      ugwlog.Time
	UserName  string
	GroupName string
	Url       string
	Title     string
	UrlType   string
}

func Close() {
	writer.Close()
}

func Write(record *Record) {
	writer.Write(record)
}
