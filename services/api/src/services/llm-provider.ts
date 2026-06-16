export interface ChatResponse {
  content: string;
}

export interface LlmProvider {
  chat(systemPrompt: string, userMessage: string, forceJson?: boolean): Promise<ChatResponse>;
}

export async function createLlmProvider(): Promise<LlmProvider> {
  const providerType = process.env.LLM_PROVIDER || 'gemini';

  if (providerType === 'bedrock') {
    const { BedrockProvider } = await import('./bedrock-provider');
    return new BedrockProvider();
  } else if (providerType === 'openai') {
    const { OpenAiProvider } = await import('./openai-provider');
    return new OpenAiProvider();
  } else {
    const { GeminiProvider } = await import('./gemini-provider');
    return new GeminiProvider();
  }
}
