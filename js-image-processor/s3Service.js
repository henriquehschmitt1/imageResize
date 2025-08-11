const { S3Client, GetObjectCommand, PutObjectCommand, HeadObjectCommand } = require("@aws-sdk/client-s3");

const s3Client = new S3Client({});

exports.imageExists = async (bucket, key) => {
    try {
        const command = new HeadObjectCommand({ Bucket: bucket, Key: key });
        await s3Client.send(command);
        return true;
    } catch (error) {
        if (error.name === 'NotFound') {
            return false;
        }
        throw error;
    }
};

exports.downloadImage = async (bucket, key) => {
    console.log(`Downloading s3://${bucket}/${key}`);
    const command = new GetObjectCommand({ Bucket: bucket, Key: key });
    const s3Object = await s3Client.send(command);
    if (!s3Object.Body) throw new Error("S3 object body not found.");
    const buffer = Buffer.from(await s3Object.Body.transformToByteArray());
    return { buffer, contentType: s3Object.ContentType };
};

exports.uploadImage = async (bucket, key, body, contentType, cacheControl = 'public, max-age=31536000') => {
    console.log(`Uploading to s3://${bucket}/${key} with Cache-Control: ${cacheControl}`);
    const command = new PutObjectCommand({
        Bucket: bucket,
        Key: key,
        Body: body,
        ContentType: contentType,
        CacheControl: cacheControl
    });
    await s3Client.send(command);
};