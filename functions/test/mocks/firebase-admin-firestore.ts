// as i have server timestamps and array union I mock them too

export const FieldValue = {
  serverTimestamp: () => "SERVER_TIMESTAMP",
  arrayUnion: (...args: unknown[]) => ({_arrayUnion: args}),
};

// doc mocking firestore
export const getFirestore = () => ({
  collection: () => ({
    add: async () => ({
      id: "mock-doc-id",
      update: async () => {},
    }),
    doc: () => ({
      get: async () => ({
        exists: false,
        data: () => ({}),
      }),
      update: async () => {},
    }),
  }),
});