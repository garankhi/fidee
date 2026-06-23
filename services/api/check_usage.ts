const { getPool } = require('./src/db/client');

async function run() {
  const pool = await getPool();
  
  const res = await pool.query(
    `SELECT * FROM ai_usage_daily WHERE user_id IN ('494a75ec-9051-7076-4491-5b937105db11', '89ca655c-f041-70c0-733d-8d6ff49479d4')`
  );
  
  console.log('AI Usage Daily:', res.rows);
  
  process.exit(0);
}

run().catch(console.error);
