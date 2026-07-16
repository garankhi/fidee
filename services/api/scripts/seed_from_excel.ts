import * as fs from 'fs';
import * as path from 'path';
import xlsx from 'xlsx';
import { Client } from 'pg';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import stringSimilarity from 'string-similarity';
import crypto from 'crypto';

const S3_BUCKET = 'fidee-dev-media-926883321458-ap-southeast-1';
const DB_HOST = 'localhost';
const DB_PORT = 5433; // SSM port forward
const DB_NAME = 'fidee';
const DB_USER = 'postgres';
const DB_PASS = 'N9ir4EXjWoJkTDmAcHqLA=M,I4KiYv';

const s3Client = new S3Client({ region: 'ap-southeast-1' });
const pgClient = new Client({
  host: DB_HOST,
  port: DB_PORT,
  database: DB_NAME,
  user: DB_USER,
  password: DB_PASS,
});

const PHOTOS_DIR = 'D:\\Seeddata\\photos\\Photos';
const EXCEL_PATH = 'D:\\Seeddata\\Data.xlsx';

async function uploadToS3(filePath: string, mediaId: string, mimeType: string) {
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

function getMimeType(filePath: string) {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === '.png') return 'image/png';
  if (ext === '.gif') return 'image/gif';
  if (ext === '.webp') return 'image/webp';
  return 'image/jpeg';
}

async function main() {
  await pgClient.connect();
  console.log('Connected to database!');

  // Read available photo folders
  const photoFolders = fs.readdirSync(PHOTOS_DIR).filter(f => fs.statSync(path.join(PHOTOS_DIR, f)).isDirectory());

  // Read Excel
  const workbook = xlsx.readFile(EXCEL_PATH);
  const sheetName = workbook.SheetNames[0];
  const rows = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName]);
  
  console.log(`Found ${rows.length} rows in Excel.`);

  let successCount = 0;

  for (const row of rows as any[]) {
    const name = row['name'] ? row['name'].toString().trim() : '';
    if (!name) continue;

    console.log(`Processing: ${name}`);

    // Fuzzy match folder
    let match = stringSimilarity.findBestMatch(name, photoFolders);
    let matchedFolder = null;
    if (match.bestMatch.rating > 0.3) {
      matchedFolder = match.bestMatch.target;
      console.log(`  -> Matched folder: ${matchedFolder} (score: ${match.bestMatch.rating.toFixed(2)})`);
    } else {
      console.log(`  -> No matching folder found.`);
    }

    // Parse coordinates
    let lat = 0, lng = 0;
    const geo = row['geo.lat/geo.lng'] || '';
    if (geo) {
      const parts = geo.split('/').map((s: string) => parseFloat(s.trim()));
      if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1])) {
        lat = parts[0];
        lng = parts[1];
      }
    }

    // Parse category
    let category = 'other';
    const rawCategory = (row['category'] || '').toLowerCase();
    if (rawCategory.includes('cà phê') || rawCategory.includes('coffee')) category = 'cafe';
    else if (rawCategory.includes('khách sạn') || rawCategory.includes('hotel')) category = 'hotel';
    else if (rawCategory.includes('quán ăn') || rawCategory.includes('nhà hàng')) category = 'restaurant';
    else if (rawCategory.includes('mua sắm') || rawCategory.includes('shop')) category = 'shopping';

    // Parse price
    let priceMin = null, priceMax = null;
    const priceStr = row['priceRange'] || '';
    const priceMatch = priceStr.match(/(\d+)\s*-\s*(\d+)/);
    if (priceMatch) {
      priceMin = parseInt(priceMatch[1]);
      priceMax = parseInt(priceMatch[2]);
    }

    // Parse opening hours "08:00 - 22:15" -> open_time, close_time
    let openTime = null;
    let closeTime = null;
    const hours = row['openingHours'] || '';
    const hourMatch = hours.match(/(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})/);
    if (hourMatch) {
      openTime = hourMatch[1];
      closeTime = hourMatch[2];
    }

    // Metadata (only non-column fields)
    const metadata: any = {
      rating_avg: parseFloat(row['rating.avg']) || null,
      rating_count: parseInt(row['rating.count']) || null,
      features: row['features'] ? row['features'].split('\n').map((s: string) => s.trim().replace(/^-/, '').trim()) : [],
      vibe: row['vibe'] || '',
      category_description: row['category description'] || null,
      media_ids: [] as string[],
      menu_ids: [] as string[]
    };

    // Upload photos if folder exists
    // Photos are inside subfolders: overview/ and menu/
    let coverMediaId: string | null = null;

    if (matchedFolder) {
      const folderPath = path.join(PHOTOS_DIR, matchedFolder);

      // Upload overview photos (used for cover + gallery)
      const overviewPath = path.join(folderPath, 'overview');
      if (fs.existsSync(overviewPath)) {
        const files = fs.readdirSync(overviewPath).filter(f => f.match(/\.(jpg|jpeg|png|webp|gif)$/i));
        for (const file of files) {
          const filePath = path.join(overviewPath, file);
          const mediaId = `place_photo_${crypto.randomBytes(8).toString('hex')}`;
          console.log(`     Uploading overview/${file} -> ${mediaId}`);
          await uploadToS3(filePath, mediaId, getMimeType(filePath));
          metadata.media_ids.push(mediaId);
          if (!coverMediaId) coverMediaId = mediaId; // first overview photo = cover
        }
      }

      // Upload menu photos
      const menuPath = path.join(folderPath, 'menu');
      if (fs.existsSync(menuPath)) {
        const files = fs.readdirSync(menuPath).filter(f => f.match(/\.(jpg|jpeg|png|webp|gif)$/i));
        for (const file of files) {
          const filePath = path.join(menuPath, file);
          const mediaId = `place_menu_${crypto.randomBytes(8).toString('hex')}`;
          console.log(`     Uploading menu/${file} -> ${mediaId}`);
          await uploadToS3(filePath, mediaId, getMimeType(filePath));
          metadata.menu_ids.push(mediaId);
        }
      }
    }

    // Normalized name
    const normalizedName = name.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    const address = row['address'] || null;
    const description = row['description'] || null;
    const phoneNumber = row['phone'] || null;
    
    // Insert to DB
    const placeId = crypto.randomUUID();
    const insertQuery = `
      INSERT INTO places (id, name, normalized_name, category, address, location, created_by,
        description, phone_number, price_min, price_max, open_time, close_time, cover_media_id, metadata)
      VALUES ($1, $2, $3, $4, $5, ST_MakePoint($6, $7), $8, $9, $10, $11, $12, $13, $14, $15, $16)
      RETURNING id;
    `;
    
    try {
      await pgClient.query('BEGIN');
      
      // Ensure the test user exists to satisfy foreign key
      await pgClient.query(`INSERT INTO users (id, display_name, username, plan, email) VALUES ('system-seeder', 'System', 'system', 'FREE', 'system@fidee.com') ON CONFLICT DO NOTHING`);

      await pgClient.query(insertQuery, [
        placeId, 
        name,
        normalizedName,
        category,
        address,
        lng, // PostGIS MakePoint takes (longitude, latitude)
        lat,
        'system-seeder',
        description,
        phoneNumber,
        priceMin,
        priceMax,
        openTime,
        closeTime,
        coverMediaId,
        JSON.stringify(metadata)
      ]);
      
      // Insert into place_settings
      const settingsQuery = `
        INSERT INTO place_settings (place_id, visibility, status)
        VALUES ($1, 'PUBLIC', 'APPROVED');
      `;
      await pgClient.query(settingsQuery, [
        placeId
      ]);
      
      await pgClient.query('COMMIT');
      console.log(`  -> Inserted place ${placeId}`);
      successCount++;
    } catch (err) {
      await pgClient.query('ROLLBACK');
      console.error(`  -> Failed to insert ${name}:`, err);
    }
  }

  console.log(`Successfully seeded ${successCount} places!`);
  await pgClient.end();
}

main().catch(console.error);
