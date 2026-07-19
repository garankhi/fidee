import { Pool } from 'pg';

const p = new Pool({host: 'localhost', port: 5433, database: 'fidee', user: 'postgres', password: 'N9ir4EXjWoJkTDmAcHqLA=M,I4KiYv'});
async function run() {
  const r = await p.query("SELECT id, name, metadata FROM places LIMIT 10");
  for (const row of r.rows) {
    console.log(`Place: ${row.name}, metadata:`, row.metadata);
  }
  p.end();
}
run().catch(console.error);
