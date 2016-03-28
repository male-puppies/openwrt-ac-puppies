package main

/*
*/
import "C"
import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"os"
	"pkg/eval/evalcli"
	"strings"
)

var (
	command = flag.String("c", "", "eval command")
)

func main() {
	flag.Parse()

	cli := evalcli.NewEvalClient("tcp", "127.0.0.1:19999")

	if *command != "" {
		var res interface{}
		err := cli.Eval(*command, &res)
		if err != nil {
			fmt.Fprintf(os.Stderr, "eval error: %s\n", err)
			os.Exit(1)
		}
		output, err := json.MarshalIndent(res, "", "   ")
		if err != nil {
			fmt.Fprintf(os.Stderr, "eval error: %s\n", err)
			os.Exit(1)
		}
		fmt.Println(string(output))
		return
	}

	stdin := bufio.NewReader(os.Stdin)
	for {
		fmt.Fprint(os.Stderr, "> ")

		cmd, err := stdin.ReadString('\n')
		if err != nil {
			if err == io.EOF {
				os.Exit(0)
			}
			fmt.Fprintf(os.Stderr, "eval error: %s\n", err)
			os.Exit(1)
		}

		cmd = strings.TrimSpace(cmd)
		if len(cmd) == 0 {
			continue
		}

		var res interface{}
		err = cli.Eval(cmd, &res)
		if err != nil {
			fmt.Fprintf(os.Stderr, "eval error: %s\n", err)
			continue
		}

		output, err := json.MarshalIndent(res, "", "   ")
		if err != nil {
			fmt.Fprintf(os.Stderr, "eval error: %s\n", err)
			continue
		}

		fmt.Println(string(output))
	}
}
