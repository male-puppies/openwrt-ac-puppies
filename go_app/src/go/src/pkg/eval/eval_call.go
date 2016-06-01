package eval

import (
	"encoding/json"
	"fmt"
	"go/ast"
	rf "reflect"
	"sort"
)

type jsonObj struct {
	val string
}

func (obj jsonObj) toValue(typ rf.Type) rf.Value {
	val := rf.New(typ).Elem()

	if exist, ret := callObjBoolCb("FromJson", val, rf.ValueOf(obj.val)); exist {
		if !ret.Bool() {
			panic("obj.FromJson() failed")
		}
		return val
	}

	if err := json.Unmarshal([]byte(obj.val), val.Addr().Interface()); err != nil {
		panic(err)
	}

	if exist, ret := callObjBoolCb("OnNew", val); exist && !ret.Bool() {
		panic("obj.OnNew() failed")
	}

	return val
}

func getCompatibleValue(val rf.Value, typ rf.Type) rf.Value {
	if jsonobj, ok := val.Interface().(jsonObj); ok {
		val = jsonobj.toValue(typ)
	} else {
		if val.Kind() != typ.Kind() {
			data, err := json.Marshal(val.Interface())
			if err != nil {
				panic("getCompatibleValue(value): json.Marshal error: " + err.Error())
			}
			val = jsonObj{string(data)}.toValue(typ)
		}
	}
	return val
}

func (env *EvalEnv) evalCall(expr *ast.CallExpr) rf.Value {
	var fn rf.Value

	switch fe := expr.Fun.(type) {
	default:
		fn = env.eval(expr.Fun)
	case *ast.Ident:
		ret := env.funcCall(fe.Name, expr.Args)
		if ret.IsValid() {
			return ret
		}
		fn = env.evalIdent(fe)
	case *ast.SelectorExpr:
		obj := env.eval(fe.X)
		for obj.Kind() == rf.Ptr || obj.Kind() == rf.Interface {
			obj = obj.Elem()
		}
		ret := env.objCall(obj, fe.Sel.Name, expr.Args)
		if ret.IsValid() {
			return ret
		}
		fn = obj.FieldByName(fe.Sel.Name)
		if !fn.IsValid() {
			if obj.CanAddr() {
				fn = obj.Addr().MethodByName(fe.Sel.Name)
			}
			if !fn.IsValid() {
				fn = obj.MethodByName(fe.Sel.Name)
				if !fn.IsValid() {
					panic("no such function: " + fe.Sel.Name)
				}
			}
		}
	}

	fnType := fn.Type()
	if fnType.Kind() != rf.Func {
		panic("not func")
	}
	if fnType.NumIn() != len(expr.Args) {
		panic("arg count not match")
	}

	args := make([]rf.Value, len(expr.Args))
	for i, argexpr := range expr.Args {
		val := env.eval(argexpr)
		args[i] = getCompatibleValue(val, fnType.In(i))
	}

	ret := fn.Call(args)

	switch len(ret) {
	case 0:
		return rf.Value{}
	case 1:
		return ret[0]
	}
	panic("evalCall error: not support multiple return value")
}

func (env *EvalEnv) funcCall(fn string, args []ast.Expr) rf.Value {
	switch fn {
	case "ifE":
		return env.ifE(args)
	case "json":
		return env.json(args)
	}
	return rf.Value{}
}

func (env *EvalEnv) ifE(args []ast.Expr) rf.Value {
	if len(args) != 3 {
		panic("ifE(cond, true-expr, false-expr): wrong arg count")
	}
	if env.eval(args[0]).Bool() {
		return env.eval(args[1])
	}
	return env.eval(args[2])
}

func (env *EvalEnv) json(args []ast.Expr) rf.Value {
	if len(args) != 1 {
		panic("json(json-string): wrong arg count")
	}
	jsonstr := env.eval(args[0])
	if jsonstr.Kind() != rf.String {
		panic("json(json-string): wrong arg type")
	}
	obj := jsonObj{jsonstr.String()}
	return rf.ValueOf(obj)
}

func (env *EvalEnv) objCall(obj rf.Value, fn string, args []ast.Expr) rf.Value {
	switch fn {
	case "set":
		return objSet(obj, args, env)
	case "fmt":
		return objFmt(obj, args, env)
	}
	switch obj.Kind() {
	case rf.Struct:
		switch fn {
		case "mapE":
			return structMapE(obj, makeCKVCallback(env, args))
		case "filterE":
			return structFilterE(obj, makeCKVCallback(env, args))
		}
	case rf.Map:
		switch fn {
		case "insert":
			return mapInsert(obj, args, env)
		case "deleteE":
			return mapDeleteE(obj, args, env)
		case "updateE":
			return mapUpdateE(obj, args, env)
		case "mapE":
			return mapMapE(obj, makeCKVCallback(env, args))
		case "filterE":
			return mapFilterE(obj, makeCKVCallback(env, args))
		}
	case rf.Slice:
		switch fn {
		case "insert":
			return sliceInsert(obj, args, env)
		case "deleteE":
			return sliceDeleteE(obj, args, env)
		case "updateE":
			return sliceUpdateE(obj, args, env)
		case "mapE":
			return sliceMapE(obj, makeCKVCallback(env, args))
		case "filterE":
			return sliceFilterE(obj, makeCKVCallback(env, args))
		case "swapE":
			return sliceSwapE(obj, args, env)
		case "sortE":
			return sliceSortE(obj, args, env)
		}
	}
	return rf.Value{}
}

type ckvCallback func(c, k, v rf.Value) rf.Value

func makeCKVCallback(env *EvalEnv, args []ast.Expr) ckvCallback {
	if len(args) != 1 {
		panic("wrong arg count")
	}
	expr := args[0]
	return func(c, k, v rf.Value) rf.Value {
		vars := map[string]rf.Value{"c": c, "k": k, "v": v}
		return env.evalWithVars(expr, vars)
	}
}

func objSet(obj rf.Value, args []ast.Expr, env *EvalEnv) rf.Value {
	if len(args) != 1 {
		panic("obj.set(value): wrong arg count")
	}

	val := env.eval(args[0])

	val = getCompatibleValue(val, obj.Type())

	if env.onObjSet(obj, val) {
		obj.Set(val)
		env.dirty = true
		return rf.ValueOf(true)
	}

	return rf.ValueOf(false)
}

func objFmt(obj rf.Value, args []ast.Expr, env *EvalEnv) rf.Value {
	if len(args) != 1 {
		panic("obj.fmt(verb): wrong arg count")
	}
	val := env.eval(args[0])
	if val.Kind() != rf.String {
		panic("obj.fmt(verb): verb should be string value")
	}
	res := fmt.Sprintf(val.String(), obj.Interface())
	return rf.ValueOf(res)
}

func structMapE(obj rf.Value, fn ckvCallback) rf.Value {
	objtype := obj.Type()
	res := make(map[string]interface{}, objtype.NumField())
	for i := 0; i < objtype.NumField(); i++ {
		k := objtype.Field(i).Name
		v := obj.Field(i)
		res[k] = fn(obj, rf.ValueOf(k), v).Interface()
	}
	return rf.ValueOf(res)
}

func structFilterE(obj rf.Value, fn ckvCallback) rf.Value {
	objtype := obj.Type()
	res := make(map[string]interface{})
	for i := 0; i < objtype.NumField(); i++ {
		k := objtype.Field(i).Name
		v := obj.Field(i)
		if fn(obj, rf.ValueOf(k), v).Bool() {
			res[k] = v.Interface()
		}
	}
	return rf.ValueOf(res)
}

func mapInsert(obj rf.Value, args []ast.Expr, env *EvalEnv) rf.Value {
	if len(args) != 2 {
		panic("map.insert(key, value): wrong arg count")
	}

	key, val := env.eval(args[0]), env.eval(args[1])

	if key.Type() != obj.Type().Key() {
		panic("map.insert(key, value): key type mismatch")
	}

	if orig := obj.MapIndex(key); orig.IsValid() {
		return rf.ValueOf(false)
	}

	val = getCompatibleValue(val, obj.Type().Elem())

	if env.onObjInsert(obj, key, val) {
		obj.SetMapIndex(key, val)
		env.dirty = true
		return rf.ValueOf(true)
	}

	return rf.ValueOf(false)
}

func mapDeleteE(obj rf.Value, args []ast.Expr, env *EvalEnv) rf.Value {
	fn := makeCKVCallback(env, args)
	n := 0
	res := rf.MakeMap(obj.Type())
	for _, k := range obj.MapKeys() {
		v := obj.MapIndex(k)
		if fn(obj, k, v).Bool() {
			if env.onObjDelete(obj, k, v) {
				n++
				continue
			}
		}
		res.SetMapIndex(k, v)
	}
	if n != 0 {
		obj.Set(res)
		env.dirty = true
	}
	return rf.ValueOf(n)
}

func mapUpdateE(obj rf.Value, args []ast.Expr, env *EvalEnv) rf.Value {
	if len(args) != 2 {
		panic("map.updateE(cond, expr): wrong arg count")
	}
	cond := makeCKVCallback(env, args[:1])
	alter := makeCKVCallback(env, args[1:2])
	n := 0
	for _, k := range obj.MapKeys() {
		v := obj.MapIndex(k)
		if cond(obj, k, v).Bool() {
			val := valueCopy(v)
			if alter(obj, k, val).Bool() && env.onObjUpdate(obj, k, val) {
				obj.SetMapIndex(k, val)
				env.dirty = true
				n++
			}
		}
	}
	return rf.ValueOf(n)
}

func mapMapE(obj rf.Value, fn ckvCallback) rf.Value {
	res := make(map[string]interface{}, obj.Len())
	for _, k := range obj.MapKeys() {
		v := obj.MapIndex(k)
		// TODO: handle non-string keys
		res[k.String()] = fn(obj, k, v).Interface()
	}
	return rf.ValueOf(res)
}

func mapFilterE(obj rf.Value, fn ckvCallback) rf.Value {
	res := rf.MakeMap(obj.Type())
	for _, k := range obj.MapKeys() {
		v := obj.MapIndex(k)
		if fn(obj, k, v).Bool() {
			res.SetMapIndex(k, v)
		}
	}
	return res
}

func sliceInsert(obj rf.Value, args []ast.Expr, env *EvalEnv) rf.Value {
	if len(args) != 2 {
		panic("slice.insert(index, value): wrong arg count")
	}
	key, val := env.eval(args[0]), env.eval(args[1])

	idx := getIndex(key, -1, obj.Len()+1)
	if idx == -1 {
		idx = obj.Len()
	}

	key = rf.ValueOf(idx)

	val = getCompatibleValue(val, obj.Type().Elem())

	if env.onObjInsert(obj, key, val) {
		res := rf.MakeSlice(obj.Type(), obj.Len()+1, obj.Len()+1)
		rf.Copy(res, obj.Slice(0, idx))
		res.Index(idx).Set(val)
		rf.Copy(res.Slice(idx+1, res.Len()), obj.Slice(idx, obj.Len()))
		obj.Set(res)
		env.dirty = true
		return rf.ValueOf(true)
	}

	return rf.ValueOf(false)
}

func sliceDeleteE(obj rf.Value, args []ast.Expr, env *EvalEnv) rf.Value {
	fn := makeCKVCallback(env, args)
	n := 0
	res := rf.MakeSlice(obj.Type(), 0, 0)
	for i := 0; i < obj.Len(); i++ {
		v := obj.Index(i)
		k := rf.ValueOf(i)
		if fn(obj, k, v).Bool() {
			if env.onObjDelete(obj, k, v) {
				n++
				continue
			}
		}
		res = rf.Append(res, v)
	}
	if n != 0 {
		obj.Set(res)
		env.dirty = true
	}
	return rf.ValueOf(n)
}

func sliceUpdateE(obj rf.Value, args []ast.Expr, env *EvalEnv) rf.Value {
	if len(args) != 2 {
		panic("slice.updateE(cond, expr): wrong arg count")
	}
	cond := makeCKVCallback(env, args[:1])
	alter := makeCKVCallback(env, args[1:2])
	n := 0
	for i := 0; i < obj.Len(); i++ {
		v := obj.Index(i)
		k := rf.ValueOf(i)
		if cond(obj, k, v).Bool() {
			val := valueCopy(v)
			if alter(obj, k, val).Bool() && env.onObjUpdate(obj, k, val) {
				v.Set(val)
				env.dirty = true
				n++
			}
		}
	}
	return rf.ValueOf(n)
}

func sliceMapE(obj rf.Value, fn ckvCallback) rf.Value {
	res := make([]interface{}, obj.Len())
	for i := 0; i < obj.Len(); i++ {
		v := obj.Index(i)
		res[i] = fn(obj, rf.ValueOf(i), v).Interface()
	}
	return rf.ValueOf(res)
}

func sliceFilterE(obj rf.Value, fn ckvCallback) rf.Value {
	res := rf.MakeSlice(obj.Type(), 0, 0)
	for i := 0; i < obj.Len(); i++ {
		v := obj.Index(i)
		if fn(obj, rf.ValueOf(i), v).Bool() {
			res = rf.Append(res, v)
		}
	}
	return res
}

func sliceSwapE(obj rf.Value, args []ast.Expr, env *EvalEnv) rf.Value {
	if len(args) != 2 {
		panic("slice.swapE(filter_a, filter_b): wrong arg count")
	}
	fa := makeCKVCallback(env, args[:1])
	fb := makeCKVCallback(env, args[1:2])
	ia, ib := -1, -1
	for i := 0; i < obj.Len(); i++ {
		v := obj.Index(i)
		if ia < 0 && fa(obj, rf.ValueOf(i), v).Bool() {
			ia = i
		} else if ib < 0 && fb(obj, rf.ValueOf(i), v).Bool() {
			ib = i
		}
		if ia >= 0 && ib >= 0 {
			if !env.onObjSwap(obj, rf.ValueOf(ia), rf.ValueOf(ib)) {
				return rf.ValueOf(false)
			}
			a := obj.Index(ia).Interface() // get copy by Interface()
			obj.Index(ia).Set(obj.Index(ib))
			obj.Index(ib).Set(rf.ValueOf(a))
			env.dirty = true
			return rf.ValueOf(true)
		}
	}
	return rf.ValueOf(false)
}

type sliceSortCallback func(a, b rf.Value) rf.Value

type sliceSortType struct {
	slice []rf.Value
	less  sliceSortCallback
}

func (c *sliceSortType) Len() int {
	return len(c.slice)
}

func (c *sliceSortType) Swap(i, j int) {
	c.slice[i], c.slice[j] = c.slice[j], c.slice[i]
}

func (c *sliceSortType) Less(i, j int) bool {
	return c.less(c.slice[i], c.slice[j]).Bool()
}

func sliceSortE(obj rf.Value, args []ast.Expr, env *EvalEnv) rf.Value {
	if len(args) != 1 {
		panic("wrong arg count")
	}
	expr := args[0]
	cb := func(a, b rf.Value) rf.Value {
		vars := map[string]rf.Value{"a": a, "b": b}
		return env.evalWithVars(expr, vars)
	}
	ss := &sliceSortType{make([]rf.Value, obj.Len()), cb}
	for i := 0; i < obj.Len(); i++ {
		ss.slice[i] = obj.Index(i)
	}
	sort.Sort(ss)
	res := rf.MakeSlice(obj.Type(), obj.Len(), obj.Len())
	for i := 0; i < obj.Len(); i++ {
		res.Index(i).Set(ss.slice[i])
	}
	return res
}

func callObjBoolCb(name string, args ...rf.Value) (exist bool, ret rf.Value) {
	for i := range args {
		switch args[i].Kind() {
		case rf.Array, rf.Struct:
			args[i] = args[i].Addr()
		}
	}
	if method, ok := args[0].Type().MethodByName(name); ok {
		ret := method.Func.Call(args)
		if len(ret) != 1 || ret[0].Kind() != rf.Bool {
			panic(name + "() not return bool value")
		}
		return true, ret[0]
	}
	return false, rf.Value{}
}

func (env *EvalEnv) onObjSet(obj, val rf.Value) bool {
	if host := env.curScope.objhost[obj.Addr().Interface()]; host != nil {
		exist, ret := callObjBoolCb("On"+host.field+"Set", host.ptr, val)
		return !exist || ret.Bool()
	}
	return true
}

func (env *EvalEnv) onObjInsert(obj, k, v rf.Value) bool {
	if host := env.curScope.objhost[obj.Addr().Interface()]; host != nil {
		exist, ret := callObjBoolCb("On"+host.field+"Insert", host.ptr, obj, k, v)
		return !exist || ret.Bool()
	}
	return true
}

func (env *EvalEnv) onObjUpdate(obj, k, v rf.Value) bool {
	if host := env.curScope.objhost[obj.Addr().Interface()]; host != nil {
		exist, ret := callObjBoolCb("On"+host.field+"Update", host.ptr, obj, k, v)
		return !exist || ret.Bool()
	}
	return true
}

func (env *EvalEnv) onObjDelete(obj, k, v rf.Value) bool {
	if host := env.curScope.objhost[obj.Addr().Interface()]; host != nil {
		exist, ret := callObjBoolCb("On"+host.field+"Delete", host.ptr, obj, k, v)
		return !exist || ret.Bool()
	}
	return true
}

func (env *EvalEnv) onObjSwap(obj, ia, ib rf.Value) bool {
	if host := env.curScope.objhost[obj.Addr().Interface()]; host != nil {
		exist, ret := callObjBoolCb("On"+host.field+"Swap", host.ptr, obj, ia, ib)
		return !exist || ret.Bool()
	}
	return true
}

func valueCopy(val rf.Value) rf.Value {
	origJson, err := json.Marshal(val.Interface())
	if err != nil {
		panic(err)
	}
	newValPtr := rf.New(val.Type())
	err = json.Unmarshal(origJson, newValPtr.Interface())
	if err != nil {
		panic(err)
	}
	return newValPtr.Elem()
}
