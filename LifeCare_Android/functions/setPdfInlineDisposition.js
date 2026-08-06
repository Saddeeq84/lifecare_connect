const functions = require('firebase-functions');
const { Storage } = require('@google-cloud/storage');
const storage = new Storage();

exports.setPdfInlineDisposition = functions.storage.object().onFinalize(async (object) => {
  if (object.contentType === 'application/pdf') {
    const bucket = storage.bucket(object.bucket);
    const file = bucket.file(object.name);
    await file.setMetadata({
      contentDisposition: 'inline'
    });
    console.log(`Set Content-Disposition:inline for ${object.name}`);
  }
});
