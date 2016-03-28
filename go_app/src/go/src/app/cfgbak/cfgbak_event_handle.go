package main

import (
	"log"
	"fmt"
	"pkg/ugw/config"
)

type NotifyTargetCFGBAK int

func (fd *NotifyTargetCFGBAK) MessageHandler(msg *config.NotifyMsgSt, res *int) error {
	log.Printf("handler CfgBak notify msg: %s,%v\n", msg.Cmd, msg.Args)
	cfgbakChan <- cfgChangeNotify{msg.Cmd, nil}
	log.Printf("Bak config: %s, %v\n", msg.Cmd, msg.Args)

	return nil
}

func CfgbakEventsHandler() error {
	fmt.Println("-------------------------------------------")
	return config.CfgBakNotify.Services(new(NotifyTargetCFGBAK))
}
