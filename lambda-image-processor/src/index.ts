import { S3Event } from "aws-lambda";
import { downloadImage, uploadImage } from "./s3Service";
import { resizeImage } from "./imageResizer";

const DESTINATION_BUCKET = process.env.DESTINATION_BUCKET || 'bucket-redimensionadas';
const RESIZE_WIDTH = parseInt(process.env.RESIZE_WIDTH || '500', 10);

export const handler = async (event: S3Event): Promise<void> => {
  console.log("Evento S3 recebido:", JSON.stringify(event, null, 2));

  if (!DESTINATION_BUCKET) {
    console.error("Erro: Variável de ambiente DESTINATION_BUCKET não definida.");
    return;
  }

  for (const record of event.Records) {
    const sourceBucket = record.s3.bucket.name;
    const sourceKey = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
    const destinationKey = sourceKey;

    try {
      const { buffer: originalImageBuffer, contentType } = await downloadImage(sourceBucket, sourceKey);
      
      const resizedImageBuffer = await resizeImage(originalImageBuffer, RESIZE_WIDTH);

      await uploadImage(DESTINATION_BUCKET, destinationKey, resizedImageBuffer, contentType);

      console.log(`Sucesso! Imagem ${sourceKey} processada e salva.`);
    } catch (error) {
      console.error(`Erro ao processar o arquivo ${sourceKey}:`, error);
    }
  }
};