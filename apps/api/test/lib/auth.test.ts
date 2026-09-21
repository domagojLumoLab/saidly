import { describe, expect, it } from 'vitest';
import { verifyIdToken } from '../../src/lib/auth.js';
import { UnauthorizedError } from '../../src/lib/errors.js';
import { keys, projectId, signToken, strangerKey } from '../helpers/firebase-token.js';

describe('verifyIdToken', () => {
  it('returns the sub of a valid token', async () => {
    await expect(verifyIdToken(await signToken(), { keys, projectId })).resolves.toBe(
      'firebase-sub-abc',
    );
  });

  it.each([
    ['an expired token', () => signToken({ expiresIn: '-1h' })],
    ['a token for another project', () => signToken({ audience: 'someone-else' })],
    ['a token from another issuer', () => signToken({ issuer: 'https://evil.example/' })],
    ['a token signed with an unknown key', () => signToken({ signWith: strangerKey })],
    ['a token without a subject', () => signToken({ subject: '' })],
  ])('rejects %s', async (_label, make) => {
    await expect(verifyIdToken(await make(), { keys, projectId })).rejects.toBeInstanceOf(
      UnauthorizedError,
    );
  });

  it.each(['', 'not-a-jwt', 'a.b.c'])('rejects the garbage token %j', async (token) => {
    await expect(verifyIdToken(token, { keys, projectId })).rejects.toBeInstanceOf(
      UnauthorizedError,
    );
  });
});
