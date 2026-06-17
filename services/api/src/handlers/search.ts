import { APIGatewayProxyEvent, APIGatewayProxyResult } from 'aws-lambda';
import { query } from '../db/client';
import { extractAuth } from '../middleware/auth';
import { incrementAiUsage, AiUsageResult } from '../repositories/ai-usage';
import { getUserPlan, UserPlan } from '../repositories/user-profiles';
import { EmbeddingService } from '../services/embedding-service';
import { ChatMessage, createLlmProvider } from '../services/llm-provider';

const CORS_HEADERS = {
  'Content-Type': 'application/json',
  'Access-Control-Allow-Origin': '*',
};

type SearchMethod = 'vector' | 'keyword';

interface SearchPlacesInput {
  prompt: string;
  history?: ChatMessage[];
  limit: number;
}

interface SearchPlacesResult {
  answer: string;
  search_method: SearchMethod;
  results: unknown[];
}

interface SearchDeps {
  getPlan: (userId: string) => Promise<UserPlan>;
  incrementUsage: (input: { userId: string; plan: UserPlan }) => Promise<AiUsageResult>;
  searchPlaces: (input: SearchPlacesInput) => Promise<SearchPlacesResult>;
}

function jsonResponse(statusCode: number, body: Record<string, unknown>): APIGatewayProxyResult {
  return {
    statusCode,
    headers: CORS_HEADERS,
    body: JSON.stringify(body),
  };
}

function defaultDeps(): SearchDeps {
  const userProfilesTable = process.env.USER_PROFILES_TABLE;
  if (!userProfilesTable) {
    throw new Error('USER_PROFILES_TABLE is required');
  }

  return {
    getPlan: (userId) => getUserPlan(userId, userProfilesTable),
    incrementUsage: incrementAiUsage,
    searchPlaces: performSemanticSearch,
  };
}

async function performSemanticSearch(input: SearchPlacesInput): Promise<SearchPlacesResult> {
  const { prompt, history, limit } = input;
  let places: any[] = [];
  let searchMethod: SearchMethod = 'vector';

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

    if (places.length === 0) {
      console.log('Vector search returned 0 results, falling back to keyword...');
      searchMethod = 'keyword';
    }
  } catch (embeddingError) {
    console.error('Vector search failed, falling back to keyword:', embeddingError);
    searchMethod = 'keyword';
  }

  if (searchMethod === 'keyword') {
    const llm = await createLlmProvider();
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
        const normalizedKw = kw
          .toLowerCase()
          .normalize('NFD')
          .replace(/[\u0300-\u036f]/g, '')
          .replace(/đ/g, 'd')
          .replace(/Đ/g, 'D');
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

  const llm = await createLlmProvider();
  const placeSummary = places
    .map((place, index) => {
      const parts = [`${index + 1}. ${place.name} (${place.category})`];
      if (place.address) parts.push(`   Địa chỉ: ${place.address}`);
      if (place.description) parts.push(`   Mô tả: ${place.description}`);
      if (place.price_min && place.price_max) {
        parts.push(`   Giá: ${place.price_min.toLocaleString()}đ - ${place.price_max.toLocaleString()}đ`);
      }
      if (place.open_time && place.close_time) {
        parts.push(`   Giờ mở cửa: ${place.open_time} - ${place.close_time}`);
      }
      if (place.similarity_score !== undefined) {
        parts.push(`   Độ phù hợp: ${(place.similarity_score * 100).toFixed(0)}%`);
      }
      return parts.join('\n');
    })
    .join('\n\n');

  const ragSystemPrompt = `Bạn là Fidee, một trợ lý ảo tư vấn địa điểm thân thiện và nhiệt tình.
Người dùng đã hỏi: "${prompt}"

Dưới đây là danh sách các địa điểm phù hợp nhất từ cơ sở dữ liệu:
${placeSummary || '(Không tìm thấy địa điểm nào phù hợp)'}

Quy tắc trả lời:
- Trả lời tự nhiên, ngắn gọn (tối đa 3-4 câu)
- Chỉ dựa trên dữ liệu được cung cấp, KHÔNG bịa thêm thông tin
- Nếu không có kết quả, xin lỗi lịch sự và gợi ý user thử từ khóa khác
- Nếu có nhiều kết quả, ưu tiên giới thiệu 2-3 nơi nổi bật nhất`;

  const userMessage = `Câu hỏi của user: "${prompt}"\n\nDanh sách địa điểm (Context):\n${placeSummary}`;
  const answerResponse = await llm.chat(ragSystemPrompt, userMessage, false, history);

  return {
    answer: answerResponse.content,
    search_method: searchMethod,
    results: places,
  };
}

/**
 * POST /search
 *
 * Authenticated AI-powered semantic search with server-side daily quota.
 */
export function createSearchHandler(deps: SearchDeps = defaultDeps()) {
  return async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> => {
    const body = event.body ? JSON.parse(event.body) : {};
    const prompt = body.prompt as string | undefined;
    const history = body.history as ChatMessage[] | undefined;
    const limit = Math.min(Math.max(Number(body.limit) || 10, 1), 20);

    if (!prompt || prompt.trim().length === 0) {
      return jsonResponse(400, { error: 'Missing required field: prompt' });
    }

    const trimmedPrompt = prompt.trim();

    try {
      const auth = await extractAuth(event);
      const plan = await deps.getPlan(auth.sub);
      const quota = await deps.incrementUsage({ userId: auth.sub, plan });

      if (!quota.allowed) {
        return jsonResponse(429, {
          error: 'AI_QUOTA_EXCEEDED',
          limit: quota.limit,
          used: quota.used,
          resetDate: quota.usageDate,
        });
      }

      const searchResult = await deps.searchPlaces({ prompt: trimmedPrompt, history, limit });

      return jsonResponse(200, {
        ...searchResult,
        prompt: trimmedPrompt,
        quota: {
          limit: quota.limit,
          used: quota.used,
          resetDate: quota.usageDate,
        },
      });
    } catch (error) {
      if (error instanceof Error && error.message.startsWith('Missing auth context')) {
        return jsonResponse(401, { error: error.message });
      }

      console.error('Search error:', error);
      return jsonResponse(500, { error: 'Internal server error during AI search' });
    }
  };
}

export const handler = async (event: APIGatewayProxyEvent): Promise<APIGatewayProxyResult> =>
  createSearchHandler()(event);
