import fs from 'fs';
import path from 'path';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';
import { Client } from 'pg';
import crypto from 'crypto';
import xlsx from 'xlsx';
import stringSimilarity from 'string-similarity';
import mime from 'mime-types';

// ── Config ───────────────────────────────────────────────────────────────────
const S3_BUCKET = 'fidee-dev-media-926883321458-ap-southeast-1';
const DYNAMO_TABLE = 'fidee-dev-places';
const REGION = 'ap-southeast-1';

const DB_HOST = 'localhost';
const DB_PORT = 5433;
const DB_NAME = 'fidee';
const DB_USER = 'postgres';
const DB_PASS = 'N9ir4EXjWoJkTDmAcHqLA=M,I4KiYv';

const PHOTOS_DIR = 'D:\\Seeddata\\photos\\Photos';
const EXCEL_PATH = 'D:\\Seeddata\\Data.xlsx';

const SEEDER_USER_ID = 'system-seeder';

// ── Clients ──────────────────────────────────────────────────────────────────
const s3Client = new S3Client({ region: REGION });
const dynamoClient = DynamoDBDocumentClient.from(new DynamoDBClient({ region: REGION }));

// ── Helpers ──────────────────────────────────────────────────────────────────
const CONTENT_TYPE_EXT: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

function getMimeType(filePath: string): string {
  const mimeType = mime.lookup(filePath);
  if (!mimeType) return 'image/png';
  return mimeType;
}

function getExtension(mimeType: string): string {
  return CONTENT_TYPE_EXT[mimeType] || 'png';
}

/**
 * Upload file to S3 with the correct key format: uploads/<mediaId>.<ext>
 * And create a MediaRecord in DynamoDB so GET /media/<mediaId> works.
 */
async function uploadAndRegisterMedia(
  filePath: string,
  mediaId: string,
  lat: number,
  lng: number,
): Promise<void> {
  const contentType = getMimeType(filePath);
  const ext = getExtension(contentType);
  const s3Key = `uploads/${mediaId}.${ext}`;
  const fileContent = fs.readFileSync(filePath);
  const contentLength = fileContent.length;
  const now = new Date().toISOString();

  // 1. Upload to S3 with proper key
  await s3Client.send(new PutObjectCommand({
    Bucket: S3_BUCKET,
    Key: s3Key,
    Body: fileContent,
    ContentType: contentType,
    Metadata: {
      'media-id': mediaId,
      'owner-user-id': SEEDER_USER_ID,
      'source': 'EXIF_GALLERY',
      'gps-latitude': lat.toString(),
      'gps-longitude': lng.toString(),
      'gps-captured-at': now,
    },
  }));

  // 2. Create MediaRecord in DynamoDB (same format as handle-media-uploaded.ts)
  const item = {
    PK: `MEDIA#${mediaId}`,
    SK: 'METADATA',
    entityType: 'Media',
    mediaId,
    ownerUserId: SEEDER_USER_ID,
    status: 'PENDING_MODERATION',
    s3Bucket: S3_BUCKET,
    s3Key,
    contentType,
    contentLength,
    source: 'EXIF_GALLERY',
    mediaType: 'IMAGE',
    gpsProof: {
      latitude: lat,
      longitude: lng,
      capturedAt: now,
    },
    createdAt: now,
    updatedAt: now,
    GSI1PK: `USER#${SEEDER_USER_ID}`,
    GSI1SK: `MEDIA#${now}#${mediaId}`,
  };

  await dynamoClient.send(new PutCommand({
    TableName: DYNAMO_TABLE,
    Item: item,
  }));
}

// ── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  const pgClient = new Client({
    host: DB_HOST,
    port: DB_PORT,
    database: DB_NAME,
    user: DB_USER,
    password: DB_PASS,
  });

  try {
    await pgClient.connect();
    console.log('Connected to PostgreSQL!');

    const photoFolders = fs.readdirSync(PHOTOS_DIR)
      .filter(f => fs.statSync(path.join(PHOTOS_DIR, f)).isDirectory());

    const workbook = xlsx.readFile(EXCEL_PATH);
    const sheetName = workbook.SheetNames[0];
    const rows = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName]);

    let totalUploaded = 0;
    let totalPlacesUpdated = 0;

    for (const row of rows as any[]) {
      const name = row['name'] ? row['name'].toString().trim() : '';
      if (!name) continue;

      // Parse lat/lng from Excel
      const geoStr = row['geo.lat/geo.lng'] || '';
      let lat = 10.7738, lng = 106.7035; // default HCM
      if (geoStr) {
        const parts = geoStr.toString().split('/').map((s: string) => parseFloat(s.trim()));
        if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
          lat = parts[0];
          lng = parts[1];
        }
      }

      // Match folder
      const match = stringSimilarity.findBestMatch(name, photoFolders);
      let matchedFolder = match.bestMatch.rating > 0.3 ? match.bestMatch.target : null;

      // Fix known mismatches
      if (name === 'HOME Saigon' && matchedFolder === 'Quince Saigon') matchedFolder = null;
      if (name === 'Bếp Mẹ Ỉn - Lê Thánh Tôn' && matchedFolder === 'Bếp Mẹ Ỉn') matchedFolder = 'Bếp Mẹ Ỉn';

      if (!matchedFolder) {
        console.log(`Skipping: ${name} (no photo folder)`);
        continue;
      }

      console.log(`\nProcessing: ${name}`);
      console.log(`  -> Folder: ${matchedFolder}`);

      const folderPath = path.join(PHOTOS_DIR, matchedFolder);
      let coverMediaId: string | null = null;
      const mediaIds: string[] = [];
      const menuIds: string[] = [];

      // ── Overview photos ────────────────────────────────────────────────────
      const overviewPath = path.join(folderPath, 'overview');
      if (fs.existsSync(overviewPath)) {
        const files = fs.readdirSync(overviewPath)
          .filter(f => f.match(/\.(jpg|jpeg|png|webp)$/i));
        for (const file of files) {
          const filePath = path.join(overviewPath, file);
          const mediaId = `place_photo_${crypto.randomBytes(8).toString('hex')}`;
          console.log(`     S3+DynamoDB: overview/${file} -> ${mediaId}`);
          await uploadAndRegisterMedia(filePath, mediaId, lat, lng);
          mediaIds.push(mediaId);
          if (!coverMediaId) coverMediaId = mediaId;
          totalUploaded++;
        }
      }

      // ── Menu photos ────────────────────────────────────────────────────────
      const menuPath = path.join(folderPath, 'menu');
      if (fs.existsSync(menuPath)) {
        const files = fs.readdirSync(menuPath)
          .filter(f => f.match(/\.(jpg|jpeg|png|webp)$/i));
        for (const file of files) {
          const filePath = path.join(menuPath, file);
          const mediaId = `place_menu_${crypto.randomBytes(8).toString('hex')}`;
          console.log(`     S3+DynamoDB: menu/${file} -> ${mediaId}`);
          await uploadAndRegisterMedia(filePath, mediaId, lat, lng);
          menuIds.push(mediaId);
          totalUploaded++;
        }
      }

      if (mediaIds.length === 0 && menuIds.length === 0) {
        console.log(`     (no photos found)`);
        continue;
      }

      // ── Update PostgreSQL ──────────────────────────────────────────────────
      const query = `
        UPDATE places
        SET
          cover_media_id = COALESCE($1, cover_media_id),
          metadata = jsonb_set(
            jsonb_set(
              COALESCE(metadata, '{}'::jsonb),
              '{media_ids}', $2::jsonb
            ),
            '{menu_ids}', $3::jsonb
          )
        WHERE name = $4
        RETURNING id;
      `;
      const res = await pgClient.query(query, [
        coverMediaId,
        JSON.stringify(mediaIds),
        JSON.stringify(menuIds),
        name,
      ]);

      if (res.rowCount === 0) {
        console.log(`     WARNING: "${name}" not found in DB`);
      } else {
        console.log(`     DB updated: cover=${coverMediaId}, ${mediaIds.length} overview, ${menuIds.length} menu`);
        totalPlacesUpdated++;
      }
    }

    console.log(`\n=== DONE ===`);
    console.log(`Total photos uploaded (S3 + DynamoDB): ${totalUploaded}`);
    console.log(`Total places updated in PostgreSQL: ${totalPlacesUpdated}`);

  } catch (err) {
    console.error('FATAL ERROR:', err);
  } finally {
    await pgClient.end();
  }
}

main();
