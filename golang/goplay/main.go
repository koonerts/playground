package main

import (
	"encoding/json"
	"fmt"
	"goplay/aws/lex"
	"time"
)


func main() {
	start := time.Now()
	client := lex.GetClient()
	lexBot := lex.GetLexBot(client, "emma_ai_chatbot_uat", "working")
	_ = lex.GetIntentMap(client, lexBot)
	fmt.Println(time.Since(start))
}

func prettyPrint(v interface{}) (err error) {
	b, err := json.MarshalIndent(v, "", "  ")
	if err == nil {
		fmt.Println(string(b))
	}
	return
}
