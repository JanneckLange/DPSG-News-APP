export type AuthorRow = {
  id: number;
  username: string;
  password_hash: string;
  one_time_password_hash: string | null;
  must_change_password: boolean;
  is_active: boolean;
  is_admin: boolean;
  admin_layer_id: number | null;
};

export type AuthorRowWithAdminLayers = AuthorRow & { admin_layer_ids: number[] };

export type AuthorRowWithGrants = AuthorRowWithAdminLayers & {
  layer_grant_ids: number[];
  topic_grant_ids: number[];
};

export type AuthorRecord = {
  id: number;
  username: string;
  isAdmin: boolean;
  isActive: boolean;
  requiresPasswordChange: boolean;
  adminLayerIds: number[];
  layerGrantIds: number[];
  topicGrantIds: number[];
};
