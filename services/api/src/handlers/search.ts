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

type SearchMethod = 'vector' | 'keyword' | 'place_lookup' | 'guard';

interface ContextPlace {
  id: string;
  name: string;
}

interface SearchPlacesInput {
  prompt: string;
  history?: ChatMessage[];
  contextPlaces?: ContextPlace[];
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

function normalizeVietnamese(value: string): string {
  return value
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/đ/g, 'd')
    .replace(/Đ/g, 'D')
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function containsAny(normalizedPrompt: string, terms: string[]): boolean {
  return terms.some((term) => normalizedPrompt.includes(term));
}

function isTransientLlmError(error: unknown): boolean {
  if (!error || typeof error !== 'object') return false;
  const err = error as { status?: number; response?: { status?: number }; message?: string };
  const status = err.status ?? err.response?.status;
  const message = (err.message ?? '').toLowerCase();

  return (
    status === 429 ||
    status === 503 ||
    status === 504 ||
    message.includes('quota') ||
    message.includes('rate limit') ||
    message.includes('high demand') ||
    message.includes('unavailable') ||
    message.includes('overloaded')
  );
}

function splitSearchKeywords(prompt: string): string[] {
  const normalized = normalizeVietnamese(prompt);
  const stopWords = new Set([
    'tim',
    'cho',
    'toi',
    'minh',
    'gan',
    'day',
    'o',
    'dau',
    'co',
    'khong',
    'quan',
    'tiem',
    'nha',
    'hang',
  ]);

  return normalized
    .split(' ')
    .map((token) => token.trim())
    .filter((token) => token.length >= 2 && !stopWords.has(token))
    .slice(0, 8);
}

function buildFallbackAnswer(prompt: string, places: any[], searchMethod: SearchMethod): string {
  if (places.length === 0) {
    return 'Fidee chưa tìm được địa điểm phù hợp. Bạn thử nói rõ hơn món muốn ăn, khu vực hoặc ngân sách nhé.';
  }

  const firstPlace = places[0];
  if (searchMethod === 'place_lookup') {
    const details: string[] = [];
    if (firstPlace.price_min && firstPlace.price_max) {
      details.push(`giá khoảng ${Number(firstPlace.price_min).toLocaleString()}đ - ${Number(firstPlace.price_max).toLocaleString()}đ`);
    }
    if (firstPlace.open_time && firstPlace.close_time) {
      details.push(`mở cửa ${firstPlace.open_time} - ${firstPlace.close_time}`);
    }
    if (firstPlace.address) {
      details.push(`địa chỉ ${firstPlace.address}`);
    }

    if (details.length === 0) {
      return `Fidee tìm thấy ${firstPlace.name}, nhưng hiện chưa có đủ thông tin chi tiết cho câu hỏi "${prompt}".`;
    }

    return `Fidee tìm thấy ${firstPlace.name}: ${details.join(', ')}.`;
  }

  const placeNames = places
    .slice(0, 3)
    .map((place) => place.name)
    .join(', ');
  return `Fidee tìm được vài địa điểm hợp vibe: ${placeNames}. Bạn có thể nhấn vào card để xem chi tiết từng quán.`;
}

function asksSensitiveNonPlaceInfo(prompt: string): boolean {
  const normalized = normalizeVietnamese(prompt);
  const sensitiveTerms = [
    'mat khau',
    'password',
    'otp',
    'cccd',
    'cmnd',
    'can cuoc',
    'tai khoan ngan hang',
    'so the',
    'the tin dung',
    'doi tu',
    'luong',
    'thu nhap',
    'chinh tri',
    'y te',
    'chan doan',
  ];

  return containsAny(normalized, sensitiveTerms);
}

function isSpecificPlaceInfoPrompt(prompt: string, contextPlaces: ContextPlace[] = []): boolean {
  const normalized = normalizeVietnamese(prompt);
  const infoTerms = [
    'gia',
    'bao nhieu',
    'dia chi',
    'o dau',
    'gio mo cua',
    'dong cua',
    'mo cua',
    'so dien thoai',
    'sdt',
    'menu',
    'mon gi',
    'co gi',
    'thong tin',
    'review',
    'danh gia',
    'nhan vien',
    'phuc vu',
    'thai do',
    'dong',
    'vang',
    'ngon',
    'dep',
    'xinh',
    'sach',
    'on khong',
  ];
  const placeNameHints = [
    'quan ',
    'tiem ',
    'nha hang ',
    'cafe ',
    'ca phe ',
    'tra sua ',
    'quan do',
    'quan dau tien',
    'quan thu ',
    'cho do',
    'noi do',
    'quan nay',
    'tiem nay',
    'nha hang nay',
    'cafe nay',
    'ca phe nay',
    'tra sua nay',
    'tiem do',
  ];
  const broadSearchTerms = [
    'tim ',
    'goi y',
    'gan day',
    'quanh day',
    'xung quanh',
    'an gi',
    'uong gi',
    'nen an',
    'nen uong',
    'muon an',
    'muon uong',
    'vibe',
    'hop vibe',
    'quan nao',
    'mon nao',
    'may quan',
  ];

  if (contextPlaces.length > 0 && findContextPlace(prompt, contextPlaces)) {
    return true;
  }

  const hasInfoIntent = containsAny(normalized, infoTerms);
  const hasPlaceHint = containsAny(normalized, placeNameHints);
  if (hasInfoIntent && hasPlaceHint) return true;

  return hasPlaceHint && !containsAny(normalized, broadSearchTerms);
}

async function findSpecificPlaces(prompt: string, limit: number): Promise<any[]> {
  const normalizedPrompt = normalizeVietnamese(prompt);
  const sql = `
    WITH ranked AS (
      SELECT DISTINCT ON (p.normalized_name)
        p.id, p.name, p.category, p.address, p.description,
        p.open_time, p.close_time, p.price_min, p.price_max,
        p.metadata,
        ST_X(p.location::geometry) AS lng,
        ST_Y(p.location::geometry) AS lat,
        CASE
          WHEN $1 LIKE '%' || p.normalized_name || '%' THEN 1
          ELSE 0
        END AS exact_name_match,
        similarity(p.normalized_name, $1) AS similarity_score
      FROM places p
      JOIN place_settings ps ON ps.place_id = p.id
      WHERE ps.status = 'APPROVED'
        AND ps.visibility = 'PUBLIC'
        AND (
          $1 LIKE '%' || p.normalized_name || '%'
          OR similarity(p.normalized_name, $1) >= 0.35
        )
      ORDER BY
        p.normalized_name,
        exact_name_match DESC,
        similarity_score DESC,
        p.created_at DESC
    )
    SELECT *
    FROM ranked
    WHERE exact_name_match = 1 OR similarity_score >= 0.45
    ORDER BY exact_name_match DESC, similarity_score DESC
    LIMIT $2;
  `;

  const result = await query(sql, [normalizedPrompt, limit]);
  return result.rows;
}

function parseOrdinalPlaceReference(normalizedPrompt: string): number | null {
  if (normalizedPrompt.includes('quan dau tien') || normalizedPrompt.includes('quan 1')) {
    return 0;
  }

  const ordinalMatch = normalizedPrompt.match(/quan thu\s+(\d+)/);
  if (ordinalMatch?.[1]) {
    return Math.max(Number(ordinalMatch[1]) - 1, 0);
  }

  if (
    normalizedPrompt.includes('quan do') ||
    normalizedPrompt.includes('cho do') ||
    normalizedPrompt.includes('noi do')
  ) {
    return 0;
  }

  return null;
}

function scoreContextPlace(prompt: string, place: ContextPlace): number {
  const normalizedPrompt = normalizeVietnamese(prompt);
  const normalizedName = normalizeVietnamese(place.name);
  if (!normalizedName) return 0;
  if (normalizedPrompt.includes(normalizedName)) return 1;

  const nameTokens = normalizedName.split(' ').filter((token) => token.length >= 2);
  if (nameTokens.length === 0) return 0;

  const matchedTokens = nameTokens.filter((token) => normalizedPrompt.includes(token));
  return matchedTokens.length / nameTokens.length;
}

function findContextPlace(prompt: string, contextPlaces: ContextPlace[]): ContextPlace | null {
  if (contextPlaces.length === 0) return null;

  const normalizedPrompt = normalizeVietnamese(prompt);
  const ordinalIndex = parseOrdinalPlaceReference(normalizedPrompt);
  if (ordinalIndex !== null && contextPlaces[ordinalIndex]) {
    return contextPlaces[ordinalIndex];
  }

  const ranked = contextPlaces
    .map((place) => ({ place, score: scoreContextPlace(prompt, place) }))
    .sort((a, b) => b.score - a.score);

  return ranked[0]?.score >= 0.6 ? ranked[0].place : null;
}

async function getPlaceById(placeId: string): Promise<any | null> {
  const sql = `
    SELECT
      p.id, p.name, p.category, p.address, p.description,
      p.open_time, p.close_time, p.price_min, p.price_max,
      p.metadata,
      ST_X(p.location::geometry) AS lng,
      ST_Y(p.location::geometry) AS lat,
      1::double precision AS similarity_score
    FROM places p
    JOIN place_settings ps ON ps.place_id = p.id
    WHERE p.id = $1
      AND ps.status = 'APPROVED'
      AND ps.visibility = 'PUBLIC'
    LIMIT 1;
  `;
  const result = await query(sql, [placeId]);
  return result.rows[0] ?? null;
}

async function performSemanticSearch(input: SearchPlacesInput): Promise<SearchPlacesResult> {
  const { prompt, history, contextPlaces = [], limit } = input;
  let places: any[] = [];
  let searchMethod: SearchMethod = 'vector';

  if (isSpecificPlaceInfoPrompt(prompt, contextPlaces)) {
    const contextPlace = findContextPlace(prompt, contextPlaces);
    if (contextPlace) {
      const place = await getPlaceById(contextPlace.id);
      places = place ? [place] : [];
    }

    if (places.length === 0) {
      places = await findSpecificPlaces(prompt, 1);
    }
    searchMethod = 'place_lookup';
  } else if (places.length === 0) {
    try {
      const embeddingService = new EmbeddingService();
      const queryVector = await embeddingService.embedText(prompt);
      const vectorString = `[${queryVector.join(',')}]`;
      const minSimilarity = 0.68;

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
          AND 1 - (p.embedding <=> $1::vector) >= $3
        ORDER BY p.embedding <=> $1::vector
        LIMIT $2;
      `;

      console.log('Executing Vector Search...');
      const dbResult = await query(vectorSql, [vectorString, limit, minSimilarity]);
      places = dbResult.rows;

      if (places.length === 0) {
        console.log('Vector search returned 0 results, falling back to keyword...');
        searchMethod = 'keyword';
      }
    } catch (embeddingError) {
      console.error('Vector search failed, falling back to keyword:', embeddingError);
      searchMethod = 'keyword';
    }
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

    let filters: { category?: string | null; keywords?: string[]; limit?: number } = {};
    try {
      const filterResponse = await llm.chat(extractSystemPrompt, prompt, true);
      const cleanJson = filterResponse.content.replace(/```json/g, '').replace(/```/g, '').trim();
      filters = JSON.parse(cleanJson);
    } catch (error) {
      if (!isTransientLlmError(error)) {
        console.warn('Keyword extraction failed, falling back to local keywords:', error);
      }
      filters = { keywords: splitSearchKeywords(prompt), limit };
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

  const specificPlaceRules =
    searchMethod === 'place_lookup'
      ? `
- Người dùng đang hỏi thông tin của một quán cụ thể.
- Chỉ trả lời về đúng địa điểm trong context, KHÔNG đề xuất thêm quán khác.
- Nếu context không có thông tin được hỏi, nói rằng Fidee chưa có thông tin đó.`
      : `
- Nếu có nhiều kết quả, ưu tiên giới thiệu 2-3 nơi nổi bật nhất`;

  const ragSystemPrompt = `Bạn là Fidee, một trợ lý ảo tư vấn địa điểm ăn uống thân thiện và nhiệt tình.
Người dùng đã hỏi: "${prompt}"

Dưới đây là danh sách các địa điểm phù hợp nhất từ cơ sở dữ liệu:
${placeSummary || '(Không tìm thấy địa điểm nào phù hợp)'}

Quy tắc trả lời BẮT BUỘC (System Rules):
1. Trả lời tự nhiên, ngắn gọn (tối đa 3-4 câu).
2. Chỉ dựa trên dữ liệu được cung cấp, KHÔNG được tự bịa thêm thông tin.
3. Nếu người dùng CHÀO HỎI (ví dụ: hello, hi, chào bạn, bạn khỏe không), hãy chào lại thật thân thiện và chủ động hỏi xem họ đang muốn tìm quán ăn, cafe hay địa điểm vui chơi nào hôm nay.
4. Nếu người dùng hỏi một chủ đề KHÔNG LIÊN QUAN ĐẾN ĂN UỐNG, VUI CHƠI VÀ KHÔNG PHẢI CHÀO HỎI (ví dụ: thông tin cá nhân, nhân viên quán, chính trị, lịch sử, toán học, chửi bới, thông tin nhạy cảm), hãy từ chối một cách lịch sự, tự nhiên và hướng họ quay lại chủ đề ẩm thực. (VD: "Fidee không thể cung cấp thông tin cá nhân... Mình chỉ có thể gợi ý quán ăn thôi, bạn muốn ăn gì không?")
5. Nếu người dùng HỎI THÔNG TIN CỦA MỘT QUÁN CỤ THỂ (ví dụ hỏi giá, địa chỉ, review của một quán A), nhưng trong dữ liệu cung cấp KHÔNG có quán đó, hãy xin lỗi và nói rằng Fidee chưa có thông tin về quán này. TUYỆT ĐỐI KHÔNG tự động gợi ý sang các quán khác nếu người dùng không yêu cầu.
6. Nếu người dùng TÌM KIẾM/GỢI Ý (ví dụ: gợi ý quán cafe, tìm quán bún bò), hãy gợi ý 2-3 quán nổi bật nhất từ dữ liệu.
${specificPlaceRules}`;

  const userMessage = `Câu hỏi của user: "${prompt}"\n\nDanh sách địa điểm (Context):\n${placeSummary}`;
  let answerContent: string;
  try {
    const answerResponse = await llm.chat(ragSystemPrompt, userMessage, false, history);
    answerContent = answerResponse.content.trim();
  } catch (error) {
    if (isTransientLlmError(error)) {
      console.warn('LLM answer generation unavailable, returning deterministic fallback:', error);
      return {
        answer: buildFallbackAnswer(prompt, places, searchMethod),
        search_method: searchMethod,
        results: places,
      };
    }
    throw error;
  }

  return {
    answer: answerContent,
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
    const contextPlaces = Array.isArray(body.contextPlaces)
      ? body.contextPlaces
          .filter((place: unknown): place is Record<string, unknown> => {
            return typeof place === 'object' && place !== null;
          })
          .map((place: Record<string, unknown>): ContextPlace => ({
            id: String(place.id ?? ''),
            name: String(place.name ?? ''),
          }))
          .filter((place: ContextPlace) => place.id.trim().length > 0 && place.name.trim().length > 0)
          .slice(0, 10)
      : undefined;
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

      const searchResult = await deps.searchPlaces({
        prompt: trimmedPrompt,
        history,
        contextPlaces,
        limit,
      });

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
