const fs = require('fs');
const filePath = 'd:/mapvibe/services/api/src/db/migrations/index.ts';
let content = fs.readFileSync(filePath, 'utf8');

// Find the 011_reviews migration boundaries
const migStart = content.indexOf("'011_reviews': `");
const migSqlStart = migStart + "'011_reviews': `".length;

// Find the closing backtick for this migration
let depth = 0;
let migEnd = -1;
for (let i = migSqlStart; i < content.length; i++) {
  if (content[i] === '`') {
    migEnd = i;
    break;
  }
}

if (migEnd === -1) {
  console.log('ERROR: Could not find end of migration');
  process.exit(1);
}

// Extract and fix the migration SQL
let migSql = content.substring(migSqlStart, migEnd);
console.log('Before fix - contains \\\\$ count:', (migSql.match(/\\\\/g) || []).length, 'backslash pairs');

// Replace \\$ with \$ (remove extra backslash before $)
// In the source, we have char codes [92,92,36] and need [92,36]
let fixed = '';
for (let i = 0; i < migSql.length; i++) {
  if (migSql.charCodeAt(i) === 92 && migSql.charCodeAt(i+1) === 92 && migSql.charCodeAt(i+2) === 36) {
    // \\$ -> \$
    fixed += String.fromCharCode(92, 36);
    i += 2; // skip the \\$
  } else if (migSql.charCodeAt(i) === 92 && migSql.charCodeAt(i+1) === 114) {
    // \r literal -> actual CR
    fixed += '\r';
    i += 1;
  } else {
    fixed += migSql[i];
  }
}

// Rebuild the file
const newContent = content.substring(0, migSqlStart) + fixed + content.substring(migEnd);
fs.writeFileSync(filePath, newContent);

// Verify
const verify = fs.readFileSync(filePath, 'utf8');
const vStart = verify.indexOf("'011_reviews': `") + "'011_reviews': `".length;
let vEnd = -1;
for (let i = vStart; i < verify.length; i++) {
  if (verify[i] === '`') { vEnd = i; break; }
}
const vSql = verify.substring(vStart, vEnd);
const trigIdx = vSql.indexOf('RETURNS TRIGGER AS');
if (trigIdx >= 0) {
  const chars = [...vSql.substring(trigIdx, trigIdx+30)].map(c => c.charCodeAt(0));
  console.log('After fix trigger chars:', chars);
  console.log('Should match: 92, 36, 92, 36 (like migration 001)');
}
console.log('Done!');
