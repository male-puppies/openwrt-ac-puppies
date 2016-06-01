package ugwaes

import (
	"crypto/aes"
	"crypto/cipher"
	"io"
)

var KEY = "!@#$^GTYDkjKJIUTRgdfyswlkfoe)(*&^HJUdfecc"

type Aes struct {
	enc, dec cipher.BlockMode
}

func New(size int, key string) (*Aes, error) {
	padded := make([]byte, size)
	copy(padded, []byte(key))
	iv := make([]byte, size)
	aes, err := aes.NewCipher(padded)
	if err != nil {
		return nil, err
	}
	enc := cipher.NewCBCEncrypter(aes, iv)
	dec := cipher.NewCBCDecrypter(aes, iv)
	return &Aes{enc, dec}, nil
}

func (me *Aes) padSlice(src []byte) []byte {
	// src must be a multiple of block size
	bs := me.enc.BlockSize()
	mult := int((len(src) / bs) + 1)
	leng := bs * mult

	src_padded := make([]byte, leng)
	copy(src_padded, src)
	return src_padded
}

// Encrypt a slice of bytes, producing a new, freshly allocated slice
//
// Source will be padded with null bytes if necessary
func (me *Aes) Encrypt(src []byte) []byte {
	if len(src)%me.enc.BlockSize() != 0 {
		src = me.padSlice(src)
	}
	dst := make([]byte, len(src))
	me.enc.CryptBlocks(dst, src)
	return dst
}

// Encrypt blocks from reader, write results into writer
func (me *Aes) EncryptStream(reader io.Reader, writer io.Writer) error {
	for {
		buf := make([]byte, me.enc.BlockSize())
		_, err := io.ReadFull(reader, buf)
		if err != nil {
			if err == io.EOF {
				break
			} else if err == io.ErrUnexpectedEOF {
				// nothing
			} else {
				return err
			}
		}
		me.enc.CryptBlocks(buf, buf)
		if _, err = writer.Write(buf); err != nil {
			return err
		}
	}
	return nil
}

// Decrypt a slice of bytes, producing a new, freshly allocated slice
//
// Source will be padded with null bytes if necessary
func (me *Aes) Decrypt(src []byte) []byte {
	if len(src)%me.dec.BlockSize() != 0 {
		src = me.padSlice(src)
	}
	dst := make([]byte, len(src))
	me.dec.CryptBlocks(dst, src)
	return dst
}

// Decrypt blocks from reader, write results into writer
func (me *Aes) DecryptStream(reader io.Reader, writer io.Writer) error {
	buf := make([]byte, me.dec.BlockSize())
	for {
		_, err := io.ReadFull(reader, buf)
		if err != nil {
			if err == io.EOF {
				break
			} else {
				return err
			}
		}
		me.dec.CryptBlocks(buf, buf)
		if _, err = writer.Write(buf); err != nil {
			return err
		}
	}
	return nil
}

/*
//for test
func main() {
    key := "bardzotrudnykluczszyfrujący"
    aes, err := ugwaes.New(16, key)
    if err != nil {
        panic(err)
    }
    phrase := "czy nie mają koty na nietoperze ochoty?"
    buf := aes.Encrypt([]byte(phrase))
    fmt.Println(buf)
    buf = aes.Decrypt(buf)
    fmt.Println(string(buf))
}
*/
