import { randomBytes, scryptSync, timingSafeEqual } from 'crypto';

const SCRYPT_KEY_LENGTH = 64;

export function hashPassword(password: string): string {
  const salt = randomBytes(16).toString('hex');
  const derivedKey = scryptSync(password, salt, SCRYPT_KEY_LENGTH).toString('hex');
  return `${salt}:${derivedKey}`;
}

export function verifyPassword(password: string, storedHash: string): boolean {
  const [salt, expectedHash] = storedHash.split(':');
  if (!salt || !expectedHash) {
    return false;
  }

  const derivedKey = scryptSync(password, salt, SCRYPT_KEY_LENGTH);
  const expectedBuffer = Buffer.from(expectedHash, 'hex');
  if (expectedBuffer.length !== derivedKey.length) {
    return false;
  }
  return timingSafeEqual(expectedBuffer, derivedKey);
}
