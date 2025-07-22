#!/bin/bash

# Para o script se houver algum erro
set -e

LAMBDA_NOME="processador-de-imagens-ts"

echo "Detectamos mudança no código. Fazendo build e atualizando a função Lambda..."

# 1. Navega até a pasta da lambda, faz o build e compacta o novo código
(
  cd lambda-image-processor && \
  npm run build && \
  zip -r ../lambda-deployment.zip dist/ node_modules/
)

# 2. Usa o comando "update-function-code" para enviar o novo .zip
echo "Enviando código atualizado para a Lambda '${LAMBDA_NOME}'..."
awslocal lambda update-function-code \
  --function-name ${LAMBDA_NOME} \
  --zip-file fileb://lambda-deployment.zip

echo "Código da Lambda atualizado com sucesso!"