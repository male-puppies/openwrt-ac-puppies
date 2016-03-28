package config

import (
	"hash/crc64"
)

//策略控制对象
type ObjectOfAVCPolicy struct {
	ObjType uint8  //0-全局 1-组 2-用户
	ObjName string //对象名称（标识组名，用户名, QQ等）
}

//上网策略信息
type AvoidControlPolicy struct {
	AVCPolicyId  uint64            //全局唯一上网策略ID
	AVCPolicyObj ObjectOfAVCPolicy //策略控制对象
	AVCQQ        map[string]bool   //被审计应用
	Enable       uint8             //策略启用或禁用状态
}

type AvoidControlConfig struct {
	AVCPolicy map[string]*AvoidControlPolicy
}

func (avcp *AvoidControlPolicy) OnNew() bool {
	//合法性检查TODO
	avcp.AVCPolicyId = crc64.Checksum([]byte(avcp.AVCPolicyObj.ObjName), crc64.MakeTable(crc64.ECMA))
	return true
}

func (a *AvoidControlConfig) OnAVCPolicyInsert(adp map[string]*AvoidControlPolicy, key string, val *AvoidControlPolicy) bool {
	go notifyAuthd("avoidcontrolpolicy", key)
	go notifyAC("InsertAVPolicy", "") //通知上网控制QQ号免控
	return true
}

func (a *AvoidControlConfig) OnAVCPolicyUpdate(adp map[string]*AvoidControlPolicy, key string, val *AvoidControlPolicy) bool {
	go notifyAuthd("avoidcontrolpolicy", key)
	go notifyAC("UpdateAVPolicy", "") //通知上网控制QQ号免控
	return true
}

func (a *AvoidControlConfig) OnAVCPolicyDelete(adp map[string]*AvoidControlPolicy, key string, val *AvoidControlPolicy) bool {
	go notifyAuthd("avoidcontrolpolicy", key)
	go notifyAC("DeleteAVPolicy", "") //通知上网控制QQ号免控
	return true
}
