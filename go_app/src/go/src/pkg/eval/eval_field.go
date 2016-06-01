package eval

import (
	"crypto/md5"
	"crypto/sha1"
	"fmt"
	"go/ast"
	"hash/crc32"
	"hash/crc64"
	rf "reflect"
)

func (env *EvalEnv) evalSelector(expr *ast.SelectorExpr) rf.Value {
	obj := env.eval(expr.X)
	name := expr.Sel.Name
	switch name {
	case "typeof":
		return rf.ValueOf(obj.Type().String())
	case "sizeof":
		return rf.ValueOf(obj.Type().Size())
	case "alignof":
		return rf.ValueOf(obj.Type().Align())
	case "methods":
		type methodDesc struct {
			Returns []string
			Args    []string
		}
		ret := map[string]methodDesc{}
		for i := 0; i < obj.Type().NumMethod(); i++ {
			method := obj.Type().Method(i)
			var returns []string
			for i := 0; i < method.Type.NumOut(); i++ {
				returns = append(returns, method.Type.Out(i).String())
			}
			var args []string
			for i := 0; i < method.Type.NumIn(); i++ {
				args = append(args, method.Type.In(i).String())
			}
			ret[method.Name] = methodDesc{returns, args}
		}
		return rf.ValueOf(ret)
	case "str":
		return rf.ValueOf(fmt.Sprint(obj.Interface()))
	case "hex":
		return rf.ValueOf(fmt.Sprintf("%x", obj.Interface()))
	}
start:
	switch obj.Kind() {
	case rf.Ptr, rf.Interface:
		obj = obj.Elem()
		goto start
	case rf.Uint32:
		switch name {
		case "ip4":
			return rf.ValueOf(ip4ToString(uint32(obj.Uint())))
		}
	case rf.String:
		switch name {
		case "len":
			return rf.ValueOf(obj.Len())
		case "ip4":
			ip, err := stringToIp4(obj.String())
			if err != nil {
				panic(err)
			}
			return rf.ValueOf(ip)
		case "crc32":
			return rf.ValueOf(crc32.ChecksumIEEE([]byte(obj.String())))
		case "crc64":
			return rf.ValueOf(crc64.Checksum([]byte(obj.String()), crc64.MakeTable(crc64.ECMA)))
		case "md5":
			hash := md5.New()
			hash.Write([]byte(obj.String()))
			return rf.ValueOf(hash.Sum(nil))
		case "sha1":
			hash := sha1.New()
			hash.Write([]byte(obj.String()))
			return rf.ValueOf(hash.Sum(nil))
		}
	case rf.Struct:
		typ := obj.Type()
		switch name {
		case "len":
			return rf.ValueOf(typ.NumField())
		case "keys":
			keys := make([]string, typ.NumField())
			for i := 0; i < typ.NumField(); i++ {
				keys[i] = typ.Field(i).Name
			}
			return rf.ValueOf(keys)
		case "values":
			values := make([]interface{}, typ.NumField())
			for i := 0; i < typ.NumField(); i++ {
				values[i] = obj.Field(i).Interface()
			}
			return rf.ValueOf(values)
		}
		field := obj.FieldByName(name)
		if field.IsValid() {
			if field.CanAddr() {
				ptr := field.Addr().Interface()
				if env.curScope.objhost[ptr] == nil {
					env.curScope.objhost[ptr] = &objHost{name, obj.Addr()}
				}
			}
			return field
		}
	case rf.Slice:
		switch name {
		case "len":
			return rf.ValueOf(obj.Len())
		}
	case rf.Map:
		switch name {
		case "len":
			return rf.ValueOf(obj.Len())
		case "keys":
			keys := rf.MakeSlice(rf.SliceOf(obj.Type().Key()), obj.Len(), obj.Len())
			for i, k := range obj.MapKeys() {
				keys.Index(i).Set(k)
			}
			return keys
		case "values":
			values := rf.MakeSlice(rf.SliceOf(obj.Type().Elem()), obj.Len(), obj.Len())
			for i, k := range obj.MapKeys() {
				values.Index(i).Set(obj.MapIndex(k))
			}
			return values
		}
	}

	switch obj.Kind() {
	case rf.Int, rf.Int8, rf.Int16, rf.Int32, rf.Int64:
		switch name {
		case "uint":
			return rf.ValueOf(uint(obj.Int()))
		case "uint8":
			return rf.ValueOf(uint8(obj.Int()))
		case "uint16":
			return rf.ValueOf(uint16(obj.Int()))
		case "uint32":
			return rf.ValueOf(uint32(obj.Int()))
		case "uint64":
			return rf.ValueOf(uint64(obj.Int()))
		case "int":
			return rf.ValueOf(int(obj.Int()))
		case "int8":
			return rf.ValueOf(int8(obj.Int()))
		case "int16":
			return rf.ValueOf(int16(obj.Int()))
		case "int32":
			return rf.ValueOf(int32(obj.Int()))
		case "int64":
			return rf.ValueOf(int64(obj.Int()))
		case "float32":
			return rf.ValueOf(float32(obj.Int()))
		case "float64":
			return rf.ValueOf(float64(obj.Int()))
		}
	case rf.Uint, rf.Uint8, rf.Uint16, rf.Uint32, rf.Uint64:
		switch name {
		case "int":
			return rf.ValueOf(int(obj.Uint()))
		case "int8":
			return rf.ValueOf(int8(obj.Uint()))
		case "int16":
			return rf.ValueOf(int16(obj.Uint()))
		case "int32":
			return rf.ValueOf(int32(obj.Uint()))
		case "int64":
			return rf.ValueOf(int64(obj.Uint()))
		case "uint":
			return rf.ValueOf(uint(obj.Uint()))
		case "uint8":
			return rf.ValueOf(uint8(obj.Uint()))
		case "uint16":
			return rf.ValueOf(uint16(obj.Uint()))
		case "uint32":
			return rf.ValueOf(uint32(obj.Uint()))
		case "uint64":
			return rf.ValueOf(uint64(obj.Uint()))
		case "float32":
			return rf.ValueOf(float32(obj.Uint()))
		case "float64":
			return rf.ValueOf(float64(obj.Uint()))
		}
	case rf.Float32, rf.Float64:
		switch name {
		case "int":
			return rf.ValueOf(int(obj.Float()))
		case "int8":
			return rf.ValueOf(int8(obj.Float()))
		case "int16":
			return rf.ValueOf(int16(obj.Float()))
		case "int32":
			return rf.ValueOf(int32(obj.Float()))
		case "int64":
			return rf.ValueOf(int64(obj.Float()))
		case "uint":
			return rf.ValueOf(uint(obj.Float()))
		case "uint8":
			return rf.ValueOf(uint8(obj.Float()))
		case "uint16":
			return rf.ValueOf(uint16(obj.Float()))
		case "uint32":
			return rf.ValueOf(uint32(obj.Float()))
		case "uint64":
			return rf.ValueOf(uint64(obj.Float()))
		case "float32":
			return rf.ValueOf(float32(obj.Float()))
		case "float64":
			return rf.ValueOf(float64(obj.Float()))
		}
	}

	panic("evalSelector error: " + name)
}
