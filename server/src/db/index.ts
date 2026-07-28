export { close } from './client';

export { connect } from './schema';

export type { AuthorIdentity, AuthSession, AuthLoginSession, ChangePasswordResult } from './authors';
export {
  clearAuthorData,
  createAuthorForTesting,
  loginAuthor,
  getAuthorSession,
  refreshAuthorSession,
  listAuthors,
  getAuthorById,
  createAuthor,
  setAuthorActive,
  deleteAuthorById,
  resetAuthorPassword,
  logoutAuthor,
  changeAuthorPassword,
} from './authors';

export type { Event, EventInput } from './events';
export {
  mapEventRow,
  getEvents,
  createEvent,
  createAuthorEvent,
  deleteEventById,
  getAuthorEvents,
  updateAuthorEventById,
  updateEventById,
  deleteAuthorEventById,
  deleteAllEvents,
  clearEvents,
} from './events';

export type { Draft, DraftInput } from './drafts';
export {
  mapDraftRow,
  cleanupExpiredDrafts,
  createAuthorDraft,
  getAuthorDrafts,
  updateAuthorDraftById,
  deleteAuthorDraftById,
  clearDrafts,
} from './drafts';

export type { EventUpdate } from './eventUpdates';
export {
  mapEventUpdateRow,
  createEventUpdate,
  getEventUpdates,
  getEventUpdateById,
  updateEventUpdateById,
  deleteEventUpdateById,
} from './eventUpdates';

export type {
  Layer,
  LayerInput,
  LayerAdminRecord,
  RemoveAdminLayerResult,
  UpdateLayerResult,
  DeleteLayerResult,
} from './layers';
export {
  mapLayerRow,
  getLayers,
  getLayerById,
  getRootLayerId,
  isLayerInAdminScope,
  getLayerSubtree,
  getLayerAdmins,
  getAdminLayerIds,
  addAdminLayer,
  removeAdminLayer,
  getAuthorLayerGrantIds,
  addAuthorLayerGrant,
  removeAuthorLayerGrant,
  createLayer,
  updateLayer,
  deleteLayer,
} from './layers';

export type { Topic, TopicInput, DeleteTopicResult } from './topics';
export {
  mapTopicRow,
  getAuthorTopicGrantIds,
  addAuthorTopicGrant,
  removeAuthorTopicGrant,
  getTopics,
  getTopicById,
  createTopic,
  updateTopic,
  deleteTopic,
} from './topics';

export type { AuthorRecord } from './types';
