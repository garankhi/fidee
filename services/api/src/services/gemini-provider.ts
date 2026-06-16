import { LlmProvider, ChatResponse } from './llm-provider';
import { GeminiRotator } from './gemini-rotator';

export class GeminiProvider implements LlmProvider {
  private rotator: GeminiRotator;
  private model: string;

  constructor() {
    this.rotator = new GeminiRotator();
    this.model = process.env.GEMINI_MODEL || 'gemini-2.5-flash'; // Google Gen AI standard model
  }

  async chat(systemPrompt: string, userMessage: string, forceJson?: boolean): Promise<ChatResponse> {
    const response = await this.rotator.executeWithRetry(async (ai) => {
      return ai.models.generateContent({
        model: this.model,
        contents: userMessage,
        config: {
          systemInstruction: systemPrompt,
          responseMimeType: forceJson ? 'application/json' : 'text/plain',
        },
      });
    });

    const content = response.text || '';
    return { content };
  }
}

