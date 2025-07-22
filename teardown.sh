#!/bin/bash
set -e

echo "Destruindo a stack no LocalStack..."

# Apaga os buckets (a flag --force é necessária se não estiverem vazios)
awslocal s3 rb s3://bucket-originais --force
awslocal s3 rb s3://bucket-redimensionadas --force

# Apaga a função Lambda
awslocal lambda delete-function --function-name processador-de-imagens-ts

# Desatacha a policy e apaga a role
awslocal iam detach-role-policy --role-name LambdaS3TriggerRole --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
awslocal iam detach-role-policy --role-name LambdaS3TriggerRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
awslocal iam delete-role --role-name LambdaS3TriggerRole

echo "Stack destruída com sucesso."