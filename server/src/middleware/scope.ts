import { Response } from 'express';
import { AuthorIdentity, getLayerById, isLayerInAdminScope } from '../db';

export async function requireLayerScope(res: Response, targetLayerId: number | null | undefined): Promise<boolean> {
  const author = res.locals.author as { adminLayerIds?: number[] } | undefined;
  if (!targetLayerId || !author?.adminLayerIds?.length || !await isLayerInAdminScope(author.adminLayerIds, targetLayerId)) {
    res.status(403).json({ error: 'Forbidden' });
    return false;
  }
  return true;
}

// Fuer Aktionen gegen einen ANDEREN Admin (delete/reset-password/Layer-Verwaltung):
// jeder Layer des Ziel-Admins muss im Scope des handelnden Admins liegen, nicht nur
// irgendeiner davon - sonst koennte ein niedriger-scoped Admin einen Account
// beeinflussen, der auch Rechte ausserhalb seiner eigenen Reichweite haelt.
export async function requireLayerScopeForAll(res: Response, targetLayerIds: number[]): Promise<boolean> {
  const author = res.locals.author as { adminLayerIds?: number[] } | undefined;
  if (!author?.adminLayerIds?.length) {
    res.status(403).json({ error: 'Forbidden' });
    return false;
  }
  if (!targetLayerIds.length) {
    // Ziel hat noch keine Admin-Layer (z.B. Promotion eines Autors zum Admin) -
    // nichts ausserhalb des eigenen Scopes vorhanden, also unbedenklich.
    return true;
  }
  for (const targetLayerId of targetLayerIds) {
    if (!await isLayerInAdminScope(author.adminLayerIds, targetLayerId)) {
      res.status(403).json({ error: 'Forbidden' });
      return false;
    }
  }
  return true;
}

// Autoren duerfen Events nur auf explizit zugewiesenen Layern/Topics erstellen
// (Rechtematrix aus #1: "create post: own layer/topic", unabhaengig vom Admin-Status).
export function requireEventGrant(res: Response, layerId: number, topicId: number | undefined): boolean {
  const author = res.locals.author as AuthorIdentity | undefined;
  if (!author?.layerGrantIds?.includes(layerId)) {
    res.status(403).json({ error: 'Forbidden' });
    return false;
  }
  if (typeof topicId === 'number' && !author.topicGrantIds?.includes(topicId)) {
    res.status(403).json({ error: 'Forbidden' });
    return false;
  }
  return true;
}

export async function isKnownLayerId(layerId: number): Promise<boolean> {
  return (await getLayerById(layerId)) !== null;
}

// Ownership ODER (Admin UND targetLayerId liegt im eigenen Scope, "und darunter").
// Rechtematrix aus #1/#16: "edit/delete post" bzw. "edit/delete update".
export async function canManageWithinLayerScope(
  author: AuthorIdentity | undefined,
  targetAuthorId: number | null,
  targetLayerId: number | null
): Promise<boolean> {
  if (!author) {
    return false;
  }
  if (targetAuthorId != null && targetAuthorId === author.id) {
    return true;
  }
  if (!author.isAdmin || targetLayerId == null) {
    return false;
  }
  return isLayerInAdminScope(author.adminLayerIds, targetLayerId);
}

export async function requireManageableWithinLayerScope(
  res: Response,
  targetAuthorId: number | null,
  targetLayerId: number | null
): Promise<boolean> {
  const author = res.locals.author as AuthorIdentity | undefined;
  if (!author) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }
  if (!await canManageWithinLayerScope(author, targetAuthorId, targetLayerId)) {
    res.status(403).json({ error: 'Forbidden' });
    return false;
  }
  return true;
}

// Reine Ownership ohne Admin-Bypass - fuer "create update" (Rechtematrix: Admin
// darf grundsaetzlich keine Updates erstellen, auch nicht innerhalb seines Scopes).
export function requireOwnEvent(res: Response, eventAuthorId: number | null): boolean {
  const author = res.locals.author as { id: number } | undefined;
  if (!author) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }
  if (eventAuthorId !== author.id) {
    res.status(403).json({ error: 'Forbidden' });
    return false;
  }
  return true;
}
