package gpm

import (
	"bufio"
	"fmt"
	"io"
	"strings"
)

const (
	COMMENT = '#'
	EQUALS  = '='
	NO_LINE = -1
)

type rawLine []rune

// Parser represents a parser for a specific format of property files.
type Parser struct {
	lines []rawLine
	props []Property
}

type Property struct {
	key        string
	value      string
	comment    string
	hasComment bool
	lineNum    int
}

func (p *Property) String() string {
	if p.IsEmpty() {
		return ""
	}

	if p.IsCommentOnly() {
		if p.comment == "" {
			return "#"
		}
		if p.comment[0] == COMMENT {
			return "#" + p.comment
		}
		return fmt.Sprintf("# %s", p.comment)
	}

	if p.hasComment {
		if p.comment == "" {
			return fmt.Sprintf("%s=%s #", p.key, p.value)
		}
		if p.comment[0] == COMMENT {
			return fmt.Sprintf("%s=%s #%s", p.key, p.value, p.comment)
		}
		return fmt.Sprintf("%s=%s # %s", p.key, p.value, p.comment)
	}

	return fmt.Sprintf("%s=%s", p.key, p.value)
}

func (p *Property) IsCommentOnly() bool {
	return p.key == "" && p.hasComment
}

func (p *Property) IsEmpty() bool {
	return p.key == "" && !p.hasComment
}

// NewParser creates a new Parser instance.
func NewParser() *Parser {
	return &Parser{}
}

func (p *Parser) Parse(r io.Reader) error {
	buf := bufio.NewScanner(r)
	p.lines = make([]rawLine, 0, 64)
	for buf.Scan() {
		rLine := buf.Text()
		runes := rawLine(strings.TrimSpace(rLine))
		p.lines = append(p.lines, runes)

	}
	if err := buf.Err(); err != nil {
		return err
	}

	p.props = make([]Property, 0, len(p.lines))
	for i, line := range p.lines {
		prop := p.parseTokens(line, i)
		p.props = append(p.props, prop)
	}
	return nil
}

func (p *Parser) parseTokens(pureLine rawLine, lineNum int) Property {
	var key, value, comment string
	var hasComment bool
	var valueEndAt int = -1
	var firstEqAt int = -1

	for i, r := range pureLine {
		if r == COMMENT {
			if i != len(pureLine)-1 {
				comment = string(pureLine[i+1:])
				comment = strings.TrimSpace(comment)
			}
			hasComment = true
			valueEndAt = i - 1
			break
		}
		if r == EQUALS {
			if firstEqAt != -1 {
				// do nothing
			} else {
				firstEqAt = i
				key = string(pureLine[:i])
				key = strings.TrimSpace(key)
				continue
			}
		}
		valueEndAt = i
	}
	if valueEndAt != -1 {
		if firstEqAt == -1 {
			// do nothing
		} else {
			value = string(pureLine[firstEqAt+1 : valueEndAt+1])
			value = strings.TrimSpace(value)
		}
	}

	return Property{
		key:        key,
		value:      value,
		comment:    comment,
		hasComment: hasComment,
		lineNum:    lineNum,
	}
}

func (p *Parser) GetProps() []Property {
	return p.props
}
