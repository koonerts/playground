package lex

import (
	"context"
	"github.com/aws/aws-sdk-go-v2/aws"
	lmbs "github.com/aws/aws-sdk-go-v2/service/lexmodelbuildingservice"
	"goplay/aws/config"
	"log"
	"sync"
)


func GetClient() *lmbs.Client {
	cfg := config.GetDefaultConfig()
	return lmbs.NewFromConfig(cfg)
}

func GetLexBot(client *lmbs.Client, botName, botAlias string) *lmbs.GetBotOutput {
	bot, err := client.GetBot(context.TODO(), &lmbs.GetBotInput{aws.String(botName), aws.String(botAlias)})
	if err != nil {
		log.Fatal(err)
	}
	return bot
}

func GetIntentMap(client *lmbs.Client, lexBot *lmbs.GetBotOutput) map[string]*lmbs.GetIntentOutput {
	intentMap := map[string]*lmbs.GetIntentOutput{}
	wg := sync.WaitGroup{}
	for _, intent := range lexBot.Intents {
		wg.Add(1)
		go func(getIntentReq *lmbs.GetIntentInput) {
			resp, _ := client.GetIntent(context.TODO(), getIntentReq)
			intentMap[*resp.Name] = resp
			wg.Done()
		}(&lmbs.GetIntentInput{intent.IntentName, intent.IntentVersion})
	}
	wg.Wait()
	return intentMap
}




