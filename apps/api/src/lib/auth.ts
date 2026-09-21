import type { JWTVerifyGetKey } from 'jose';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { UnauthorizedError } from './errors.js';

/** Google's public keys for Firebase ID tokens, per docs/decisions/001. */
const GOOGLE_JWKS_URL = new URL(
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
);

/** A JWKS, or anything else `jose` accepts as a verification key. */
export type KeySource = JWTVerifyGetKey | CryptoKey;

export type AuthOptions = {
  keys: KeySource;
  projectId: string;
};

/**
 * Caches the fetched keys and refetches them when Google rotates. Build it once
 * at startup, not per request.
 */
export function googleSecureTokenKeys(): JWTVerifyGetKey {
  return createRemoteJWKSet(GOOGLE_JWKS_URL);
}

/**
 * Verifies a Firebase ID token and returns its `sub`, which is our userId.
 *
 * Every failure becomes the same `UnauthorizedError`: a caller learns only that
 * the token was not accepted, never why. The real reason travels in `cause` for
 * the error handler to log.
 */
export async function verifyIdToken(
  token: string,
  { keys, projectId }: AuthOptions,
): Promise<string> {
  let sub: string | undefined;

  try {
    const { payload } = await jwtVerify(token, keys, {
      algorithms: ['RS256'],
      audience: projectId,
      issuer: `https://securetoken.google.com/${projectId}`,
    });
    sub = payload.sub;
  } catch (cause) {
    throw new UnauthorizedError({ cause });
  }

  if (!sub) {
    throw new UnauthorizedError({ cause: new Error('token has no sub claim') });
  }

  return sub;
}
