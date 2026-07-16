import { Client } from 'pg';

const pgClient = new Client({
  host: 'localhost',
  port: 5433,
  database: 'fidee',
  user: 'postgres',
  password: 'N9ir4EXjWoJkTDmAcHqLA=M,I4KiYv',
});

async function main() {
  await pgClient.connect();
  console.log('Connected to database!');

  // Get all seeded places
  const { rows } = await pgClient.query(`
    SELECT id, name, metadata FROM places WHERE created_by = 'system-seeder'
  `);

  console.log(`Found ${rows.length} places to fix.`);

  let successCount = 0;

  for (const row of rows) {
    const meta = row.metadata || {};

    // Parse opening hours "08:00 - 22:15" -> open_time, close_time
    let openTime = null;
    let closeTime = null;
    const hours = meta.opening_hours || '';
    const hourMatch = hours.match(/(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})/);
    if (hourMatch) {
      openTime = hourMatch[1];
      closeTime = hourMatch[2];
    }

    // cover_media_id = first photo uploaded
    const coverMediaId = (meta.media_ids && meta.media_ids.length > 0) ? meta.media_ids[0] : null;

    // Clean metadata: remove fields that now live in columns
    const cleanMeta = { ...meta };
    delete cleanMeta.description;
    delete cleanMeta.phone_number;
    delete cleanMeta.price_min;
    delete cleanMeta.price_max;
    delete cleanMeta.opening_hours;

    try {
      await pgClient.query(`
        UPDATE places SET
          description = $1,
          phone_number = $2,
          price_min = $3,
          price_max = $4,
          open_time = $5,
          close_time = $6,
          cover_media_id = $7,
          metadata = $8
        WHERE id = $9
      `, [
        meta.description || null,
        meta.phone_number || null,
        meta.price_min || null,
        meta.price_max || null,
        openTime,
        closeTime,
        coverMediaId,
        JSON.stringify(cleanMeta),
        row.id
      ]);

      console.log(`  ✓ Fixed: ${row.name} (cover: ${coverMediaId || 'none'})`);
      successCount++;
    } catch (err) {
      console.error(`  ✗ Failed: ${row.name}:`, err);
    }
  }

  console.log(`\nDone! Fixed ${successCount}/${rows.length} places.`);
  await pgClient.end();
}

main().catch(console.error);
