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
  contextPlaces?: { id: string; name: string }[];
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
  const { prompt, history, contextPlaces, limit } = input;
  let places: any[] = [];
  let searchMethod: SearchMethod = 'vector';

  // Quick check if user is asking about specific places currently in context
  let isAskingAboutContext = false;
  if (contextPlaces && contextPlaces.length > 0) {
    const normalizedPrompt = prompt.toLowerCase();
    isAskingAboutContext = contextPlaces.some(p => normalizedPrompt.includes(p.name.toLowerCase())) ||
      normalizedPrompt.includes('quán này') || 
      normalizedPrompt.includes('chỗ này') ||
      normalizedPrompt.includes('địa điểm này') ||
      normalizedPrompt.includes('nó');
  }

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

    if (places.length === 0 && !isAskingAboutContext) {
      console.log('Vector search returned 0 results, falling back to keyword...');
      searchMethod = 'keyword';
    }
  } catch (embeddingError) {
    console.error('Vector search failed, falling back to keyword:', embeddingError);
    if (!isAskingAboutContext) searchMethod = 'keyword';
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

  const ragSystemPrompt = `Bạn là Fidee, một trợ lý ảo tư vấn địa điểm ăn uống, vui chơi thân thiện và nhiệt tình.

Quy tắc trả lời:
1. Trả lời tự nhiên, thân thiện, ngắn gọn (tối đa 3-4 câu).
2. Dựa vào bối cảnh cuộc trò chuyện (Lịch sử chat) để hiểu ý người dùng. Nếu người dùng đang nói đùa, hỏi thăm, hoặc đang hỏi tiếp một câu chuyện cũ (VD: "Tại sao?", "Thế à?"), hãy phản hồi tự nhiên theo đúng mạch truyện đó. 
3. Sau khi kết thúc những câu nói đùa hoặc ngoài lề, hãy khéo léo lái câu chuyện về việc gợi ý quán ăn/vui chơi (VD: "À mà hôm nay bạn muốn tìm quán nào không?").
4. Nếu người dùng hỏi các chủ đề hoàn toàn không liên quan (chính trị, toán học, hỏi thông tin cá nhân...): Hãy từ chối một cách khéo léo, vui vẻ và nhắc nhở rằng bạn chỉ có thể giúp gợi ý địa điểm.
5. Khi người dùng hỏi tìm địa điểm, hãy dựa vào Danh sách địa điểm (Context) được cung cấp. KHÔNG bịa thêm thông tin. Nếu có nhiều kết quả, ưu tiên giới thiệu 2-3 nơi nổi bật nhất.
6. Nếu người dùng yêu cầu tìm địa điểm nhưng Danh sách địa điểm rỗng (Không tìm thấy): Xin lỗi lịch sự và gợi ý user nói rõ hơn về món ăn, khu vực hoặc ngân sách.`;

  const contextPlacesText = contextPlaces && contextPlaces.length > 0 
    ? `Các địa điểm user đang nhắc tới: ${contextPlaces.map(p => p.name).join(', ')}\n\n` 
    : '';

  const userMessage = `${contextPlacesText}Câu hỏi của user: "${prompt}"\n\nDanh sách địa điểm (Context):\n${placeSummary}`;
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
    const contextPlaces = body.contextPlaces as { id: string; name: string }[] | undefined;
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

      const searchResult = await deps.searchPlaces({ prompt: trimmedPrompt, history, contextPlaces, limit });

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
