package ringbuf

import (
	"log"
	"pkg/nlmsg"
	"unsafe"
)

type Ringpkgs struct {
	rb *Ringbuf
}

func (this *Ringpkgs) ReadPrepare() []nlmsg.NosPacketSt {
	buffer := this.rb.ReadPrepare()
	n := len(buffer)

	if n%nlmsg.SizeOfNosPacket != 0 {
		panic(nil)
	}

	n = n / nlmsg.SizeOfNosPacket
	sl := struct {
		addr uintptr
		len  int
		cap  int
	}{uintptr(unsafe.Pointer(&buffer[0])), int(n), int(n)}

	return *(*[]nlmsg.NosPacketSt)(unsafe.Pointer(&sl))
}

func (this *Ringpkgs) ReadCommit(n int) {
	this.rb.ReadCommit(n * nlmsg.SizeOfNosPacket)
}

func (this *Ringpkgs) WritePrepare() *nlmsg.NosPacketSt {
	buffer := this.rb.WritePrepare()
	n := len(buffer)

	if n >= nlmsg.SizeOfNosPacket {
		return (*nlmsg.NosPacketSt)(unsafe.Pointer(&buffer[0]))
	} else {
		return nil
	}

	return nil
}

func (this *Ringpkgs) WriteCommit() {
	this.rb.WriteCommit(nlmsg.SizeOfNosPacket)
}

func RingPackagesCreate(path string, size int) *Ringpkgs {
	rb := Create(path, size)
	if rb == nil {
		log.Fatalln("create ring buffer failed.")
	}

	log.Printf("NosPacketSt Size: %d\n", nlmsg.SizeOfNosPacket)

	return &Ringpkgs{rb}
}

func RingPackagesOpen(path string) *Ringpkgs {
	rb := Open(path)
	if rb == nil {
		log.Fatalln("open ring buffer failed.")
	}

	return &Ringpkgs{rb}
}
