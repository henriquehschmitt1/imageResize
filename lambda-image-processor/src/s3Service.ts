import { S3Client, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";

const s3Client = new S3Client({ endpoint: process.env.AWS_ENDPOINT_URL });

export const downloadImage = async (bucket: string, key: string): Promise<{ buffer: Buffer, contentType?: string }> => {
  console.log(`Baixando s3://${bucket}/${key}`);
  const command = new GetObjectCommand({ Bucket: bucket, Key: key });
  const s3Object = await s3Client.send(command);

  if (!s3Object.Body) {
    throw new Error("Corpo do objeto S3 não encontrado.");
  }
  
  const buffer = Buffer.from(await s3Object.Body.transformToByteArray());
  return { buffer, contentType: s3Object.ContentType };
};

export const uploadImage = async (bucket: string, key: string, body: Buffer, contentType?: string): Promise<void> => {
  console.log(`Enviando para s3://${bucket}/${key}`);
  const command = new PutObjectCommand({
    Bucket: bucket,
    Key: key,
    Body: body,
    ContentType: contentType
  });
  await s3Client.send(command);
};