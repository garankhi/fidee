import { Pool } from 'pg';

const p = new Pool({host: 'localhost', port: 5433, database: 'fidee', user: 'postgres', password: 'N9ir4EXjWoJkTDmAcHqLA=M,I4KiYv'});
async function run() {
  const r = await p.query("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'");
  console.log(r.rows.map(x => x.table_name));
  p.end();
}
run().catch(console.error);
