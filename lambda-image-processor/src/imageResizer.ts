import sharp from 'sharp';

export const resizeImage = async (imageBuffer: Buffer, width: number): Promise<Buffer> => {
  console.log(`Redimensionando para ${width}px de largura...`);
  return sharp(imageBuffer)
    .resize({ width })
    .toBuffer();
};