import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { createLlmProvider } from '../services/llm-provider';
import { EmbeddingService } from '../services/embedding-service';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

/**
 * POST /search
 *
 * AI-powered semantic search using Vector Search + RAG:
 * 1. Embed user's prompt into a 768-dim vector (Gemini text-embedding-004)
 * 2. Vector similarity search in PostgreSQL (pgvector cosine distance)
 * 3. RAG — feed results to Gemini LLM for natural language response
 *
 * Fallback: If no embeddings exist in DB, falls back to keyword search (ILIKE).
 */
export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
  const body = event.body ? JSON.parse(event.body) : {};
  const prompt = body.prompt as string | undefined;
  const limit = Math.min(Math.max(body.limit || 10, 1), 20);

  if (!prompt || prompt.trim().length === 0) {
    return {
      statusCode: 400,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Missing required field: prompt' }),
    };
  }

  try {
    let places: any[] = [];
    let searchMethod: 'vector' | 'keyword' = 'vector';

    // ── Step 1: Try Vector Search ───────────────────────────────────────
    try {
      const embeddingService = new EmbeddingService();
      const queryVector = await embeddingService.embedText(prompt);
      const vectorString = `[${queryVector.join(',')}]`;

      const vectorSql = `
        SELECT
          p.id, p.name, p.category, p.address, p.description,
          p.open_time, p.close_time, p.price_min, p.price_max,
          p.metadata,
          ST_X(p.location::geometry) AS lng,
          ST_Y(p.location::geometry) AS lat,
          1 - (p.embedding <=> $1::vector) AS similarity_score
        FROM places p
        JOIN place_settings ps ON ps.place_id = p.id
        WHERE ps.status = 'APPROVED'
          AND ps.visibility = 'PUBLIC'
          AND p.embedding IS NOT NULL
        ORDER BY p.embedding <=> $1::vector
        LIMIT $2;
      `;

      console.log('Executing Vector Search...');
      const dbResult = await query(vectorSql, [vectorString, limit]);
      places = dbResult.rows;

      // If vector search returned no results (all embeddings NULL),
      // fall back to keyword search
      if (places.length === 0) {
        console.log('Vector search returned 0 results, falling back to keyword...');
        searchMethod = 'keyword';
      }
    } catch (embeddingError) {
      console.error('Vector search failed, falling back to keyword:', embeddingError);
      searchMethod = 'keyword';
    }

    // ── Step 2: Keyword Fallback ────────────────────────────────────────
    if (searchMethod === 'keyword') {
      const llm = await createLlmProvider();

      // Extract keywords using LLM
      const extractSystemPrompt = `Bạn là một chuyên gia phân tích yêu cầu tìm kiếm địa điểm.
Hãy đọc yêu cầu của người dùng và trích xuất ra các bộ lọc tìm kiếm.
Trả về định dạng JSON thuần túy (không có markdown code blocks) với cấu trúc sau:
{
  "category": "Tên danh mục nếu có (cafe, restaurant, hotel, tourist_attraction, office, shopping, other). Nếu không rõ, để null",
  "keywords": ["danh", "sách", "các", "từ", "khóa", "quan", "trọng"],
  "limit": 10
}`;

      const filterResponse = await llm.chat(extractSystemPrompt, prompt, true);

      let filters: { category?: string | null; keywords?: string[]; limit?: number } = {};
      try {
        const cleanJson = filterResponse.content.replace(/```json/g, '').replace(/```/g, '').trim();
        filters = JSON.parse(cleanJson);
      } catch {
        filters = { keywords: prompt.split(' ') };
      }

      let sql = `
        SELECT p.id, p.name, p.category, p.address, p.description,
               p.open_time, p.close_time, p.price_min, p.price_max,
               p.metadata,
               ST_X(p.location::geometry) AS lng,
               ST_Y(p.location::geometry) AS lat
        FROM places p
        JOIN place_settings ps ON ps.place_id = p.id
        WHERE ps.status = 'APPROVED' AND ps.visibility = 'PUBLIC'`;
      const params: any[] = [];
      let paramIndex = 1;

      if (filters.category) {
        sql += ` AND p.category = $${paramIndex}`;
        params.push(filters.category);
        paramIndex++;
      }

      if (filters.keywords && filters.keywords.length > 0) {
        const keywordConditions = filters.keywords.map((kw: string) => {
          const normalizedKw = kw.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/đ/g, 'd').replace(/Đ/g, 'D');
          params.push(`%${normalizedKw}%`);
          const str = `p.normalized_name ILIKE $${paramIndex}`;
          paramIndex++;
          return str;
        });
        sql += ` AND (${keywordConditions.join(' OR ')})`;
      }

      sql += ` LIMIT $${paramIndex}`;
      params.push(filters.limit || limit);

      console.log('Executing Keyword Fallback:', sql);
      const dbResult = await query(sql, params);
      places = dbResult.rows;
    }

    // ── Step 3: RAG — Generate natural language answer ──────────────────
    const llm = await createLlmProvider();

    const placeSummary = places.map((p, i) => {
      const parts = [`${i + 1}. ${p.name} (${p.category})`];
      if (p.address) parts.push(`   Địa chỉ: ${p.address}`);
      if (p.description) parts.push(`   Mô tả: ${p.description}`);
      if (p.price_min && p.price_max) parts.push(`   Giá: ${p.price_min.toLocaleString()}đ - ${p.price_max.toLocaleString()}đ`);
      if (p.open_time && p.close_time) parts.push(`   Giờ mở cửa: ${p.open_time} - ${p.close_time}`);
      if (p.similarity_score !== undefined) parts.push(`   Độ phù hợp: ${(p.similarity_score * 100).toFixed(0)}%`);
      return parts.join('\n');
    }).join('\n\n');

    const ragSystemPrompt = `Bạn là Fidee, một trợ lý ảo tư vấn địa điểm thân thiện và nhiệt tình.
Người dùng đã hỏi: "${prompt}"

Dưới đây là danh sách các địa điểm phù hợp nhất từ cơ sở dữ liệu:
${placeSummary || '(Không tìm thấy địa điểm nào phù hợp)'}

Quy tắc trả lời:
- Trả lời tự nhiên, ngắn gọn (tối đa 3-4 câu)
- Chỉ dựa trên dữ liệu được cung cấp, KHÔNG bịa thêm thông tin
- Nếu không có kết quả, xin lỗi lịch sự và gợi ý user thử từ khóa khác
- Nếu có nhiều kết quả, ưu tiên giới thiệu 2-3 nơi nổi bật nhất`;

    const answerResponse = await llm.chat(ragSystemPrompt, 'Hãy trả lời người dùng.', false);

    return {
      statusCode: 200,
      headers: CORS_HEADERS,
      body: JSON.stringify({
        answer: answerResponse.content,
        search_method: searchMethod,
        results: places,
      }),
    };
  } catch (error) {
    console.error('Search error:', error);
    return {
      statusCode: 500,
      headers: CORS_HEADERS,
      body: JSON.stringify({ error: 'Internal server error during AI search' }),
    };
  }
};
