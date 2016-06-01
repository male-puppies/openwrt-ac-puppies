package syslog

//系统日志基本定义

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path"
	"pkg/ugw/log"
	"runtime"
	"strings"
	"time"
)

var moduleName string //模块名

var (
//writer = ugwlog.NewWriter("sys", Record{})
)

const ( //日志级别
	DEBUG = 1
	INFO  = 2
	WARN  = 3
	ERROR = 4
)

type Record struct {
	Level   uint8       //日志级别
	Module  string      //模块名
	Source  string      //文件名
	Details string      //日志详情
	Time    ugwlog.Time //事件发生时间
}

func Close() {
	//writer.Close()
}

var (
	g_file    *os.File
	logBuf    *bufio.Writer
	timerChan <-chan time.Time
)

const (
	LOG_FLUSH_INTERVAL = 3 * time.Second
	LOG_FLUSH_MAXSIZE  = 512
)
const (
	current_log = "/ugw/log/openwrt_log.txt"
	max_logfile = 5
)

func logInit() error {

	return nil
}
func logCleanup() {
	g_file.Close()
	logBuf = nil
	timerChan = nil
}
func logFlush() error {
	if logBuf.Buffered() == 0 {
		return nil
	}
	if err := logBuf.Flush(); err != nil {
		//fmt.Fprintf(os.Stderr, "log flush error: %s\n", err)
		return err
	}
	return nil
}
func logWrite(msg string) error {
	select {
	default:
	case <-timerChan:
		if err := logFlush(); err != nil {
			return err
		}
		timerChan = time.After(LOG_FLUSH_INTERVAL)
	}
	if n, err := logBuf.WriteString(msg); err != nil || n != len(msg) {
		//fmt.Fprintf(os.Stderr, "log write error: %s, %d/%d\n", err, n, len(msg))
		return err
	}
	return nil
}

func open_new_log() {
	file, err := os.OpenFile(current_log, os.O_APPEND|os.O_WRONLY|os.O_CREATE, 0644)
	if err != nil {
		fmt.Println("open log.txt fail", err)
		os.Exit(-1)
	}
	g_file = file
	logBuf = bufio.NewWriterSize(g_file, LOG_FLUSH_MAXSIZE)
	if timerChan == nil {
		timerChan = time.After(LOG_FLUSH_INTERVAL)
	}
}
func check_logfile() {
	if g_file == nil {
		open_new_log()
	}
	fi, err := g_file.Stat()
	if err != nil {
		fmt.Println("Stat log.txt fail", err)
		os.Exit(-1)
	}
	if fi.Size() > 1024*1024 {
		g_file.Close()
		post := time.Now().Format("0102-15:04:05")
		filepath := current_log + "." + post
		if err := os.Rename(current_log, filepath); err == nil {
			cmd := fmt.Sprintf("total_log_files=`ls %s.* | wc -l`; ls %s.* | sort -r | tail -$((total_log_files-%d)) | xargs rm", current_log, current_log, max_logfile)
			exec.Command("sh", "-c", cmd).Run()
		} else {
			fmt.Println("rename fail", err)
		}
		open_new_log()
	}
}
func write(level uint8, detail string) {
	_, file, line, _ := runtime.Caller(2)
	tokens := strings.SplitAfter(file, "/")
	file = tokens[len(tokens)-1]
	check_logfile()
	msg := fmt.Sprintf("%s:%d %s %s\n", file, line, time.Now().Format("01-02 15:04:05"), detail)
	logWrite(msg)
	fmt.Fprintf(os.Stderr, "%s", msg)
}

//debug syslog
func Debug(format string, v ...interface{}) {
	write(DEBUG, fmt.Sprintf(format, v...))
}

//info syslog
func Info(format string, v ...interface{}) {
	write(INFO, fmt.Sprintf(format, v...))
}

//warn syslog
func Warn(format string, v ...interface{}) {
	write(WARN, fmt.Sprintf(format, v...))
}

//error syslog
func Error(format string, v ...interface{}) {
	write(ERROR, fmt.Sprintf(format, v...))
}

func init() {
	moduleName = path.Base(os.Args[0])
	fmt.Fprintf(os.Stderr, "syslog for %s init ok\n", moduleName)
}
