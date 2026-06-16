import OpenAI from 'openai';
import { LlmProvider, ChatResponse } from './llm-provider';

export class OpenAiProvider implements LlmProvider {
  private client: OpenAI;
  private model: string;

  constructor() {
    this.client = new OpenAI({
      apiKey: process.env.OPENAI_API_KEY,
      baseURL: process.env.OPENAI_BASE_URL || undefined,
    });
    this.model = process.env.OPENAI_MODEL || 'gc/gemini-3-flash-preview';
  }

  async chat(systemPrompt: string, userMessage: string, forceJson?: boolean): Promise<ChatResponse> {
    const response = await this.client.chat.completions.create({
      model: this.model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userMessage },
      ],
      stream: false,
      ...(forceJson ? { response_format: { type: 'json_object' } } : {}),
    });

    const content = response.choices[0]?.message?.content || '';
    return { content };
  }
}
