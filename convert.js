const fs = require('fs');
const sql = fs.readFileSync('d:/mapvibe/services/api/src/db/migrations/001_initial.sql', 'utf8');
const tsContent = `export const migrations: Record<string, string> = {
  '001_initial': \`${sql.replace(/`/g, '\\`').replace(/\$/g, '\\$')}\`
};`;
fs.writeFileSync('d:/mapvibe/services/api/src/db/migrations/index.ts', tsContent);
console.log('Done!');
