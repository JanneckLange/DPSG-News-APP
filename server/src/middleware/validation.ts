import { Request, Response } from 'express';
import { logWarn } from '../logger';

export function respondBadRequest(req: Request, res: Response, message: string): Response {
  logWarn(message, { requestId: res.locals.requestId, method: req.method, path: req.originalUrl });
  return res.status(400).json({ error: message });
}

export function parseLayerId(value: unknown): number | undefined {
  const num = typeof value === 'number' ? value : Number(value);
  return Number.isInteger(num) && num > 0 ? num : undefined;
}

export function isUniqueViolation(error: unknown): boolean {
  return typeof error === 'object' && error !== null && (error as { code?: string }).code === '23505';
}

export function isForeignKeyViolation(error: unknown): boolean {
  return typeof error === 'object' && error !== null && (error as { code?: string }).code === '23503';
}
