import { randomUUID } from 'crypto';
import { NextFunction, Request, Response } from 'express';
import { logRequest } from '../logger';

export function requestContextMiddleware(req: Request, res: Response, next: NextFunction): void {
  const startedAt = Date.now();
  const headerRequestId = req.header('x-request-id');
  const requestId = headerRequestId && headerRequestId.trim() ? headerRequestId.trim() : randomUUID();
  res.locals.requestId = requestId;
  res.setHeader('x-request-id', requestId);

  res.on('finish', () => {
    logRequest({
      requestId,
      method: req.method,
      path: req.originalUrl,
      statusCode: res.statusCode,
      durationMs: Date.now() - startedAt,
      ip: req.ip,
      userAgent: req.get('user-agent'),
    });
  });

  next();
}
