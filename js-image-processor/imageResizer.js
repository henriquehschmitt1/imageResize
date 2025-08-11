const sharp = require('sharp');

exports.resizeImage = async (imageBuffer, width, height, format = 'webp') => {
  const quality = 90;

  console.log(`Resizing to fit inside ${width}x${height}px with quality ${quality}...`);
  return sharp(imageBuffer)
    .rotate()
    .resize({
      width: width,
      height: height,
      fit: 'inside',
      withoutEnlargement: true
    })
    .toFormat(format, { quality: quality })
    .toBuffer();

}