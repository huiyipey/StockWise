const MAX_IMAGE_BYTES = 1024 * 1024;
const MAX_TOTAL_BYTES = 4 * MAX_IMAGE_BYTES;

function imageType(bytes) {
  if (bytes.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]))) return ['image/png', 'png'];
  if (bytes[0] === 255 && bytes[1] === 216 && bytes[2] === 255) return ['image/jpeg', 'jpg'];
  if (['GIF87a', 'GIF89a'].includes(bytes.subarray(0, 6).toString())) return ['image/gif', 'gif'];
  return null;
}

async function orderImages(bucket, storeId, items) {
  const imagesByPath = new Map(), attachments = [];
  if (!bucket) return {imagesByPath, attachments};
  let totalBytes = 0, attempted = 0;
  for (const path of new Set(items.map(item => item.imagePath).filter(path => typeof path === 'string'))) {
    const parts = path.split('/');
    if (parts.length !== 5 || parts[0] !== 'stores' || parts[1] !== storeId || parts[2] !== 'product-images'
      || parts.some(part => !part || part === '.' || part === '..')) continue;
    if (attempted++ >= 8 || totalBytes >= MAX_TOTAL_BYTES) break;
    let stream, timer;
    try {
      // Read a bounded range, never an arbitrary URL, receipt or another store's file.
      stream = bucket.file(path).createReadStream({start: 0, end: MAX_IMAGE_BYTES, validation: false});
      timer = setTimeout(() => stream.destroy(new Error('Product photo timed out.')), 5000);
      const chunks = [];
      let size = 0;
      for await (const chunk of stream) {
        size += chunk.length;
        if (size > MAX_IMAGE_BYTES || totalBytes + size > MAX_TOTAL_BYTES) throw Error('Product photo is too large.');
        chunks.push(chunk);
      }
      const content = Buffer.concat(chunks), type = imageType(content);
      if (!type) continue;
      const cid = `stockwise-product-${attachments.length}@order`;
      attachments.push({filename: `product-${attachments.length + 1}.${type[1]}`, content, cid, contentType: type[0], contentDisposition: 'inline'});
      imagesByPath.set(path, cid);
      totalBytes += size;
    } catch (_) {
      // A missing, unsupported or oversized photo must not prevent the confirmation.
    } finally {
      clearTimeout(timer);
      stream?.destroy();
    }
  }
  return {imagesByPath, attachments};
}

module.exports = {orderImages};
