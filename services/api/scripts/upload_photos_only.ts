import fs from 'fs';
import path from 'path';
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { Client } from 'pg';
import crypto from 'crypto';
import xlsx from 'xlsx';
import stringSimilarity from 'string-similarity';
import mime from 'mime-types';

const S3_BUCKET = 'fidee-dev-media-926883321458-ap-southeast-1';
const DB_HOST = 'localhost';
const DB_PORT = 5433; // SSM port forward
const DB_NAME = 'fidee';
const DB_USER = 'fidee_admin';
const DB_PASS = 'FideeDBPassword2026';

const PHOTOS_DIR = 'D:\\Seeddata\\photos\\Photos';
const EXCEL_PATH = 'D:\\Seeddata\\Data.xlsx';

const s3Client = new S3Client({ region: "ap-southeast-1" });

function getMimeType(filePath: string): string {
  return mime.lookup(filePath) || 'application/octet-stream';
}

async function uploadToS3(filePath: string, mediaId: string, mimeType: string): Promise<string> {
  const fileContent = fs.readFileSync(filePath);
  const command = new PutObjectCommand({
    Bucket: S3_BUCKET,
    Key: mediaId,
    Body: fileContent,
    ContentType: mimeType,
  });
  await s3Client.send(command);
  return mediaId;
}

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
    console.log('Connected to database!');

    const photoFolders = fs.readdirSync(PHOTOS_DIR).filter(f => fs.statSync(path.join(PHOTOS_DIR, f)).isDirectory());

    const workbook = xlsx.readFile(EXCEL_PATH);
    const sheetName = workbook.SheetNames[0];
    const rows = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName]);

    for (const row of rows as any[]) {
      const name = row['name'] ? row['name'].toString().trim() : '';
      if (!name) continue;

      let match = stringSimilarity.findBestMatch(name, photoFolders);
      let matchedFolder = match.bestMatch.rating > 0.3 ? match.bestMatch.target : null;
      
      // Fix known mismatched folders
      if (name === "HOME Saigon" && matchedFolder === "Quince Saigon") matchedFolder = null;
      if (name === "Bếp Mẹ Ỉn - Lê Thánh Tôn" && matchedFolder === "Bếp Mẹ Ỉn") matchedFolder = "Bếp Mẹ Ỉn";

      if (!matchedFolder) {
        console.log(`Skipping: ${name} (No photo folder)`);
        continue;
      }

      console.log(`Processing photos for: ${name}`);
      const folderPath = path.join(PHOTOS_DIR, matchedFolder);

      let coverMediaId: string | null = null;
      const media_ids: string[] = [];
      const menu_ids: string[] = [];

      const overviewPath = path.join(folderPath, 'overview');
      if (fs.existsSync(overviewPath)) {
        const files = fs.readdirSync(overviewPath).filter(f => f.match(/\.(jpg|jpeg|png|webp|gif)$/i));
        for (const file of files) {
          const filePath = path.join(overviewPath, file);
          const mediaId = `place_photo_${crypto.randomBytes(8).toString('hex')}`;
          console.log(`     Uploading overview/${file} -> ${mediaId}`);
          await uploadToS3(filePath, mediaId, getMimeType(filePath));
          media_ids.push(mediaId);
          if (!coverMediaId) coverMediaId = mediaId;
        }
      } else {
         console.log(`     WARNING: No overview folder for ${name}`);
      }

      const menuPath = path.join(folderPath, 'menu');
      if (fs.existsSync(menuPath)) {
        const files = fs.readdirSync(menuPath).filter(f => f.match(/\.(jpg|jpeg|png|webp|gif)$/i));
        for (const file of files) {
          const filePath = path.join(menuPath, file);
          const mediaId = `place_menu_${crypto.randomBytes(8).toString('hex')}`;
          console.log(`     Uploading menu/${file} -> ${mediaId}`);
          await uploadToS3(filePath, mediaId, getMimeType(filePath));
          menu_ids.push(mediaId);
        }
      } else {
         console.log(`     WARNING: No menu folder for ${name}`);
      }

      if (media_ids.length === 0 && menu_ids.length === 0) {
        console.log(`     No photos found to upload for ${name}.`);
        continue;
      }

      // Update Database
      const query = `
        UPDATE places 
        SET 
          cover_media_id = COALESCE($1, cover_media_id),
          metadata = jsonb_set(
            jsonb_set(metadata, '{media_ids}', $2::jsonb), 
            '{menu_ids}', $3::jsonb
          )
        WHERE name = $4
        RETURNING id;
      `;
      const res = await pgClient.query(query, [coverMediaId, JSON.stringify(media_ids), JSON.stringify(menu_ids), name]);
      
      if (res.rowCount === 0) {
        console.log(`     WARNING: Place "${name}" not found in DB to update.`);
      } else {
        console.log(`     Successfully updated photos for ${name}.`);
      }
    }

    console.log('Finished uploading photos!');

  } catch (err) {
    console.error(err);
  } finally {
    await pgClient.end();
  }
}

main();
