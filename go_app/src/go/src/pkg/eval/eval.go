package eval

import (
	"bytes"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	rf "reflect"
	"strings"
)

var (
	globalVars = map[string]rf.Value{
		"true":  rf.ValueOf(true),
		"false": rf.ValueOf(false),
	}
)

type EvalEnv struct {
	curScope *evalScope
	dirty    bool
	dirtyCb  func() bool
}

type evalScope struct {
	outer   *evalScope
	vars    map[string]rf.Value
	objhost map[interface{}]*objHost // get struct ptr by field ptr
}

type objHost struct {
	field string   // field name
	ptr   rf.Value // struct ptr
}

func NewEvalEnv() *EvalEnv {
	return &EvalEnv{
		curScope: newEvalScope(nil, nil),
		dirty:    false,
		dirtyCb:  nil,
	}
}

func newEvalScope(outer *evalScope, vars map[string]rf.Value) *evalScope {
	if vars == nil {
		vars = map[string]rf.Value{}
	}
	return &evalScope{
		outer:   outer,
		vars:    vars,
		objhost: map[interface{}]*objHost{},
	}
}

func (env *EvalEnv) AddVar(name string, value interface{}) {
	if _, ok := env.curScope.vars[name]; ok {
		panic("var already exists: " + name)
	}
	env.curScope.vars[name] = rf.ValueOf(value)
}

func (env *EvalEnv) OnDirty(cb func() bool) {
	env.dirtyCb = cb
}

func (env *EvalEnv) Eval(expr string, res interface{}) (err error) {
	result := rf.ValueOf(res)
	if result.Kind() != rf.Ptr {
		return fmt.Errorf("res is not pointer: %s", result.Type().String())
	}

	ast, err := parser.ParseExpr(expr)
	if err != nil {
		return err
	}

	defer func() {
		if e := recover(); e != nil {
			err = fmt.Errorf("%v", e)
		}
	}()

	obj := env.evalWithVars(ast, globalVars)
	if obj.IsValid() {
		result.Elem().Set(obj)
	} else {
		*res.(*interface{}) = nil
	}

	if env.dirty {
		if env.dirtyCb == nil || env.dirtyCb() {
			env.dirty = false
		}
	}

	return nil
}

func (env *EvalEnv) evalWithVars(expr ast.Expr, vars map[string]rf.Value) rf.Value {
	env.curScope = newEvalScope(env.curScope, vars)
	ret := env.eval(expr)
	env.curScope = env.curScope.outer
	return ret
}

func (env *EvalEnv) eval(expr ast.Expr) rf.Value {
	switch e := expr.(type) {
	case *ast.BasicLit:
		return evalLit(e)
	case *ast.Ident:
		return env.evalIdent(e)
	case *ast.SliceExpr:
		return env.evalSlice(e)
	case *ast.UnaryExpr:
		return env.evalUnary(e)
	case *ast.BinaryExpr:
		return env.evalBinary(e)
	case *ast.SelectorExpr:
		return env.evalSelector(e)
	case *ast.IndexExpr:
		return env.evalIndex(e)
	case *ast.CallExpr:
		return env.evalCall(e)
	case *ast.ParenExpr:
		return env.eval(e.X)
	}
	panic("eval error:\n" + exprToString(expr))
}

func evalLit(expr *ast.BasicLit) rf.Value {
	fn := func(verb string, p interface{}) {
		_, err := fmt.Sscanf(expr.Value, verb, p)
		if err != nil {
			panic(err)
		}
	}
	var res interface{}
	switch expr.Kind {
	default:
		panic("evalLit error: " + expr.Value)
	case token.STRING:
		var v string
		fn("%q", &v)
		res = v
	case token.INT:
		var v int64
		fn("%v", &v)
		res = v
	case token.FLOAT:
		var v float64
		fn("%v", &v)
		res = v
	}
	return rf.ValueOf(res)
}

func (env *EvalEnv) evalIdent(expr *ast.Ident) rf.Value {
	name := expr.Name
	for scope := env.curScope; scope != nil; scope = scope.outer {
		if val, ok := scope.vars[name]; ok {
			return val
		}
	}
	panic("no such var: " + name)
}

func (env *EvalEnv) evalSlice(expr *ast.SliceExpr) rf.Value {
	obj := env.eval(expr.X)
start:
	switch obj.Kind() {
	case rf.Ptr, rf.Interface:
		obj = obj.Elem()
		goto start
	case rf.String, rf.Slice:
		beg, end := 0, obj.Len()
		if expr.Low != nil {
			beg = getIndex(env.eval(expr.Low), 0, end)
		}
		if expr.High != nil {
			end = getIndex(env.eval(expr.High), 0, end)
		}
		if obj.Kind() == rf.String { // TODO: Slice already support String in new version
			return rf.ValueOf(obj.String()[beg:end])
		}
		return obj.Slice(beg, end)
	}
	panic("evalSlice error: type mismatch")
}

func (env *EvalEnv) evalIndex(expr *ast.IndexExpr) rf.Value {
	obj := env.eval(expr.X)
start:
	switch obj.Kind() {
	case rf.Ptr, rf.Interface:
		obj = obj.Elem()
		goto start
	case rf.String, rf.Slice:
		idx := getIndex(env.eval(expr.Index), 0, obj.Len())
		if obj.Kind() == rf.String { // TODO: Index already support String in new version
			return rf.ValueOf(obj.String()[idx])
		}
		return obj.Index(idx)
	case rf.Map:
		idx := env.eval(expr.Index)
		if idx.Type() == obj.Type().Key() {
			value := obj.MapIndex(idx)
			if value.IsValid() {
				return value
			}
			panic(fmt.Errorf("[%v] map key not found", idx.Interface()))
		}
		panic(fmt.Errorf("[%v] type mismatch: %s", idx.Interface(), obj.Type().String()))
	}
	panic("evalIndex error: type mismatch")
}

func getIndex(idx rf.Value, min, max int) int {
	switch idx.Kind() {
	case rf.Int, rf.Int8, rf.Int16, rf.Int32, rf.Int64:
		v := idx.Int()
		if v < int64(min) || v >= int64(max) {
			panic(fmt.Errorf("index [%d] out of range: [%d, %d)", v, min, max))
		}
		return int(v)
	case rf.Uint, rf.Uint8, rf.Uint16, rf.Uint32, rf.Uint64:
		v := idx.Uint()
		if min < 0 {
			min = 0
		}
		if max < 0 {
			max = 0
		}
		if v < uint64(min) || v >= uint64(max) {
			panic(fmt.Errorf("index [%d] out of range: [%d, %d)", v, min, max))
		}
		return int(v)
	}
	panic("index is not integer")
}

func exprToString(expr ast.Expr) string {
	var buf bytes.Buffer
	ast.Fprint(&buf, nil, expr, nil)
	return buf.String()
}

func stringToIp4(str string) (uint32, error) {
	var a, b, c, d uint32
	str = strings.TrimSpace(str)
	n, err := fmt.Sscanf(str, "%d.%d.%d.%d\n", &a, &b, &c, &d)
	if err != nil {
		return 0, err
	}
	if n != 4 || a > 255 || b > 255 || c > 255 || d > 255 {
		return 0, fmt.Errorf("wrong ip format")
	}
	return a<<24 | b<<16 | c<<8 | d, nil
}

func ip4ToString(ip uint32) string {
	a := (ip >> 24) & 0xff
	b := (ip >> 16) & 0xff
	c := (ip >> 8) & 0xff
	d := ip & 0xff
	return fmt.Sprintf("%d.%d.%d.%d", a, b, c, d)
}
