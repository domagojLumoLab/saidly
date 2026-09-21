import type { JWTVerifyGetKey } from 'jose';
import { SignJWT, createLocalJWKSet, exportJWK, generateKeyPair } from 'jose';

/**
 * Stands in for Google's signing keys. Tests sign their own tokens with these,
 * so the real verification path runs without a network call or a Firebase
 * project — only the key source differs from production.
 */
export const projectId = 'saidly-test';
export const issuer = `https://securetoken.google.com/${projectId}`;

const { privateKey, publicKey } = await generateKeyPair('RS256', { extractable: true });
const strangerPair = await generateKeyPair('RS256', { extractable: true });

export const keys: JWTVerifyGetKey = createLocalJWKSet({
  keys: [{ ...(await exportJWK(publicKey)), kid: 'test-key', alg: 'RS256' }],
});

/** A key the JWKS above does not know about. */
export const strangerKey = strangerPair.privateKey;

export type TokenOverrides = {
  audience?: string;
  issuer?: string;
  subject?: string;
  expiresIn?: string | number;
  signWith?: CryptoKey;
};

export function signToken({
  audience = projectId,
  issuer: iss = issuer,
  subject = 'firebase-sub-abc',
  expiresIn = '1h',
  signWith = privateKey,
}: TokenOverrides = {}): Promise<string> {
  const jwt = new SignJWT({})
    .setProtectedHeader({ alg: 'RS256', kid: 'test-key' })
    .setIssuedAt()
    .setIssuer(iss)
    .setAudience(audience)
    .setExpirationTime(expiresIn);

  if (subject) jwt.setSubject(subject);

  return jwt.sign(signWith);
}
