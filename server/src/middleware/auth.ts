import { Request, Response } from 'express';
import { getAuthorSession } from '../db';

export function getBearerToken(req: Request): string | null {
  const authorization = req.header('authorization');
  if (!authorization) {
    return null;
  }
  const [scheme, value] = authorization.split(' ');
  if (scheme?.toLowerCase() !== 'bearer' || !value?.trim()) {
    return null;
  }
  return value.trim();
}

export async function requireAuthorAuth(req: Request, res: Response): Promise<boolean> {
  const token = getBearerToken(req);
  if (!token) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }

  const session = await getAuthorSession(token);
  if (!session) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }

  res.locals.author = session.author;
  res.locals.authorSession = session;
  res.locals.authToken = token;
  return true;
}

export async function getViewerSession(req: Request) {
  const token = getBearerToken(req);
  if (!token) {
    return null;
  }
  return getAuthorSession(token);
}

export function requireAdminSession(res: Response): boolean {
  const author = res.locals.author as { isAdmin?: boolean } | undefined;
  if (!author?.isAdmin) {
    res.status(403).json({ error: 'Forbidden' });
    return false;
  }
  return true;
}

export function requirePasswordChangeCompleted(res: Response): boolean {
  const session = res.locals.authorSession as { requiresPasswordChange: boolean } | undefined;
  if (session?.requiresPasswordChange) {
    res.status(403).json({ error: 'Password change required' });
    return false;
  }
  return true;
}
