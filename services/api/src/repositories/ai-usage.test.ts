import { describe, expect, it } from 'vitest';
import { quotaForPlan, serverUsageDate } from './ai-usage';

describe('AI usage helpers', () => {
  it('uses product quota limits', () => {
    expect(quotaForPlan('FREE')).toBe(5);
    expect(quotaForPlan('PRO')).toBe(50);
  });

  it('formats server usage date as YYYY-MM-DD', () => {
    expect(serverUsageDate(new Date('2026-06-16T12:34:56Z'))).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });
});
