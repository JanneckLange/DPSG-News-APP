import { Response } from 'express';
import { AuthorIdentity, AuthorRecord, getLayerById, getTopicById, isLayerInAdminScope } from '../db';

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

type AccountScopeTarget = { adminLayerIds: number[]; layerGrantIds: number[]; topicGrantIds: number[] };

// Vereinigung aller Rechte eines Kontos (Admin-Layer, Layer-Grants, Layer der
// Topic-Grants) als flache Layer-Id-Liste - Grundlage sowohl fuer die Verwaltungs-
// Scope-Pruefung als auch fuer die Sichtbarkeitsregel in der Nutzerliste.
async function getAccountScopeLayerIds(target: AccountScopeTarget): Promise<number[]> {
  const topicLayerIds = await Promise.all(
    target.topicGrantIds.map(async (topicId) => (await getTopicById(topicId))?.layerId)
  );
  return [
    ...target.adminLayerIds,
    ...target.layerGrantIds,
    ...topicLayerIds.filter((layerId): layerId is number => layerId != null),
  ];
}

// Fuer Kontoverwaltung eines beliebigen Zielnutzers (activate/deactivate, delete,
// reset-password): Admin und Autor sind technisch dasselbe Konto, daher gilt
// einheitlich "layer and below" ueber die Vereinigung aller Rechte des Ziels -
// analog zu requireLayerScopeForAll fuer Admin-Ziele, nur erweitert um Autoren-Grants.
export async function requireManageableAccountScope(res: Response, target: AccountScopeTarget): Promise<boolean> {
  const targetLayerIds = await getAccountScopeLayerIds(target);
  return requireLayerScopeForAll(res, targetLayerIds);
}

// Sichtbarkeit in der Admin-Nutzerliste (#112): sichtbar, wenn mindestens ein Recht
// im eigenen Layer-Zweig liegt. Ein Konto ganz ohne Rechte (frisch angelegt) ist nur
// fuer seinen Ersteller und fuer Admins des Wurzel-Layers sichtbar - sonst koennte
// niemand einem neuen Autor je den ersten Grant zuweisen, ohne dass er fuer alle
// Admins systemweit sichtbar waere.
export async function isAccountVisibleToAdmin(
  admin: { id: number; adminLayerIds: number[] },
  target: AccountScopeTarget & { createdByAuthorId: number | null },
  rootLayerId: number | null
): Promise<boolean> {
  const targetLayerIds = await getAccountScopeLayerIds(target);
  if (targetLayerIds.length === 0) {
    return target.createdByAuthorId === admin.id || (rootLayerId != null && admin.adminLayerIds.includes(rootLayerId));
  }
  for (const targetLayerId of targetLayerIds) {
    if (await isLayerInAdminScope(admin.adminLayerIds, targetLayerId)) {
      return true;
    }
  }
  return false;
}

// Redaktion der Grant-Felder auf den eigenen Layer-Zweig (#18/#112): ein Admin sieht
// bei einem sichtbaren Nutzer nur die Rechte innerhalb des eigenen Zweigs, nicht das
// vollstaendige Bild ueber fremde Layer hinweg.
async function redactToOwnScope(admin: { adminLayerIds: number[] }, layerIds: number[]): Promise<number[]> {
  const flags = await Promise.all(layerIds.map((layerId) => isLayerInAdminScope(admin.adminLayerIds, layerId)));
  return layerIds.filter((_, index) => flags[index]);
}

export async function filterAuthorsForAdmin(
  admin: { id: number; adminLayerIds: number[] },
  authors: AuthorRecord[],
  rootLayerId: number | null
): Promise<AuthorRecord[]> {
  const visible: AuthorRecord[] = [];
  for (const author of authors) {
    if (!await isAccountVisibleToAdmin(admin, author, rootLayerId)) {
      continue;
    }
    const topicLayerPairs = await Promise.all(
      author.topicGrantIds.map(async (topicId) => ({ topicId, layerId: (await getTopicById(topicId))?.layerId }))
    );
    const visibleTopicGrantIds = (
      await Promise.all(
        topicLayerPairs.map(async (pair) =>
          pair.layerId != null && (await isLayerInAdminScope(admin.adminLayerIds, pair.layerId)) ? pair.topicId : null
        )
      )
    ).filter((topicId): topicId is number => topicId != null);
    visible.push({
      ...author,
      adminLayerIds: await redactToOwnScope(admin, author.adminLayerIds),
      layerGrantIds: await redactToOwnScope(admin, author.layerGrantIds),
      topicGrantIds: visibleTopicGrantIds,
    });
  }
  return visible;
}

type EventGrantHolder = { layerGrantIds?: number[]; topicGrantIds?: number[] } | undefined;

// Reine Grant-Pruefung ohne Response-Kopplung, damit sie sowohl fuer den
// eingeloggten Autor (requireEventGrant) als auch fuer eine beliebige
// Zielperson (Event-Uebertragung, #22/#23) verwendet werden kann.
export function authorHasEventGrant(author: EventGrantHolder, layerId: number, topicId: number | undefined): boolean {
  if (!author?.layerGrantIds?.includes(layerId)) {
    return false;
  }
  if (typeof topicId === 'number' && !author.topicGrantIds?.includes(topicId)) {
    return false;
  }
  return true;
}

// Autoren duerfen Events nur auf explizit zugewiesenen Layern/Topics erstellen
// (Rechtematrix aus #1: "create post: own layer/topic", unabhaengig vom Admin-Status).
export function requireEventGrant(res: Response, layerId: number, topicId: number | undefined): boolean {
  const author = res.locals.author as AuthorIdentity | undefined;
  if (!authorHasEventGrant(author, layerId, topicId)) {
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
