package main
import "C"
import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"io/ioutil" 
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"pkg/ugw/log/sys"
	"regexp"
	"sort"
	"strings"
	"syscall"
	"time"
)

const (
	CFG_DEFAULT       = "default.7z"                  // 默认配置的备份文件
	CFG_WORK_DIR      = "/tmp/config"                 // 配置工作目录
	CFG_BAK_DIR       = "/ugw/etc/cfgbak"             // 配置备份目录
	CFG_WORK_FILES    = CFG_WORK_DIR + "/*.json"      // UGW后台程序使用的配置文件
	CFG_BAK_HISTORY   = CFG_BAK_DIR + "/history.json" // 配置备份的历史记录
	CFG_UNRECOVER_DIR = "/ugw/etc/un_recover"         //该目录下存储不需要恢复的配置，如序列号
	F_BLACK_BOX_DIR   = "/data/blackbox"
	OPENSSL_TAR       = "/ugw/sh/init_scripts/openssltar.sh"
	PASSWORD          = "123456"
)

const (
	CFG_BAK_DELAY_MAX = 10 * time.Second // 备份当天配置时间间隔
	CFG_BAK_FILE_MAX  = 7                // 备份配置文件的数量上限
)

var (
	cfgbakList    []string
	cfgbakChan    = make(chan cfgChangeNotify)
	cfgbakDelayed = false
)

type cfgChangeNotify struct {
	module string
	done   chan bool
}

func main() {
	syslog.Info("service starting...") 
	fmt.Println("-------------------------------------------")
	initBackupList()

	tidyBackupDirectory()

	handleCommandLine()

	restoreWorkingDirectory()

	go CfgbakEventsHandler()

	go BlackBoxThread()

	timerChan := time.Tick(CFG_BAK_DELAY_MAX)

	signalChan := make(chan os.Signal)
	signal.Notify(signalChan, syscall.SIGINT, syscall.SIGTERM, syscall.SIGQUIT)

	fmt.Println("-------------------------------------------")
	// go (func() {
		for {
			fmt.Println("---")
			time.Sleep(time.Second)
		}
	// })()
	for {
		select {
		case notify := <-cfgbakChan:
			// syslog.Info("%s config changed", notify.module)
			if notify.module == "User" || notify.module == "AP" {
				// syslog.Info("delayed backup scheduled")
				cfgbakDelayed = true
			} else {
				backupCurrentConfig()
			}
			if notify.done != nil {
				notify.done <- true
			}
		case <-timerChan:
			if cfgbakDelayed {
				// syslog.Info("perform delayed backup")
				backupCurrentConfig()
				cfgbakDelayed = false
			}
		case sig := <-signalChan:
			// syslog.Info("signal received: %v", sig)
			switch sig {
			default:
			case syscall.SIGINT, syscall.SIGTERM, syscall.SIGQUIT:
				if cfgbakDelayed {
					// syslog.Info("perform delayed backup on exit")
					backupCurrentConfig()
					cfgbakDelayed = false
				}
				// syslog.Info("service exits on signal")
				// syslog.Close()
				os.Exit(0)
			}
		}
	}
}

func handleCommandLine() {
	showlist := flag.Bool("list", false, "list available backup")
	bakname := flag.String("reset", "", "reset specific settings")
	loadpath := flag.String("load", "", "load specific settings")

	flag.Parse()

	if flag.NFlag() == 0 {
		return
	}

	retcode := 0
	var bakpath string

	if *showlist {
		baklist := append(cfgbakList, CFG_DEFAULT)
		if jslist, err := json.MarshalIndent(baklist, "", "\t"); err != nil {
			fmt.Fprintf(os.Stderr, "backup list marshal(%v) error: %s\n", jslist, err)
			retcode = 1
		} else {
			fmt.Fprintf(os.Stdout, "%s\n", string(jslist))
		}
	} else if *bakname != "" {
		bakpath = CFG_BAK_DIR + "/" + *bakname + ".7z"
	} else if *loadpath != "" {
		bakpath = *loadpath
	}

	if bakpath != "" {
		if restoreBackupConfig(bakpath) && backupCurrentConfig() {
			fmt.Fprintf(os.Stdout, "reset config [%s] OK\n", bakpath)
			// syslog.Info("reset config [%s] OK", bakpath)
		} else {
			fmt.Fprintf(os.Stderr, "reset config [%s] failed\n", bakpath)
			// syslog.Error("reset config [%s] failed", bakpath)
			retcode = 1
		}
	}

	// syslog.Info("service exits")
	// syslog.Close()
	os.Exit(retcode)
}

func fileInBackupList(filename string) bool {
	for _, bakname := range cfgbakList {
		if filename == bakname {
			return true
		}
	}
	return false
}

func tidyBackupDirectory() {
	// syslog.Info("tidying backup directory...")

	if err := os.RemoveAll(CFG_WORK_DIR + ".tmp"); err != nil {
		// syslog.Error("failed to remove %s.tmp, error: %s", CFG_WORK_DIR, err)
	}

	if files, err := ioutil.ReadDir(CFG_BAK_DIR); err != nil {
		// syslog.Error("failed to read %s, error: %s", CFG_BAK_DIR, err)
	} else {
		for _, fileinfo := range files {
			filename := fileinfo.Name()
			filepath := CFG_BAK_DIR + "/" + filename
			if filepath != CFG_BAK_HISTORY && filename != CFG_DEFAULT &&
				!fileInBackupList(filename) {
				// syslog.Info("removing %s...", filepath)
				if err := os.RemoveAll(filepath); err != nil {
					// syslog.Error("failed to remove %s, error: %s", filepath, err)
				}
			}
		}
	}
}

func saveBackupHistory() bool {
	// syslog.Info("saving backup history...")
	// syslog.Debug("backup history: %v", cfgbakList)

	history, err := json.MarshalIndent(cfgbakList, "", "\t")
	if err != nil {
		// syslog.Error("failed to marshal cfgbak history: %s", err)
		return false
	}

	tmppath := CFG_BAK_HISTORY + ".tmp"

	err = ioutil.WriteFile(tmppath, history, 0644)
	if err != nil {
		// syslog.Error("failed to write cfgbak history: %s", err)
		return false
	}

	err = os.Rename(tmppath, CFG_BAK_HISTORY)
	if err != nil {
		// syslog.Error("failed to rename cfgbak history: %s", err)
		return false
	}

	// syslog.Info("backup history saved")
	return true
}

func adjustBackupList(bakname string) {
	newBakList := []string{bakname}
	for _, filename := range cfgbakList {
		if filename != bakname {
			newBakList = append(newBakList, filename)
		}
	}
	cfgbakList = newBakList

	// syslog.Debug("new backup list: %v", cfgbakList)

	if len(cfgbakList) > CFG_BAK_FILE_MAX {
		cfgbakList = cfgbakList[:CFG_BAK_FILE_MAX]
		saveBackupHistory()
		tidyBackupDirectory()
	} else {
		saveBackupHistory()
	}
}

func backupCurrentConfig() bool {
	bakname := getNowDay() + ".7z"
	bakpath := CFG_BAK_DIR + "/" + bakname
	tmppath := bakpath + ".tmp"

	// syslog.Info("make backup of current config to %s", bakpath)

	if err := os.RemoveAll(tmppath); err != nil {
		// syslog.Error("failed to remove %s, error: %s", tmppath, err)
		return false
	}

	cmd_str := fmt.Sprintf("%s tar %s %s %s", OPENSSL_TAR, CFG_WORK_DIR, tmppath, PASSWORD)
	cmd := exec.Command("sh", "-c", cmd_str)
	if _, err := cmd.Output(); err != nil {
		// syslog.Error("failed to make backup: %s, %s", err, cmd_str)
		fmt.Println(tmppath, CFG_WORK_FILES)
		return false
	}

	if err := os.Rename(tmppath, bakpath); err != nil {
		// syslog.Error("failed to rename backup file: %s", err)
		return false
	}

	// syslog.Info("make backup OK")

	adjustBackupList(bakname)

	return true
}

func getSortedBackupFileNames() []string {
	var filenames []string

	if files, err := ioutil.ReadDir(CFG_BAK_DIR); err != nil {
		// syslog.Error("failed to read %s, error: %s", CFG_BAK_DIR, err)
		// syslog.Error("service exits with error")
		// syslog.Close()
		os.Exit(1)
	} else {
		bakPat := regexp.MustCompile(`\d\d\d\d-\d\d-\d\d\.7z`)
		for _, file := range files {
			name := file.Name()
			if bakPat.MatchString(name) {
				filenames = append(filenames, name)
			}
		}
		sort.Strings(filenames)
	}

	return filenames
}

func initBackupList() {
	var baknames []string

	if history, err := ioutil.ReadFile(CFG_BAK_HISTORY); err != nil {
		// syslog.Warn("failed to read history, error: %s", err)
	} else {
		if err := json.Unmarshal(history, &baknames); err != nil {
			// syslog.Error("failed to unmarshal history, error: %s", err)
		}
	}

	if len(baknames) != 0 {
		cfgbakList = nil
		for _, filename := range baknames {
			filepath := CFG_BAK_DIR + "/" + filename
			if _, err := os.Stat(filepath); err != nil {
				// syslog.Warn("stat %s failed, error: %s", filepath, err)
			} else {
				cfgbakList = append(cfgbakList, filename)
			}
		}
		if len(cfgbakList) != len(baknames) {
			// syslog.Warn("backup list mismatch")
			saveBackupHistory()
		}
	} else {
		// syslog.Info("recovering backup history...")
		baknames = getSortedBackupFileNames()
		cfgbakList = make([]string, len(baknames))
		i := len(baknames) - 1
		for _, filename := range baknames {
			cfgbakList[i] = filename
			i--
		}
		saveBackupHistory()
	}

	// syslog.Info("backup list initialized: %v", cfgbakList)
}

func restoreBackupConfig(bakpath string) bool {
	dstpath := CFG_WORK_DIR + ".tmp"

	// syslog.Info("restoring %s...", bakpath)

	if err := os.RemoveAll(dstpath); err != nil {
		// syslog.Error("failed to remove %s, error: %s", dstpath, err)
		return false
	}

	cmd_str := fmt.Sprintf("%s untar %s %s %s", OPENSSL_TAR, bakpath, dstpath, PASSWORD)
	cmd := exec.Command("sh", "-c", cmd_str)
	_, err := cmd.Output()
	if err != nil {
		// syslog.Error("failed to restore %s, error: %s, %s", bakpath, err, cmd_str)
		return false
	}

	if err := os.RemoveAll(CFG_WORK_DIR); err != nil {
		// syslog.Error("failed to remove %s, error: %s", CFG_WORK_DIR, err)
		return false
	}

	if err := os.Rename(dstpath, CFG_WORK_DIR); err != nil {
		// syslog.Error("failed to rename %s, error: %s", CFG_WORK_DIR, err)
		return false
	}

	/*避免不应该被恢复的配置文件被覆盖，例如客户已经开启的序列号*/
	un_recover()

	exec.Command("sh", "-c", "echo {} > /tmp/config/rds.json").Run()

	// syslog.Info("%s restored", bakpath)
	return true
}

func restoreWorkingDirectory() {
	if fileinfo, err := os.Stat(CFG_WORK_DIR); err != nil {
		if os.IsNotExist(err) {
			// syslog.Info("%s does not exist, restore it", CFG_WORK_DIR)
		} else {
			// syslog.Error("stat %s failed, error: %s", CFG_WORK_DIR, err)
			// syslog.Error("service exits on fs exception")
			// syslog.Close()
			os.Exit(1)
		}
	} else {
		if fileinfo.IsDir() {
			// syslog.Info("%s exists, no need restore", CFG_WORK_DIR)
			return
		}
		// syslog.Error("%s is not directory, remove it", CFG_WORK_DIR)
		if err := os.RemoveAll(CFG_WORK_DIR); err != nil {
			// syslog.Error("remove %s failed, error: %s", CFG_WORK_DIR, err)
			// syslog.Error("service exits on fs exception")
			// syslog.Close()
			os.Exit(1)
		}
	}

	// syslog.Info("restoring config working direcotry...")

	trylist := append(cfgbakList, CFG_DEFAULT)

	for _, bakname := range trylist {
		bakpath := CFG_BAK_DIR + "/" + bakname
		if restoreBackupConfig(bakpath) {
			return
		}
	}

	// syslog.Error("failed to restore config working directory")
	// syslog.Close()
	os.Exit(1)
}

/*避免不应该被恢复的配置文件被覆盖，例如客户已经开启的序列号*/
func un_recover() {
	ok, _ := isExists(CFG_UNRECOVER_DIR)
	if !ok {
		// syslog.Warn("Dir %s not exist!\n", CFG_UNRECOVER_DIR)
		return
	}

	walkFunc := func(path string, info os.FileInfo, err error) error {
		cfg_name := info.Name()
		if info.IsDir() {
			if cfg_name != "un_recover" {
				return filepath.SkipDir
			} else {
				return nil
			}
		}

		CopyFile(CFG_UNRECOVER_DIR+"/"+cfg_name, CFG_WORK_DIR+"/"+cfg_name+".bak")
		os.Rename(CFG_WORK_DIR+"/"+cfg_name+".bak", CFG_WORK_DIR+"/"+cfg_name)

		return nil
	}

	filepath.Walk(CFG_UNRECOVER_DIR, walkFunc)

}

func CopyFile(src, dst string) (w int64, err error) {
	srcFile, err := os.Open(src)
	if err != nil {
		fmt.Println(err.Error())
		return
	}
	defer srcFile.Close()

	dstFile, err := os.Create(dst)

	if err != nil {
		fmt.Println(err.Error())
		return
	}

	defer dstFile.Close()

	return io.Copy(dstFile, srcFile)

}

/*判断文件或目录是否存在*/
func isExists(path string) (bool, error) {
	_, err := os.Stat(path)
	if err == nil {
		return true, nil
	}
	if os.IsNotExist(err) {
		return false, nil
	}
	return false, err
}

/*
获取当前日期字符串
输出：2013-01-01
*/
func getNowDay() string {
	// RFC3339     = "2006-01-02T15:04:05Z07:00"
	time_str := time.Now().Format(time.RFC3339)
	day_strs := strings.SplitN(time_str, "T", -1)
	return day_strs[0]
}
