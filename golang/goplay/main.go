package main

import (
	"crypto/rand"
	"encoding/json"
	"fmt"
	_ "github.com/aws/aws-sdk-go-v2/service/lexruntimeservice"
	"goplay/aws/lex"
	"log"
	"sync"
	"sync/atomic"
	"time"
)

func main() {
	start := time.Now()
	/*lexBot := lex.GetLexBot("emma_ai_chatbot_uat", "working")
	_ = lex.GetBotIntentInfo(lexBot)*/
	botName, botAlias := "emma_ai_chatbot_uat", "working"
	utteranceList := lex.GetBotUtterancesReplaced(botName, botAlias)
	wg := sync.WaitGroup{}

	limiter := make(chan int, 50)
	var successCnt uint64
	var errorCnt uint64
	for _, utt := range utteranceList {
		limiter <- 1
		wg.Add(1)
		utt := utt
		go func() {
			if _, err := lex.PostText(botName, botAlias, utt, createGuid(), nil); err != nil {
				atomic.AddUint64(&errorCnt, 1)
			} else {
				atomic.AddUint64(&successCnt, 1)
			}
			<-limiter
			wg.Done()
		}()
	}

	close(limiter)
	wg.Wait()
	fmt.Println(time.Since(start), len(utteranceList), successCnt, errorCnt)
}

func createGuid() string {
	b := make([]byte, 16)
	_, err := rand.Read(b)
	if err != nil {
		log.Fatal(err)
	}
	return fmt.Sprintf("%x-%x-%x-%x-%x",
		b[0:4], b[4:6], b[6:8], b[8:10], b[10:])
}

func prettyPrint(v interface{}) (err error) {
	b, err := json.MarshalIndent(v, "", "  ")
	if err == nil {
		fmt.Println(string(b))
	}
	return
}
