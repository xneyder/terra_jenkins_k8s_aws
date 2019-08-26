#!/usr/bin/bash

#Build the docker images
docker system prune -a -f
docker build -t top-api -f ../src/api/Dockerfile ../src/api/.
docker build -t top-web -f ../src/web/Dockerfile ../src/web/.
docker build -t top-pgbackup -f ../src/pgbackup/Dockerfile ../src/pgbackup/.
docker build -t top-jenkins -f ../src/jenkins/Dockerfile ../src/jenkins/.

#Login to aws ECR
aws ecr get-login --no-include-email --region us-east-1 | sh

#Create ECR repos
aws ecr create-repository --repository-name top-web --region us-east-1 > /dev/null 2>&1
aws ecr create-repository --repository-name top-api --region us-east-1 > /dev/null 2>&1
aws ecr create-repository --repository-name top-jenkins --region us-east-1 > /dev/null 2>&1
aws ecr create-repository --repository-name top-pgbackup --region us-east-1 > /dev/null 2>&1

#Tag Images
docker tag top-api `aws sts get-caller-identity --output text --query 'Account'`.dkr.ecr.us-east-1.amazonaws.com/top-api:stable
docker tag top-web `aws sts get-caller-identity --output text --query 'Account'`.dkr.ecr.us-east-1.amazonaws.com/top-web:stable
docker tag top-pgbackup `aws sts get-caller-identity --output text --query 'Account'`.dkr.ecr.us-east-1.amazonaws.com/top-pgbackup:stable
docker tag top-jenkins `aws sts get-caller-identity --output text --query 'Account'`.dkr.ecr.us-east-1.amazonaws.com/top-jenkins:stable

#Push Images
docker push `aws sts get-caller-identity --output text --query 'Account'`.dkr.ecr.us-east-1.amazonaws.com/top-api
docker push `aws sts get-caller-identity --output text --query 'Account'`.dkr.ecr.us-east-1.amazonaws.com/top-web
docker push `aws sts get-caller-identity --output text --query 'Account'`.dkr.ecr.us-east-1.amazonaws.com/top-pgbackup
docker push `aws sts get-caller-identity --output text --query 'Account'`.dkr.ecr.us-east-1.amazonaws.com/top-jenkins

