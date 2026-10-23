import { BlobServiceClient, StorageSharedKeyCredential } from '@azure/storage-blob';
import { randomUUID } from 'node:crypto';
import { config } from './config.js';

const credential = new StorageSharedKeyCredential(config.storage.accountName, config.storage.accountKey);
const service = new BlobServiceClient(`https://${config.storage.accountName}.blob.core.windows.net`, credential);
const container = service.getContainerClient(config.storage.containerName);

export async function ensureContainer() {
  await container.createIfNotExists();
}

export async function uploadEvidence(file: Express.Multer.File) {
  const safeName = file.originalname.replace(/[^a-zA-Z0-9._-]/g, '_');
  const blobName = `${randomUUID()}-${safeName}`;
  const blob = container.getBlockBlobClient(blobName);
  await blob.uploadData(file.buffer, { blobHTTPHeaders: { blobContentType: file.mimetype } });
  return { blobName, url: blob.url };
}

export async function downloadEvidence(blobName: string) {
  return container.getBlobClient(blobName).download();
}
