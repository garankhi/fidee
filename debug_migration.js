// Test what the migration SQL actually evaluates to
const fs = require('fs');
const content = fs.readFileSync('d:/mapvibe/services/api/src/db/migrations/index.ts', 'utf8');

// Find the 011 migration and extract its SQL
const start = content.indexOf("'011_reviews': `") + "'011_reviews': `".length;
const end = content.indexOf("`", start);
const sql011 = content.substring(start, end);

// Find the trigger section
const triggerIdx = sql011.indexOf('RETURNS TRIGGER AS');
if (triggerIdx >= 0) {
  const triggerSnippet = sql011.substring(triggerIdx, triggerIdx + 30);
  console.log('Trigger start:', JSON.stringify(triggerSnippet));
  console.log('Chars:', [...triggerSnippet].map(c => c.charCodeAt(0)));
}

// Find LANGUAGE plpgsql
const langIdx = sql011.indexOf('LANGUAGE plpgsql');
if (langIdx >= 0) {
  const langSnippet = sql011.substring(langIdx - 5, langIdx + 20);
  console.log('Trigger end:', JSON.stringify(langSnippet));
  console.log('Chars:', [...langSnippet].map(c => c.charCodeAt(0)));
}

// Also check migration 001
const start001 = content.indexOf("'001_initial': `") + "'001_initial': `".length;
const end001 = content.indexOf("`", start001);
const sql001 = content.substring(start001, end001);
const triggerIdx001 = sql001.indexOf('RETURNS TRIGGER AS');
if (triggerIdx001 >= 0) {
  const triggerSnippet001 = sql001.substring(triggerIdx001, triggerIdx001 + 30);
  console.log('\n001 Trigger start:', JSON.stringify(triggerSnippet001));
  console.log('Chars:', [...triggerSnippet001].map(c => c.charCodeAt(0)));
}
