import 'dotenv/config';

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

export const config = {
  port: Number(process.env.PORT ?? 3000),
  database: {
    host: required('DATABASE_HOST'),
    port: Number(process.env.DATABASE_PORT ?? 5432),
    name: required('DATABASE_NAME'),
    user: required('DATABASE_USER'),
    password: required('DATABASE_PASSWORD'),
    ssl: process.env.DATABASE_SSL !== 'false'
  },
  storage: {
    accountName: required('AZURE_STORAGE_ACCOUNT_NAME'),
    accountKey: required('AZURE_STORAGE_ACCOUNT_KEY'),
    containerName: required('AZURE_STORAGE_CONTAINER_NAME')
  }
};
