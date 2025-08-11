const { downloadImage, uploadImage, imageExists } = require("./s3Service");
const { resizeImage } = require("./imageResizer");

const SOURCE_BUCKET = process.env.SOURCE_BUCKET;
const DESTINATION_BUCKET = process.env.DESTINATION_BUCKET;

const SIZE_MAP = {
    xxs: 25,
    xs: 100,
    sm: 250,
    md: 500,
    lg: 750,
    xl: 1000,
    xxl: 1500
};

const pathPattern = new RegExp(`^/(.+)/(${Object.keys(SIZE_MAP).join('|')})(?:\\.(webp|jpeg|jpg|png))?$`, "i");

exports.handler = async (event) => {
    const requestedPath = event.rawPath;
    console.log(`Request received for path: ${requestedPath}`);

    const match = requestedPath.match(pathPattern);
    if (!match) {
        console.error("Path does not match resize pattern:", requestedPath);
        return { statusCode: 400, body: "Bad Request: Invalid URL format." };
    }

    try {
        const originalKey = match[1];
        const imageSizeClass = match[2].toLowerCase();
        const imageFormat = match[3] ? match[3].toLowerCase() : undefined

        const resizedKey = requestedPath.substring(1);
        const imageSizePx = SIZE_MAP[imageSizeClass];
        
        if (!imageSizePx) {
             return { statusCode: 400, body: "Bad Request: Invalid image size." };
        }

        console.log("Resized image not found. Generating on-demand.");

        // 1. Download the ORIGINAL image from the source bucket
        const { buffer: originalImageBuffer } = await downloadImage(SOURCE_BUCKET, originalKey);

        // 2. Resize the image
        const resizedImageBuffer = await resizeImage(originalImageBuffer,imageSizePx, imageSizePx,imageFormat);

        // 3. Upload the new version to the DESTINATION bucket
        // const newContentType = `image/${imageFormat === 'jpg' ? 'jpeg' : imageFormat}`;
        const newContentType = `image/${imageFormat ? imageFormat : 'webp'}`;
        await uploadImage(DESTINATION_BUCKET, resizedKey, resizedImageBuffer, newContentType);

        // 4. Return the newly created image directly in the HTTP response
        return {
            statusCode: 200,
            headers: { 
                "Content-Type": newContentType,
                "Cache-Control": "public, max-age=31536000" //Cache set to 1 year
            },
            body: resizedImageBuffer.toString('base64'),
            isBase64Encoded: true,
        };

    } catch (error) {
        console.error(`Error processing ${requestedPath}:`, error);
        return {
            statusCode: 404,
            body: JSON.stringify({ message: "The requested image could not be found or processed." }),
        };
    }
};