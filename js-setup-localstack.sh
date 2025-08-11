#!/bin/bash
# Script robusto para configurar uma pipeline de processamento de imagens (Node.js) no LocalStack

# 'set -x' imprime cada comando antes de executá-lo (ótimo para depuração)
# 'set -e' garante que o script pare se algum comando falhar
set -ex

# --- 1. Definição de Variáveis ---
BUCKET_ORIGINAIS="bucket-originais"
BUCKET_REDIMENSIONADAS="bucket-redimensionadas"
LAMBDA_NOME="processador-de-imagens-js" # Nome da Lambda atualizado para JS
LAMBDA_ROLE_NOME="LambdaS3TriggerRole"
LAMBDA_POLICY_NOME="LambdaS3SpecificAccessPolicy"
LAMBDA_ZIP_PACOTE="lambda-deployment.zip"
RESIZE_WIDTH=800

# --- 2. Limpeza de Recursos Anteriores ---
echo "🧹 Limpando recursos de execuções anteriores..."
set +e # Desativa o 'exit on error' temporariamente para a limpeza
awslocal s3 rb s3://${BUCKET_ORIGINAIS} --force
awslocal s3 rb s3://${BUCKET_REDIMENSIONADAS} --force
awslocal lambda delete-function --function-name ${LAMBDA_NOME}
ATTACHED_POLICIES=$(awslocal iam list-attached-role-policies --role-name ${LAMBDA_ROLE_NOME} --query 'AttachedPolicies[*].PolicyArn' --output text 2>/dev/null)
if [ ! -z "$ATTACHED_POLICIES" ]; then
    for POLICY_ARN in $ATTACHED_POLICIES; do
        awslocal iam detach-role-policy --role-name ${LAMBDA_ROLE_NOME} --policy-arn ${POLICY_ARN}
    done
fi
awslocal iam delete-role --role-name ${LAMBDA_ROLE_NOME}
POLICY_ARN_TO_DELETE=$(awslocal iam list-policies --query "Policies[?PolicyName=='${LAMBDA_POLICY_NOME}'].Arn" --output text 2>/dev/null)
if [ ! -z "$POLICY_ARN_TO_DELETE" ]; then
    awslocal iam delete-policy --policy-arn ${POLICY_ARN_TO_DELETE}
fi
rm -f ${LAMBDA_ZIP_PACOTE}
echo "Limpeza concluída."
set -e # Reativa o 'exit on error'
echo "------------------------------------------"


# --- 3. Criação dos Buckets S3 ---
echo "📦 Criando buckets S3..."
awslocal s3 mb s3://${BUCKET_ORIGINAIS}
awslocal s3 mb s3://${BUCKET_REDIMENSIONADAS}
echo "Buckets '${BUCKET_ORIGINAIS}' e '${BUCKET_REDIMENSIONADAS}' criados."
echo "------------------------------------------"


# --- 4. Criação da Role e Policy Específica no IAM ---
echo "🛡️  Criando Policy e Role no IAM..."
# (Esta seção permanece a mesma)
POLICY_ARN=$(awslocal iam create-policy \
  --policy-name ${LAMBDA_POLICY_NOME} \
  --policy-document file://lambda-policy.json \
  --query 'Policy.Arn' --output text)
LAMBDA_ROLE_ARN=$(awslocal iam create-role \
  --role-name ${LAMBDA_ROLE_NOME} \
  --assume-role-policy-document '{"Version": "2012-10-17","Statement": [{ "Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]}' \
  --query 'Role.Arn' --output text)
echo "Aguardando a Role '${LAMBDA_ROLE_NOME}' ser criada..."
awslocal iam wait role-exists --role-name ${LAMBDA_ROLE_NOME}
awslocal iam attach-role-policy --role-name ${LAMBDA_ROLE_NOME} --policy-arn ${POLICY_ARN}
awslocal iam attach-role-policy --role-name ${LAMBDA_ROLE_NOME} --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
echo "Role '${LAMBDA_ROLE_NOME}' criada e configurada."
echo "------------------------------------------"


# --- 5. Build e Deploy da Lambda (Refatorado para Node.js) ---
echo "⚙️  Preparando e empacotando a função Lambda (Node.js)..."
(
  # Entra na pasta do projeto JavaScript
  cd js-image-processor && \
  
  # Instala as dependências, incluindo a versão correta da 'sharp' para a Lambda
  echo "Instalando dependências para a plataforma Lambda (linux/x64)..." && \
  npm install && \
  # Opcional, mas recomendado se a 'sharp' não instalar a versão correta
  npm install --os=linux --cpu=x64 sharp && \

  # Compacta todos os arquivos do projeto (index.js, outros .js, node_modules)
  # O arquivo .zip é criado no diretório raiz (../)
  echo "Compactando o pacote de deploy..." && \
  zip -r ../${LAMBDA_ZIP_PACOTE} .
)
echo "✅ Pacote de deploy criado com sucesso."

LAMBDA_ARN=$(awslocal lambda create-function \
  --function-name ${LAMBDA_NOME} \
  --runtime nodejs18.x \
  --handler index.handler \
  --role ${LAMBDA_ROLE_ARN} \
  --zip-file fileb://${LAMBDA_ZIP_PACOTE} \
  --query 'FunctionArn' --output text)

echo "✅ Lambda '${LAMBDA_NOME}' criada com ARN: ${LAMBDA_ARN}"


# --- 6. Configurar Permissão e Gatilho S3 ---
echo "🔗 Configurando permissão e gatilho S3..."
awslocal lambda add-permission \
  --function-name ${LAMBDA_NOME} \
  --statement-id "S3InvokePermission" \
  --action "lambda:InvokeFunction" \
  --principal s3.amazonaws.com \
  --source-arn "arn:aws:s3:::${BUCKET_ORIGINAIS}"
echo "Aguardando 5 segundos para propagação da permissão..."
sleep 5
awslocal s3api put-bucket-notification-configuration \
  --bucket ${BUCKET_ORIGINAIS} \
  --notification-configuration '{
    "LambdaFunctionConfigurations": [{
      "Id": "s3-lambda-trigger",
      "LambdaFunctionArn": "'${LAMBDA_ARN}'",
      "Events": ["s3:ObjectCreated:*"]
    }]
  }'
echo "Gatilho do S3 configurado para invocar a Lambda."
echo "------------------------------------------"


# --- 7. Verificação Final ---
echo "🔎 Verificando a configuração final..."
echo "--- Notificação do Bucket S3: ---"
awslocal s3api get-bucket-notification-configuration --bucket ${BUCKET_ORIGINAIS}
echo "--- Política de Permissão da Lambda: ---"
awslocal lambda get-policy --function-name ${LAMBDA_NOME}
echo "------------------------------------------"

# Desativa o modo de depuração
set +x

# --- FIM ---
echo "🚀 Stack orientada a eventos criada com sucesso! 🚀"
echo "A configuração parece correta. Tente fazer o upload de um arquivo agora."