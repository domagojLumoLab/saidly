import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    environment: 'node',
    // Runs once before the suite: creates the test database if missing and
    // applies every migration to it.
    globalSetup: ['./test/setup/database.ts'],
  },
});
