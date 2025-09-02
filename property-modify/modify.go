package gpm

import (
	"bufio"
	"io"
	"strings"
)

type Modifier struct {
	props []Property
	kv    map[string]Property

	// addProps    []Property
	// removeProps []Property
}

func NewModifier(props []Property) *Modifier {
	return &Modifier{
		props: props[:],
		kv:    make(map[string]Property),
	}
}

func (m *Modifier) Prepare() {
	for i, p := range m.props {
		p.lineNum = i + 1
		m.kv[p.key] = p
	}
}

func (m *Modifier) SetProperty(k, v string, comment *string) {
	prop := Property{
		key:     k,
		value:   v,
		comment: "",
		lineNum: NO_LINE,
	}
	if p, ok := m.kv[k]; ok {
		// modify
		prop.lineNum = p.lineNum
		if comment == nil {
			prop.comment = p.comment
		} else {
			prop.comment = *comment
		}
		m.kv[k] = prop
		m.props[p.lineNum-1] = prop
		return
	}
	prop.lineNum = len(m.props) + 1
	m.props = append(m.props, prop)
	m.kv[prop.key] = prop
}

func (m *Modifier) RemoveProperty(k string) bool {
	if p, ok := m.kv[k]; ok {
		delete(m.kv, k)
		idx := p.lineNum - 1
		m.props = append(m.props[:idx], m.props[idx+1:]...)
		return true
	}
	return false
}

func (m *Modifier) Text() string {
	var sb strings.Builder
	for _, p := range m.props {
		sb.WriteString(p.String())
		sb.WriteString("\n")
	}
	return sb.String()
}

func (m *Modifier) Save(w io.Writer) error {
	buf := bufio.NewWriter(w)
	for _, p := range m.props {
		buf.WriteString(p.String())
		buf.WriteString("\n")
	}
	return buf.Flush()
}
