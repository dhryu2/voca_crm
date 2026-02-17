import { defineConfig } from 'orval';

export default defineConfig({
  vocaCrmApi: {
    input: {
      target: '../voca_crm_api/openapi/openapi.json',
    },
    output: {
      mode: 'split',
      target: 'src/generated/api/endpoints.ts',
      schemas: 'src/generated/api/models',
      client: 'react-query',
      clean: true,
      override: {
        mutator: {
          path: 'src/lib/apiClient.ts',
          name: 'customFetch',
        },
        query: {
          useQuery: true,
          useMutation: true,
          signal: true,
        },
      },
    },
  },
});
