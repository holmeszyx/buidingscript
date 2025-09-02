package main

import (
	"flag"
	"fmt"
	"gpm"
	"os"
	"strings"
	"sync"
)

const (
	VERSION     = "0.0.1"
	OP_TYPE_SET = "set"
	OP_TYPE_RM  = "rm"
)

type Operation struct {
	Type    string // "set" or "rm"
	Key     string
	Value   string // only used for "set" operations
	Comment string // only used for "set" operations
}

type StringSlice []string

func (s *StringSlice) String() string {
	return strings.Join(*s, ",")
}

func (s *StringSlice) Set(value string) error {
	*s = append(*s, value)
	return nil
}

var (
	inputFile  = flag.String("input", "local.properties", "Input property file")
	outputFile = flag.String("output", "", "Output property file, default is the same file as input")
	setArgs    StringSlice
	rmArgs     StringSlice
)

func init() {
	flag.Var(&setArgs, "set", "Set property in format 'key=value' or 'key=value#comment' (can be used multiple times)")
	flag.Var(&rmArgs, "rm", "Remove property by key (can be used multiple times)")
	flag.Usage = func() {
		fmt.Println("Usage: property-modify [options]")
		fmt.Printf("version: %s \n", VERSION)
		flag.PrintDefaults()
	}
}

func parseSetArg(arg string) (key, value, comment string, err error) {
	parts := strings.SplitN(arg, "=", 2)
	if len(parts) != 2 {
		return "", "", "", fmt.Errorf("invalid set format: %s (expected key=value)", arg)
	}

	key = parts[0]
	valueAndComment := parts[1]

	if commentIdx := strings.Index(valueAndComment, "#"); commentIdx != -1 {
		value = valueAndComment[:commentIdx]
		comment = valueAndComment[commentIdx+1:]
	} else {
		value = valueAndComment
	}

	return key, value, comment, nil
}

func buildOperationList() ([]Operation, error) {
	var operations []Operation

	for _, setArg := range setArgs {
		key, value, comment, err := parseSetArg(setArg)
		if err != nil {
			return nil, err
		}
		operations = append(operations, Operation{
			Type:    OP_TYPE_SET,
			Key:     key,
			Value:   value,
			Comment: comment,
		})
	}

	// keep the remove operations at the end
	for _, rmArg := range rmArgs {
		operations = append(operations, Operation{
			Type: OP_TYPE_RM,
			Key:  rmArg,
		})
	}

	return operations, nil
}

func main() {
	flag.Parse()

	if *outputFile == "" {
		*outputFile = *inputFile
	}

	operations, err := buildOperationList()
	if err != nil {
		fmt.Println("Error parsing arguments:", err)
		return
	}

	if len(operations) == 0 {
		fmt.Println("No operations specified. Use -set or -rm flags to modify properties.")
		return
	}

	parser, err := func() (parser *gpm.Parser, err error) {
		once := sync.Once{}
		file, err := os.Open(*inputFile)
		if err != nil {
			fmt.Println("Error opening input file:", err)
			return nil, err
		}
		close := func() {
			file.Close()
		}
		defer once.Do(close)

		parser = gpm.NewParser()
		err = parser.Parse(file)
		if err != nil {
			fmt.Println("Error parsing input file:", err)
			return nil, err
		}
		once.Do(close)
		return
	}()
	if err != nil {
		return
	}

	modifier := gpm.NewModifier(parser.GetProps())
	modifier.Prepare()

	for _, op := range operations {
		switch op.Type {
		case OP_TYPE_SET:
			var comment *string
			if op.Comment != "" {
				comment = &op.Comment
			}
			modifier.SetProperty(op.Key, op.Value, comment)
		case OP_TYPE_RM:
			modifier.RemoveProperty(op.Key)
		}
	}

	outTmpFile := *outputFile + ".tmp"

	err = func() (err error) {
		file, err := os.Create(outTmpFile)
		if err != nil {
			fmt.Println("Error creating output file:", err)
			return err
		}
		defer file.Close()

		err = modifier.Save(file)
		if err != nil {
			fmt.Println("Error saving output file:", err)
			return err
		}

		return nil
	}()
	if err != nil {
		return
	}

	// replace the original file with the new file
	err = os.Rename(outTmpFile, *outputFile)
	if err != nil {
		fmt.Println("Error renaming output file:", err)
		return
	}
}
