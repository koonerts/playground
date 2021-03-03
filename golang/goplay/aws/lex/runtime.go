package lex

import (
	"context"
	"github.com/aws/aws-sdk-go-v2/aws"
	lrs "github.com/aws/aws-sdk-go-v2/service/lexruntimeservice"
	"goplay/aws/config"
)

var client *lrs.Client

func GetLexRuntimeClient() *lrs.Client {
	if client != nil {
		return client
	} else {
		cfg := config.GetDefaultConfig()
		return lrs.NewFromConfig(cfg)
	}
}

func PostText(botName, botAlias, inputText, userId string, sessionAttributes map[string]string) (resp *lrs.PostTextOutput, err error) {
	req := &lrs.PostTextInput {
		BotName: aws.String(botName), BotAlias: aws.String(botAlias), InputText: aws.String(inputText),
		UserId: aws.String(userId), SessionAttributes: sessionAttributes,
	}

	client := GetLexRuntimeClient()
	return client.PostText(context.TODO(), req)
}
