.PHONY: deps clean build

deps:
	go get -u ./...

clean: 
	rm -rf ./rekognition/rekognition
	
build:
	GOOS=linux GOARCH=amd64 go build -o rekognition/rekognition ./rekognition

local:
	sam local start-api -t template.yaml --env-vars env.json

deploy:
	make build
	sam package --template-file template.yaml --s3-bucket firefly-sam-bucket --output-template-file packaged.yaml
	sam deploy --template-file packaged.yaml --stack-name firefly-api --capabilities CAPABILITY_IAM --region ap-northeast-1
