import type { UserPlan } from './user-profiles';

export interface AiUsageResult {
  used: number;
  limit: number;
  allowed: boolean;
  usageDate: string;
}

export function quotaForPlan(plan: UserPlan): number {
  return plan === 'PRO' ? 50 : 5;
}

export function serverUsageDate(now = new Date()): string {
  return now.toISOString().slice(0, 10);
}

export async function incrementAiUsage(input: {
  userId: string;
  plan: UserPlan;
  now?: Date;
}): Promise<AiUsageResult> {
  const { query } = await import('../db/client');
  const limit = quotaForPlan(input.plan);
  const usageDate = serverUsageDate(input.now);

  const result = await query<{ input_count: number | string }>(
    `
      INSERT INTO ai_usage_daily (user_id, usage_date, input_count, updated_at)
      VALUES ($1, $2::date, 1, NOW())
      ON CONFLICT (user_id, usage_date) DO UPDATE SET
        input_count = ai_usage_daily.input_count + 1,
        updated_at = NOW()
      WHERE ai_usage_daily.input_count < $3
      RETURNING input_count;
    `,
    [input.userId, usageDate, limit],
  );

  const row = result.rows[0];
  if (row !== undefined) {
    return {
      used: Number(row.input_count),
      limit,
      allowed: true,
      usageDate,
    };
  }

  const existing = await query<{ input_count: number | string }>(
    `
      SELECT input_count
      FROM ai_usage_daily
      WHERE user_id = $1 AND usage_date = $2::date;
    `,
    [input.userId, usageDate],
  );

  return {
    used: Number(existing.rows[0]?.input_count ?? limit),
    limit,
    allowed: false,
    usageDate,
  };
}
