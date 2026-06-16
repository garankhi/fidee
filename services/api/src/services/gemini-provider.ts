import { LlmProvider, ChatResponse, ChatMessage } from './llm-provider';
import { GeminiRotator } from './gemini-rotator';
import { Content } from '@google/genai';

export class GeminiProvider implements LlmProvider {
  private rotator: GeminiRotator;
  private model: string;

  constructor() {
    this.rotator = new GeminiRotator();
    this.model = process.env.GEMINI_MODEL || 'gemini-2.5-flash'; // Google Gen AI standard model
  }

  async chat(systemPrompt: string, userMessage: string, forceJson?: boolean, history?: ChatMessage[]): Promise<ChatResponse> {
    const contents: Content[] = [];

    if (history && history.length > 0) {
      history.forEach((msg) => {
        contents.push({
          role: msg.role,
          parts: [{ text: msg.text }],
        });
      });
    }

    // Append the current message
    contents.push({
      role: 'user',
      parts: [{ text: userMessage }],
    });

    const response = await this.rotator.executeWithRetry(async (ai) => {
      return ai.models.generateContent({
        model: this.model,
        contents: contents,
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

