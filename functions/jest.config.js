module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  // it is for any file that has .test.ts in end
  testMatch: ["**/*.test.ts"],

  // I am mocking firebase, vertex  for testing functions on index.ts
  moduleNameMapper: {
    "^firebase-functions/v2$": "<rootDir>/test/mocks/firebase-functions-v2.ts",
    "^firebase-functions/v2/https$": "<rootDir>/test/mocks/firebase-functions-v2-https.ts",
    "^firebase-functions/https$": "<rootDir>/test/mocks/firebase-functions-https.ts",
    "^firebase-functions/logger$": "<rootDir>/test/mocks/firebase-functions-logger.ts",
    "^firebase-admin$": "<rootDir>/test/mocks/firebase-admin.ts",
    "^firebase-admin/firestore$": "<rootDir>/test/mocks/firebase-admin-firestore.ts",
    "^@google-cloud/vertexai$": "<rootDir>/test/mocks/vertexai.ts",
  },
};






