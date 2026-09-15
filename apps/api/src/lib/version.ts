import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const pkg = require('../../package.json') as { version: string };

/** Version reported by GET /health. Single source of truth: package.json. */
export const version: string = pkg.version;
