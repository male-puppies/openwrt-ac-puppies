package memory

import (
	"app/websrv/session"
	"container/list"
	"sync"
	"time"
)

/////////////////////////////////////////////////
//Provider
type Provider struct {
	lock     sync.Mutex               //用来锁
	sessions map[string]*list.Element //用来存储在内存
	list     *list.List               //用来做gc
}

var pder = &Provider{list: list.New()}

func init() {
	pder.sessions = make(map[string]*list.Element, 0)
	session.Register("memory", pder)
}

func (pder *Provider) SessionInit(sid string) (session.Session, error) {
	pder.lock.Lock()
	defer pder.lock.Unlock()
	v := make(map[interface{}]interface{}, 0)
	newsess := &SessionStore{sid: sid, timeAccessed: time.Now(), value: v}
	element := pder.list.PushBack(newsess)
	pder.sessions[sid] = element
	return newsess, nil
}

func (pder *Provider) SessionRead(sid string) (session.Session, error) {
	if element, ok := pder.sessions[sid]; ok {
		return element.Value.(*SessionStore), nil
	} else {
		sess, err := pder.SessionInit(sid)
		return sess, err
	}
	return nil, nil
}

func (pder *Provider) SessionDestroy(sid string) error {
	if element, ok := pder.sessions[sid]; ok {
		delete(pder.sessions, sid)
		pder.list.Remove(element)
		return nil
	}
	return nil
}

func (pder *Provider) AccountDestroy(accountname string) error {
	for k, v := range pder.sessions {
		name := v.Value.(*SessionStore).Get("accountname")
		if name != nil && name == accountname {
			delete(pder.sessions, k)
			pder.list.Remove(v)
		}
	}
	return nil
}

func (pder *Provider) SessionGC(maxlifetime int64) {
	pder.lock.Lock()
	defer pder.lock.Unlock()

	for {
		element := pder.list.Back()
		if element == nil {
			break
		}
		if (element.Value.(*SessionStore).timeAccessed.Unix() + maxlifetime) < time.Now().Unix() {
			pder.list.Remove(element)
			delete(pder.sessions, element.Value.(*SessionStore).sid)
		} else {
			break
		}
	}
}

func (pder *Provider) SessionUpdate(sid string) error {
	pder.lock.Lock()
	defer pder.lock.Unlock()
	if element, ok := pder.sessions[sid]; ok {
		element.Value.(*SessionStore).timeAccessed = time.Now()
		pder.list.MoveToFront(element)
		return nil
	}
	return nil
}

/////////////////////////////////////////////////
//SessionStore
type SessionStore struct {
	sid          string                      //session id唯一标示	  	
	timeAccessed time.Time                   //最后访问时间	  	
	value        map[interface{}]interface{} //session里面存储的值
}

func (st *SessionStore) Set(key, value interface{}) error {
	st.value[key] = value
	//pder.SessionUpdate(st.sid)
	return nil
}

func (st *SessionStore) Get(key interface{}) interface{} {
	//pder.SessionUpdate(st.sid)
	if v, ok := st.value[key]; ok {
		return v
	} else {
		return nil
	}
	return nil
}

func (st *SessionStore) Update() {
	pder.SessionUpdate(st.sid)
}

func (st *SessionStore) Delete(key interface{}) error {
	delete(st.value, key)
	//pder.SessionUpdate(st.sid)
	return nil
}

func (st *SessionStore) SessionID() string {
	return st.sid
}
