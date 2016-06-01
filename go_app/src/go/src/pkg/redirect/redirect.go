package redirect

/*
#cgo LDFLAGS:-lredirect -lnosdbg
#include "nos_redirect.h"
*/
import "C"

import (
	"unsafe"
)

/*
 * 发送http 302 重定向数据包.
 *
 * @ipkt 重定向的源GET包.
 * @payload, 重定向发送的HTTP头数据.
 * @paylen, 重定向发送的HTTP头数据长度.
 *
 * @return 0表示成功.
 */
func Redirect_http(ifname []byte, packet []byte, request []byte, size int32) int32 {
	//调用c的重定向接口
	return int32(C.nos_redirect_http(
		(*C.char)(unsafe.Pointer(&ifname[0])),
		(*C.char)(unsafe.Pointer(&packet[0])),
		(*C.char)(unsafe.Pointer(&request[0])),
		C.int(size)))
}
