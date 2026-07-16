import * as fs from 'fs';
import * as path from 'path';
import xlsx from 'xlsx';
import stringSimilarity from 'string-similarity';

const PHOTOS_DIR = 'D:\\Seeddata\\photos\\Photos';
const EXCEL_PATH = 'D:\\Seeddata\\Data.xlsx';

function main() {
  const photoFolders = fs.readdirSync(PHOTOS_DIR).filter(f => fs.statSync(path.join(PHOTOS_DIR, f)).isDirectory());

  const workbook = xlsx.readFile(EXCEL_PATH);
  const sheetName = workbook.SheetNames[0];
  const rows = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName]);

  const missingPlaces = [];
  const foundPlaces = [];

  for (const row of rows as any[]) {
    const name = row['name'] ? row['name'].toString().trim() : '';
    if (!name) continue;

    let match = stringSimilarity.findBestMatch(name, photoFolders);
    if (match.bestMatch.rating > 0.3) {
      foundPlaces.push({ name, matchedFolder: match.bestMatch.target, score: match.bestMatch.rating });
      if (match.bestMatch.rating < 0.9) {
         console.log(`[WARNING] "${name}" matched with "${match.bestMatch.target}" (score: ${match.bestMatch.rating})`);
      }
    } else {
      missingPlaces.push(name);
    }
  }

  console.log(`\n=== KẾT QUẢ KIỂM TRA ===`);
  console.log(`Tổng số quán trong Excel: ${rows.length}`);
  console.log(`Số quán có thư mục ảnh: ${foundPlaces.length}`);
  console.log(`Số quán THIẾU thư mục ảnh: ${missingPlaces.length}`);

  if (missingPlaces.length > 0) {
    console.log(`\n=== DANH SÁCH CÁC QUÁN THIẾU ẢNH ===`);
    missingPlaces.forEach(p => console.log(`- ${p}`));
  }
}

main();
