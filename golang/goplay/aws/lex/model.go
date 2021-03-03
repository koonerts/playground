package lex

import (
	"context"
	"github.com/aws/aws-sdk-go-v2/aws"
	lmbs "github.com/aws/aws-sdk-go-v2/service/lexmodelbuildingservice"
	"goplay/aws/config"
	"log"
	"strings"
	"sync"
)

func GetLexModelClient() *lmbs.Client {
	cfg := config.GetDefaultConfig()
	return lmbs.NewFromConfig(cfg)
}

func GetLexBot(botName, botAlias string) *lmbs.GetBotOutput {
	client := GetLexModelClient()
	bot, err := client.GetBot(context.TODO(), &lmbs.GetBotInput{aws.String(botName), aws.String(botAlias)})
	if err != nil {
		log.Fatal(err)
	}
	return bot
}

type BotIntentInfo struct {
	IntentMap    map[string]*lmbs.GetIntentOutput
	SlotTypesMap map[string]*lmbs.GetSlotTypeOutput
}
func GetBotIntentInfo(botName, botAlias string) *BotIntentInfo {
	intentMap := map[string]*lmbs.GetIntentOutput{}
	slotTypeMap := map[string]*lmbs.GetSlotTypeOutput{}
	wg := sync.WaitGroup{}
	client := GetLexModelClient()
	lexBot := GetLexBot(botName, botAlias)
	for _, intent := range lexBot.Intents {
		wg.Add(1)
		go func(getIntentReq *lmbs.GetIntentInput) {
			getIntentResp, _ := client.GetIntent(context.TODO(), getIntentReq)

			if len(getIntentResp.Slots) > 0 {
				for _, slot := range getIntentResp.Slots {
					wg.Add(1)
					go func(getSlotTypeReq *lmbs.GetSlotTypeInput) {
						getSlotTypeResp, _ := client.GetSlotType(context.TODO(), getSlotTypeReq)
						slotTypeMap[*getSlotTypeResp.Name] = getSlotTypeResp
						wg.Done()
					}(&lmbs.GetSlotTypeInput{slot.SlotType, slot.SlotTypeVersion})
				}
			}

			intentMap[*getIntentResp.Name] = getIntentResp
			wg.Done()
		}(&lmbs.GetIntentInput{intent.IntentName, intent.IntentVersion})
	}
	wg.Wait()

	return &BotIntentInfo{intentMap, slotTypeMap}
}

func GetBotUtterancesReplaced(botName, botAlias string) []string {
	botIntentInfoMap := GetBotIntentInfo(botName, botAlias)
	initLen := 0
	for i := range botIntentInfoMap.IntentMap {
		initLen += len(botIntentInfoMap.IntentMap[i].SampleUtterances)
	}

	utteranceList := make([]string, 0, initLen)
	for i := range botIntentInfoMap.IntentMap {
		for j := range botIntentInfoMap.IntentMap[i].SampleUtterances {
			utterance := botIntentInfoMap.IntentMap[i].SampleUtterances[j]
			if strings.Index(utterance, "{") != -1 {
				q := []string{utterance}
				var utt string
				for len(q) > 0 {
					utt, q = q[0], q[1:]
					start := strings.Index(utt, "{")
					if start != -1 {
						end := strings.Index(utt, "}")
						slotName := utt[start+1:end]
						var slotType *lmbs.GetSlotTypeOutput
						for _, slot := range botIntentInfoMap.IntentMap[i].Slots {
							if slotName == *slot.Name {
								slotType = botIntentInfoMap.SlotTypesMap[*slot.SlotType]
								break
							}
						}
						for _, val := range slotType.EnumerationValues {
							q = append(q, strings.Replace(utt, utt[start:end+1], *val.Value, -1))
						}
					} else {
						utteranceList = append(utteranceList, utt)
					}
				}
			}
		}
	}

	return utteranceList
}
