package main

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"strings"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/rekognition"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws/session"
)

// APIRequest is post Request struct
type APIRequest struct {
	Image string `json:"image"`
}

func generateRekogClient() *rekognition.Rekognition {
	sess := session.Must(session.NewSession())
	return rekognition.New(sess, aws.NewConfig().WithRegion("ap-northeast-1"))
}

func handler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	bytes := []byte(request.Body)
	var r APIRequest
	defaultHeader := map[string]string{
		"Access-Control-Allow-Origin":  "*",
		"Access-Control-Allow-Headers": "origin,Accept,Authorization,Content-Type",
		"Content-Type":                 "application/json",
	}

	_ = json.Unmarshal(bytes, &r)

	bucket := os.Getenv("TARGET_IMAGE_NAME")
	key := os.Getenv("TARGET_IMAGE_KEY")
	rekogClient := generateRekogClient()
	fileBase64 := strings.Split(r.Image, ",")

	byteIMAGE, _ := base64.StdEncoding.DecodeString(fileBase64[1])

	result, err := rekogClient.CompareFaces(&rekognition.CompareFacesInput{
		SourceImage: &rekognition.Image{
			Bytes: byteIMAGE,
		},
		TargetImage: &rekognition.Image{
			S3Object: &rekognition.S3Object{
				Bucket: &bucket,
				Name:   &key,
			},
		},
	})

	if err != nil {
		fmt.Println(err.Error())
		return events.APIGatewayProxyResponse{
			Headers:    defaultHeader,
			Body:       string(err.Error()),
			StatusCode: 500,
		}, nil
	}

	var response string
	response = "unmatch"

	if len(result.FaceMatches) != 0 && int(*result.FaceMatches[0].Similarity) >= 85 {
		response = "match"
	}

	return events.APIGatewayProxyResponse{
		Headers:    defaultHeader,
		Body:       response,
		StatusCode: 200,
	}, nil

}

func main() {
	lambda.Start(handler)
}
