export class VertexAI {
    // we do not need config vertex for tests
  constructor(_config: unknown) {}

  getGenerativeModel() {
    return {
      generateContent: async () => ({
          // this is for this resp.response?.candidates?.[0]?.content?.parts?.[0]?.text
        response: {
          candidates: [
            {
              content: {
                parts: [
                  {
                    text: "{}",
                  },
                ],
              },
            },
          ],
        },
      }),
    };
  }
}