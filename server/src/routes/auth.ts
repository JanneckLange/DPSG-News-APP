import { Router, Request, Response } from 'express';
import { AuthorIdentity, changeAuthorPassword, loginAuthor, logoutAuthor, refreshAuthorSession } from '../db';
import { logRequestError } from '../logger';
import { authRateLimiter } from '../middleware/rateLimit';
import { requireAuthorAuth } from '../middleware/auth';
import { respondBadRequest } from '../middleware/validation';

export const authRouter = Router();

authRouter.post('/api/auth/login', authRateLimiter, async (req: Request, res: Response) => {
  try {
    const username = typeof req.body.username === 'string' ? req.body.username.trim() : '';
    const password = typeof req.body.password === 'string' ? req.body.password : '';
    if (!username || !password) {
      return respondBadRequest(req, res, 'Username and password are required');
    }

    const session = await loginAuthor(username, password);
    if (!session) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    res.json({
      token: session.token,
      accessToken: session.token,
      refreshToken: session.refreshToken,
      author: session.author,
      requiresPasswordChange: session.requiresPasswordChange,
      expiresAt: session.expiresAt,
      refreshExpiresAt: session.refreshExpiresAt,
    });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to login' });
  }
});

authRouter.post('/api/auth/refresh', authRateLimiter, async (req: Request, res: Response) => {
  try {
    const refreshToken = typeof req.body.refreshToken === 'string' ? req.body.refreshToken.trim() : '';
    if (!refreshToken) {
      return respondBadRequest(req, res, 'Refresh token is required');
    }

    const session = await refreshAuthorSession(refreshToken);
    if (!session) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }
    res.json({
      token: session.token,
      accessToken: session.token,
      refreshToken: session.refreshToken,
      author: session.author,
      requiresPasswordChange: session.requiresPasswordChange,
      expiresAt: session.expiresAt,
      refreshExpiresAt: session.refreshExpiresAt,
    });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to refresh session' });
  }
});

authRouter.post('/api/auth/logout', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    await logoutAuthor(res.locals.authToken as string);
    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to logout' });
  }
});

authRouter.get('/api/auth/me', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }
    const session = res.locals.authorSession as {
      author: AuthorIdentity;
      requiresPasswordChange: boolean;
      expiresAt: string;
    };
    res.json({
      author: session.author,
      requiresPasswordChange: session.requiresPasswordChange,
      expiresAt: session.expiresAt,
    });
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to load author session' });
  }
});

authRouter.post('/api/auth/change-password', async (req: Request, res: Response) => {
  try {
    if (!await requireAuthorAuth(req, res)) {
      return;
    }

    const newPassword = typeof req.body.newPassword === 'string' ? req.body.newPassword : '';
    const oldPassword = typeof req.body.oldPassword === 'string' ? req.body.oldPassword : undefined;
    if (newPassword.trim().length < 8) {
      return respondBadRequest(req, res, 'New password must be at least 8 characters long');
    }

    const author = res.locals.author as { id: number; username: string };
    const changed = await changeAuthorPassword(author.id, newPassword, oldPassword);
    if (changed === 'invalid_old_password') {
      return respondBadRequest(req, res, 'Invalid old password');
    }
    if (changed === 'author_not_found') {
      return res.status(404).json({ error: 'Author not found' });
    }

    res.status(204).end();
  } catch (error) {
    logRequestError(error, res.locals.requestId);
    res.status(500).json({ error: 'Unable to change password' });
  }
});
