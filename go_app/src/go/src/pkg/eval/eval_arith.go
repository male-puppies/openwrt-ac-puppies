package eval

import (
	"go/ast"
	"go/token"
	rf "reflect"
)

func (env *EvalEnv) evalUnary(expr *ast.UnaryExpr) rf.Value {
	x := env.eval(expr.X)
	var res interface{}
	switch expr.Op {
	default:
		panic("evalUnary error")
	case token.NOT:
		res = !x.Bool()
	case token.ADD:
		switch x.Kind() {
		default:
			panic("type mismatch")
		case rf.Int:
			res = int(x.Int())
		case rf.Int8:
			res = int8(x.Int())
		case rf.Int16:
			res = int16(x.Int())
		case rf.Int32:
			res = int32(x.Int())
		case rf.Int64:
			res = int64(x.Int())
		case rf.Uint:
			res = uint(x.Uint())
		case rf.Uint8:
			res = uint8(x.Uint())
		case rf.Uint16:
			res = uint16(x.Uint())
		case rf.Uint32:
			res = uint32(x.Uint())
		case rf.Uint64:
			res = uint64(x.Uint())
		case rf.Float32:
			res = float32(x.Float())
		case rf.Float64:
			res = float64(x.Float())
		}
	case token.SUB:
		switch x.Kind() {
		default:
			panic("type mismatch")
		case rf.Int:
			res = -int(x.Int())
		case rf.Int8:
			res = -int8(x.Int())
		case rf.Int16:
			res = -int16(x.Int())
		case rf.Int32:
			res = -int32(x.Int())
		case rf.Int64:
			res = -int64(x.Int())
		case rf.Uint:
			res = -int(x.Uint())
		case rf.Uint8:
			res = -int8(x.Uint())
		case rf.Uint16:
			res = -int16(x.Uint())
		case rf.Uint32:
			res = -int32(x.Uint())
		case rf.Uint64:
			res = -int64(x.Uint())
		case rf.Float32:
			res = -float32(x.Float())
		case rf.Float64:
			res = -float64(x.Float())
		}
	case token.XOR:
		switch x.Kind() {
		default:
			panic("type mismatch")
		case rf.Int:
			res = ^int(x.Int())
		case rf.Int8:
			res = ^int8(x.Int())
		case rf.Int16:
			res = ^int16(x.Int())
		case rf.Int32:
			res = ^int32(x.Int())
		case rf.Int64:
			res = ^int64(x.Int())
		case rf.Uint:
			res = ^uint(x.Uint())
		case rf.Uint8:
			res = ^uint8(x.Uint())
		case rf.Uint16:
			res = ^uint16(x.Uint())
		case rf.Uint32:
			res = ^uint32(x.Uint())
		case rf.Uint64:
			res = ^uint64(x.Uint())
		}
	}
	return rf.ValueOf(res)
}

func (env *EvalEnv) evalBinary(expr *ast.BinaryExpr) rf.Value {
	switch expr.Op {
	case token.LAND:
		return rf.ValueOf(env.eval(expr.X).Bool() && env.eval(expr.Y).Bool())
	case token.LOR:
		return rf.ValueOf(env.eval(expr.X).Bool() || env.eval(expr.Y).Bool())
	}

	x, y := env.eval(expr.X), env.eval(expr.Y)

	var largerKind rf.Kind
	if x.Type().Size() > y.Type().Size() {
		largerKind = x.Kind()
	} else {
		largerKind = y.Kind()
	}

	valueNormalize(&x)
	valueNormalize(&y)

	switch expr.Op {
	case token.EQL:
		return rf.ValueOf(env.evalOpEqual(x, y))
	case token.NEQ:
		return rf.ValueOf(!env.evalOpEqual(x, y))
	}

	if x.Kind() != y.Kind() {
		panic("evalBinary error: type mismatch")
	}

	switch expr.Op {
	case token.LSS:
		return rf.ValueOf(env.evalOpLess(x, y))
	case token.GTR:
		return rf.ValueOf(env.evalOpLess(y, x))
	case token.LEQ:
		return rf.ValueOf(!env.evalOpLess(y, x))
	case token.GEQ:
		return rf.ValueOf(!env.evalOpLess(x, y))
	}

	var res interface{}

	switch expr.Op {
	default:
		panic("evalBinary error: operator not supported")
	case token.ADD:
		res = env.evalOpAdd(x, y)
	case token.SUB:
		res = env.evalOpSub(x, y)
	case token.MUL:
		res = env.evalOpMul(x, y)
	case token.QUO:
		res = env.evalOpDiv(x, y)
	case token.REM:
		res = env.evalOpMod(x, y)
	}

	switch largerKind {
	default:
		panic("type mismatch")
	case rf.String:
	case rf.Int:
		res = int(res.(int64))
	case rf.Int8:
		res = int8(res.(int64))
	case rf.Int16:
		res = int16(res.(int64))
	case rf.Int32:
		res = int32(res.(int64))
	case rf.Int64:
		res = int64(res.(int64))
	case rf.Uint:
		res = uint(res.(uint64))
	case rf.Uint8:
		res = uint8(res.(uint64))
	case rf.Uint16:
		res = uint16(res.(uint64))
	case rf.Uint32:
		res = uint32(res.(uint64))
	case rf.Uint64:
		res = uint64(res.(uint64))
	case rf.Float32:
		res = float32(res.(float64))
	case rf.Float64:
		res = float64(res.(float64))
	}

	return rf.ValueOf(res)
}

func valueNormalize(n *rf.Value) {
	switch n.Kind() {
	case rf.Int, rf.Int8, rf.Int16, rf.Int32:
		*n = rf.ValueOf(n.Int())
	case rf.Uint, rf.Uint8, rf.Uint16, rf.Uint32:
		*n = rf.ValueOf(n.Uint())
	case rf.Float32:
		*n = rf.ValueOf(n.Float())
	}
}

func (env *EvalEnv) evalOpEqual(x, y rf.Value) bool {
	switch x.Kind() {
	case rf.Int64:
		a := x.Int()
		switch y.Kind() {
		case rf.Uint64:
			return uint64(a) == y.Uint()
		case rf.Float64:
			return float64(a) == y.Float()
		}
	case rf.Uint64:
		a := x.Uint()
		switch y.Kind() {
		case rf.Int64:
			return a == uint64(y.Int())
		case rf.Float64:
			return float64(a) == y.Float()
		}
	case rf.Float64:
		a := x.Float()
		switch y.Kind() {
		case rf.Int64:
			return a == float64(y.Int())
		case rf.Uint64:
			return a == float64(y.Uint())
		}
	}
	return x.Interface() == y.Interface()
}

func (env *EvalEnv) evalOpLess(x, y rf.Value) bool {
	var res bool
	switch x.Kind() {
	default:
		panic("evalOpLess error: type not support")
	case rf.Int64:
		res = x.Int() < y.Int()
	case rf.Uint64:
		res = x.Uint() < y.Uint()
	case rf.String:
		res = x.String() < y.String()
	case rf.Float64:
		res = x.Float() < y.Float()
	}
	return res
}

func (env *EvalEnv) evalOpAdd(x, y rf.Value) interface{} {
	switch x.Kind() {
	default:
		panic("evalOpAdd error: type not support")
	case rf.Int64:
		return x.Int() + y.Int()
	case rf.Uint64:
		return x.Uint() + y.Uint()
	case rf.String:
		return x.String() + y.String()
	case rf.Float64:
		return x.Float() + y.Float()
	}
	return nil
}

func (env *EvalEnv) evalOpSub(x, y rf.Value) interface{} {
	switch x.Kind() {
	default:
		panic("evalOpSub error: type not support")
	case rf.Int64:
		return x.Int() - y.Int()
	case rf.Uint64:
		return x.Uint() - y.Uint()
	case rf.Float64:
		return x.Float() - y.Float()
	}
	return nil
}

func (env *EvalEnv) evalOpMul(x, y rf.Value) interface{} {
	switch x.Kind() {
	default:
		panic("evalOpMul error: type not support")
	case rf.Int64:
		return x.Int() * y.Int()
	case rf.Uint64:
		return x.Uint() * y.Uint()
	case rf.Float64:
		return x.Float() * y.Float()
	}
	return nil
}

func (env *EvalEnv) evalOpDiv(x, y rf.Value) interface{} {
	switch x.Kind() {
	default:
		panic("evalOpDiv error: type not support")
	case rf.Int64:
		return x.Int() / y.Int()
	case rf.Uint64:
		return x.Uint() / y.Uint()
	case rf.Float64:
		return x.Float() / y.Float()
	}
	return nil
}

func (env *EvalEnv) evalOpMod(x, y rf.Value) interface{} {
	switch x.Kind() {
	default:
		panic("evalOpMod error: type not support")
	case rf.Int64:
		return x.Int() % y.Int()
	case rf.Uint64:
		return x.Uint() % y.Uint()
	}
	return nil
}
