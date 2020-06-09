package main

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/rekognition"
	"github.com/vincent-petithory/dataurl"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws/session"

	"github.com/aws/aws-sdk-go/service/s3/s3manager"
)

// APIRequest is post Request struct
type APIRequest struct {
	Image string `json:"image"`
}

func generateRekogClient() *rekognition.Rekognition {
	sess := session.Must(session.NewSession())
	return rekognition.New(sess, aws.NewConfig().WithRegion("ap-northeast-1"))
}

func generateS3Client() *s3manager.Uploader {
	sess := session.Must(session.NewSession(&aws.Config{
		Region: aws.String("ap-northeast-1"),
	}))
	return s3manager.NewUploader(sess)
}

func handler(request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	requestByte := []byte(request.Body)
	var r APIRequest
	defaultHeader := map[string]string{
		"Access-Control-Allow-Origin":  "*",
		"Access-Control-Allow-Headers": "origin,Accept,Authorization,Content-Type",
		"Content-Type":                 "application/json",
	}

	_ = json.Unmarshal(requestByte, &r)

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

		t := time.Now()
		extens, _ := dataurl.DecodeString(r.Image)

		fileExtension := strings.Split(extens.ContentType(), "/")

		filename := "kasumi_match_" + strconv.FormatInt(t.Unix(), 10) + "." + fileExtension[1]

		fmt.Println(filename)

		s3Manager := generateS3Client()
		_, err := s3Manager.Upload(&s3manager.UploadInput{
			Bucket: aws.String(bucket),
			Key:    aws.String("/match/" + filename),
			Body:   bytes.NewReader(byteIMAGE),
		})

		if err != nil {
			fmt.Println(err)
			panic(500)
		}
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
