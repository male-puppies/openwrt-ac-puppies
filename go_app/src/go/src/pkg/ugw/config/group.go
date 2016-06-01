package config

import (
	"hash/crc64"
)

const (
	GROUPINFO = "Group.Groups"
)

type GroupConfig struct {
	Groups map[string]*Group
}

type Group struct {
	GroupId   uint64 //组crc
	GroupName string //组名
	GroupDesc string //组描述
}

func (grp *Group) OnNew() bool {
	grp.GroupId = crc64.Checksum([]byte(grp.GroupName), crc64.MakeTable(crc64.ECMA))
	return true
}

func (u *GroupConfig) OnGroupsInsert(users map[string]*Group, key string, val *Group) bool {
	go notifyAuthd("insertgroup", key)
	return true
}

func (u *GroupConfig) OnGroupsUpdate(users map[string]*Group, key string, val *Group) bool {
	go notifyAuthd("updategroup", key)
	return true
}

func (u *GroupConfig) OnGroupsDelete(users map[string]*Group, key string, val *Group) bool {
	go notifyAuthd("deletegroup", key)
	return true
}
