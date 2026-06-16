import { handler } from './src/handlers/search';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Nạp file .env từ thư mục gốc
dotenv.config({ path: path.join(__dirname, '../../.env') });

async function run() {
  const event = {
    body: JSON.stringify({ query: 'tìm quán cafe làm việc quận 1' }),
  } as any;

  console.log('⏳ Đang gọi API Search...');
  
  try {
    const result = await handler(event);
    console.log('✅ Status:', result.statusCode);
    console.log('✅ Body:\n', JSON.stringify(JSON.parse(result.body), null, 2));
  } catch (error) {
    console.error('❌ Lỗi:', error);
  }
}

run();
