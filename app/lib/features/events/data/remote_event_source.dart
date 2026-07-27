import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/services/logging_service.dart';
import 'remote_event_source/api_health_status.dart';
import 'remote_event_source/author_session.dart';
import 'remote_event_source/remote_event_source_exception.dart';

export 'remote_event_source/api_health_status.dart';
export 'remote_event_source/author_session.dart';
export 'remote_event_source/remote_event_source_exception.dart';

part 'remote_event_source/remote_event_source_base.dart';
part 'remote_event_source/events_api.dart';
part 'remote_event_source/topics_api.dart';
part 'remote_event_source/layers_api.dart';
part 'remote_event_source/auth_api.dart';
part 'remote_event_source/drafts_api.dart';
part 'remote_event_source/admin_users_api.dart';
part 'remote_event_source/grants_api.dart';

class RemoteEventSource extends _RemoteEventSourceBase
    with
        _EventsApi,
        _TopicsApi,
        _LayersApi,
        _AuthApi,
        _DraftsApi,
        _AdminUsersApi,
        _GrantsApi {
  RemoteEventSource({
    required super.baseUrl,
    super.client,
    super.timeout,
    super.logger,
  });
}
