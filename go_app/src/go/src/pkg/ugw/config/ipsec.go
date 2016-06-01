package config

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"os"
	"os/exec"
	"time"
)

type IpsecConfig struct {
}

func tmpname() string {
	now := time.Now()
	return fmt.Sprintf("/tmp/json_%d.json", now.UnixNano())
}

func (ipsec *IpsecConfig) Current() map[string]interface{} {
	path := tmpname()
	err := exec.Command("lua", "/ugw/lua/ipsec.lua", "current", path).Run()
	if err != nil {
		fmt.Println("lua ipsec.lua fail", err)
		os.Remove(path)
		return nil
	}
	output, err := ioutil.ReadFile(path)
	os.Remove(path)
	if err != nil {
		fmt.Println("ReadFile fail", err)
		return nil
	}
	var tmp map[string]interface{}
	if err := json.Unmarshal(output, &tmp); err != nil {
		fmt.Println("Unmarshal fail", err)
		return nil
	}
	return tmp
}

func (ipsec *IpsecConfig) Edit(obj interface{}) bool {
	path := tmpname()
	output, err := json.MarshalIndent(obj, "", "\t")
	if err != nil {
		fmt.Println("MarshalIndent fail", err)
		return false
	}
	err = ioutil.WriteFile(path, output, 0644)
	if err != nil {
		fmt.Println("write file fail", err)
		return false
	}
	err = exec.Command("lua", "/ugw/lua/ipsec.lua", "edit", path).Run()
	os.Remove(path)
	if err != nil {
		fmt.Println("lua ipsec.lua edit fail", err)
		return false
	}
	fmt.Println("Edit OK")
	return true
}

func (ipsec *IpsecConfig) Add(obj interface{}) bool {
	path := tmpname()
	output, err := json.MarshalIndent(obj, "", "\t")
	if err != nil {
		fmt.Println("MarshalIndent fail", err)
		return false
	}
	err = ioutil.WriteFile(path, output, 0644)
	if err != nil {
		fmt.Println("write file fail", err)
		return false
	}
	err = exec.Command("lua", "/ugw/lua/ipsec.lua", "add", path).Run()
	os.Remove(path)
	if err != nil {
		fmt.Println("lua ipsec.lua add fail", err)
		return false
	}
	fmt.Println("Add OK")
	return true
}

func (ipsec *IpsecConfig) Delete(peer, sec_name string) bool {
	err := exec.Command("lua", "/ugw/lua/ipsec.lua", "delete", peer, sec_name).Run()
	if err != nil {
		fmt.Println("lua ipsec.lua delete fail", err)
		return false
	}
	fmt.Println("Delete OK", peer, sec_name)
	return true
}

func (ipsec *IpsecConfig) SetPeer(peer string) bool {
	err := exec.Command("lua", "/ugw/lua/ipsec.lua", "peer", peer).Run()
	if err != nil {
		fmt.Println("lua ipsec.lua peer fail", err)
		return false
	}
	fmt.Println("SetPeer OK", peer)
	return true
}

const (
	scipt_path = "/ugw/sh/init_scripts/genipsec.sh"
)

func (ipsec *IpsecConfig) SetConn(peer, sec_name, status string) bool {
	if peer != "server" && peer != "client" && status != "enable" && status != "disable" {
		fmt.Println("error param", peer, sec_name, status)
		return false
	}
	action := "ipsec_up"
	if status == "disable" {
		action = "ipsec_down"
	}
	err := exec.Command(scipt_path, action, sec_name).Run()
	if err != nil {
		fmt.Println("change status fail", peer, sec_name, status, err)
		return false
	}
	fmt.Println("SetConn OK", peer, sec_name, status)
	return true
}

func (ipsec *IpsecConfig) DownloadClient() ([]byte, error) {
	// script download outpath
	path := tmpname()
	err := exec.Command(scipt_path, "gen_client", path).Run()
	if err != nil {
		fmt.Println("DownloadClient fail")
		return nil, errors.New("Generate client CA fail")
	}
	output, err := ioutil.ReadFile(path)
	os.Remove(path)
	if err != nil {
		fmt.Println("DownloadClient fail2")
		return nil, errors.New("Read client CA fail")
	}
	fmt.Println("DownloadClient OK")
	return output, nil
}

func (ipsec *IpsecConfig) UploadClient(path string) bool {
	err := exec.Command(scipt_path, "apply_client", path).Run()
	if err != nil {
		fmt.Println("UploadClient fail")
		return false
	}
	exec.Command("ipsec", "restart").Run()
	fmt.Println("UploadClient OK", path)
	return true
}

func (ipsec *IpsecConfig) GenServer() bool {
	err := exec.Command(scipt_path, "gen_server").Run()
	if err != nil {
		fmt.Println("gen server fail")
		return false
	}
	fmt.Println("GenServer OK")
	return true
}

func (ipsec *IpsecConfig) Restart() bool {
	err := exec.Command("ipsec", "restart").Run()
	if err != nil {
		fmt.Println("ipsec restart fail", err)
		return false
	}
	fmt.Println("Apply OK")
	return true
}
