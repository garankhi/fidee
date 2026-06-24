import { LlmProvider, ChatResponse } from './llm-provider';

// NOTE: To use Bedrock in the future, run:
// npm install @aws-sdk/client-bedrock-runtime
// and uncomment the implementation below.

export class BedrockProvider implements LlmProvider {
  async chat(systemPrompt: string, userMessage: string, forceJson?: boolean): Promise<ChatResponse> {
    throw new Error('Bedrock provider is not fully implemented yet. Please install @aws-sdk/client-bedrock-runtime and update this file.');
    /*
    const { BedrockRuntimeClient, InvokeModelCommand } = require('@aws-sdk/client-bedrock-runtime');
    const client = new BedrockRuntimeClient({ region: process.env.BEDROCK_REGION || 'ap-northeast-1' });

    const payload = {
      anthropic_version: "bedrock-2023-05-31",
      max_tokens: 1000,
      system: systemPrompt,
      messages: [
        {
          role: "user",
          content: [{ type: "text", text: userMessage }]
        }
      ],
    };

    const command = new InvokeModelCommand({
      modelId: process.env.BEDROCK_MODEL_ID || 'anthropic.claude-3-haiku-20240307-v1:0',
      contentType: 'application/json',
      accept: 'application/json',
      body: JSON.stringify(payload),
    });

    const response = await client.send(command);
    const responseBody = JSON.parse(new TextDecoder().decode(response.body));
    return { content: responseBody.content[0].text };
    */
  }
}
