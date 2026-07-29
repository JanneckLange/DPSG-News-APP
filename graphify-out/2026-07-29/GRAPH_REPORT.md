# Graph Report - feat-44  (2026-07-28)

## Corpus Check
- 238 files · ~114,355 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2395 nodes · 3846 edges · 178 communities (141 shown, 37 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 43 edges (avg confidence: 0.78)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `bfb9c0c4`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Settings Repository & Keys
- Logging Service Core
- Remote Event Source & Auth
- App Root & Providers
- Server DB & Auth Sessions
- Topic Model & App Settings Screen
- Navigation & Author/Events Screens
- Server Build Info & Utils
- App Theme & Spacing
- Debug Tools Screen
- Event Editor Sheet
- Widget Test Fakes
- Test App Bootstrap
- Server Auth Rate Limiting
- Admin User Detail Screen
- Author Auth Provider
- Confetti Overlay
- Admin Screen & OTP Dialog
- Server Data Access Layer
- Analytics Service
- Analytics Concept & Events (PostHog/Wiredash)
- Push Notification Service
- iOS AppDelegate & SceneDelegate
- App Widget Lifecycle
- Topic Admin Screen
- CI/CD Secrets & Xcode Cloud
- TypeScript Build Config
- Event Detail Screen
- Flutter App Project Docs
- App Navigation State
- Usage Tracking Service
- Event Sync Service
- Own Events Provider
- Server Dev Tooling Deps
- Settings State Notifiers
- Secure Storage Service
- Welcome Screen Test
- Event List Tile
- Wiredash Metadata Service
- Calendar & Changelog Screens
- Dashboard Stats Tests
- Events Screen Test
- Server Event CRUD Endpoints
- Author Change Password Screen
- Event Detail Smoke Test
- Date Format Utils
- Author Login Screen
- Author Screen Test
- Repo Structure & Endpoints Doc
- TS Test Config
- NPM Scripts
- Hive Local Storage Service
- Admin Dialogs & Log Viewer
- Server Runtime Dependencies
- Event Field Validation
- Skeleton Loading Animation
- App Entry Point
- Event Model
- Layer Tree Provider
- Layer Model
- App Config
- Error Toast Service
- Event Repository (Local)
- Notification Preference Providers
- Safe Markdown Rendering
- Config/Env Tests
- Feedback Service
- Logging Env Config
- Topic Model
- Topic/Event Admin Screens
- Empty State Widget
- Labeled Chip Widget
- Section Card Widget
- Stat Tile Widget
- Author & Event Domain Rules
- Server Package Scripts
- Remote Event Source Test
- Server Push Notification Payloads
- Remote Event Source Fakes
- Calendar Leaf Widget
- Dashboard Stat Row
- PostHog Rollout Phases
- Test Server Docker Setup
- iOS CI Post-Clone Script
- Claude Plugins & Skills Setup
- Privacy/Terms Jekyll Site
- iOS Manifest
- Author Auth Notifier Test
- Review Skills Trio
- Server Setup Instructions
- Claude Code Review Workflow
- iOS CI Post-Xcodebuild Script
- iOS CI Pre-Xcodebuild Script
- Navigation Logging Observer
- Secure Storage Fake
- API Health Status
- Remote Event Source Exception
- Confetti Painter
- URL Utils
- App Store Connect & Xcode Cloud
- Monorepo Overview
- Secret Leak Incident Process
- App Setup Instructions
- ESLint Config
- Start Test Server Script
- Stop Test Server Script
- Server Bootstrap Script
- Pre-Push Hook
- TS-Jest Dependency
- Jest Type Defs
- Postgres Type Defs
- Supertest Type Defs
- TS ESLint Parser
- Legacy Spring Boot Deployment Plan
- Temp Restore Script
- Launch Screen Assets Doc
- iOS Bundle Identifier
- Navigation Analytics Events
- Local Env Config Example
- Test Endpoint Security Gate
- Stop Test Server Script (dup)
- User Rights (Privacy)
- DSA Provisions
- Pages Privacy Workflow
- Backend API Design Rules
- Backend Reliability Rules
- Backend Security Rules
- Server Logging Format
- Request ID Correlation
- secure_storage_service_test.dart
- App Logs
- CI/CD Prozess (iOS + Server)
- rateLimit.ts
- layer_multi_select_dialog.dart
- AppSettingsScreen
- App
- MaterialPageRoute
- eventUpdates.ts
- CLAUDE.md
- Project
- Project
- Wiredash Feedback-/Support-Tool
- Umsetzungsplan
- Projektleitlinien
- Allgemein
- PULL_REQUEST_TEMPLATE.md
- SettingsRepository
- Architektur
- Analytics-Opt-in als zentrale Freigabe-Schwelle
- geoapify_service.dart
- Datenmodell
- skeleton_card_list.dart
- API
- admin_screen_test.dart
- author_login_screen_test.dart
- location_map_view.dart
- logging_service_test.dart
- testOnly.unit.test.ts
- Auth
- analytics_service_test.dart
- Infrastruktur
- AuthorAuthNotifier
- _ConfettiOverlayState
- AppNavigationLoggingObserver
- _ConfettiPainter
- FakeAdminRemoteEventSource
- FakeSettingsRepository
- eslint

## God Nodes (most connected - your core abstractions)
1. `ensureClient()` - 79 edges
2. `authorAuthProvider` - 56 edges
3. `analyticsServiceProvider` - 26 edges
4. `RemoteEventSource` - 26 edges
5. `connect()` - 24 edges
6. `_AppState` - 15 edges
7. `layerNamesByIdProvider` - 15 edges
8. `createAuthorForTesting()` - 13 edges
9. `refreshAuthorSession()` - 13 edges
10. `compilerOptions` - 13 edges

## Surprising Connections (you probably didn't know these)
- `Express-Backend (server/)` --semantically_similar_to--> `Schnittstelle`  [INFERRED] [semantically similar]
  doc/architecture.md → spec/architecture.md
- `Autorenbereich auf eigene Events begrenzt` --semantically_similar_to--> `Benutzerrollen`  [INFERRED] [semantically similar]
  doc/architecture.md → spec/plan.md
- `docker-compose.yml server service` --semantically_similar_to--> `server/deploy docker-compose server service`  [INFERRED] [semantically similar]
  docker-compose.yml → server/deploy/docker-compose.server.yml
- `Quality Soft Checks Workflow` --semantically_similar_to--> `Verification`  [INFERRED] [semantically similar]
  doc/process/ci_cd_ios_server.md → server/Claude.md
- `Autorenbereich auf eigene Events begrenzt` --semantically_similar_to--> `Autoren-Flow`  [INFERRED] [semantically similar]
  doc/architecture.md → spec/architecture.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **GitHub Agent/Prompt Pairing Pattern** — github_agents_ci_agent, github_agents_development_agent, github_agents_plan_agent, github_prompts_ci_prompt, github_prompts_development_prompt, github_prompts_plan_prompt [INFERRED 0.85]
- **Claude Code Feature Development Lifecycle Skills** — claude_skills_investigate_skill, claude_skills_verify_feature_skill, claude_skills_publish_feature_skill, claude_skills_backend_review_skill, claude_skills_flutter_review_skill [INFERRED 0.75]
- **Repo-wide AI Assistant Instruction Convergence** — claude, app_claude, github_instructions_codex_instructions, github_copilot_instructions [INFERRED 0.75]
- **PostHog Analytics Rollout Plan Phases** — doc_planning_posthog_analytics_plan_phase1_infrastruktur, doc_planning_posthog_analytics_plan_phase2_lifecycle_sessions, doc_planning_posthog_analytics_plan_phase3_navigation_ui, doc_planning_posthog_analytics_plan_phase4_einstellungen, doc_planning_posthog_analytics_plan_phase5_fehler_qualitaet, doc_planning_posthog_analytics_plan_phase6_dashboard [EXTRACTED 1.00]
- **Settings Relaunch Main Categories (NamiApp-Vorbild)** — doc_planning_settings_relaunch_plan_profilbereich, doc_planning_settings_relaunch_plan_app_einstellungen, doc_planning_settings_relaunch_plan_benachrichtigungseinstellungen, doc_planning_settings_relaunch_plan_debug_tools, doc_planning_settings_relaunch_plan_rechtliches_footer [EXTRACTED 1.00]

## Communities (178 total, 37 thin omitted)

### Community 0 - "Settings Repository & Keys"
Cohesion: 0.02
Nodes (89): defaultDeadlineReminderDaysBefore, defaultSubscribedEventsReminderDaysBefore, setAutoSaveEventOnCtaClick, setDeadlineReminderDaysBefore, setDeadlineReminderEnabled, setNewEventPushEnabled, setNotificationsEnabled, setSubscribedEventsReminderDaysBefore (+81 more)

### Community 1 - "Logging Service Core"
Cohesion: 0.03
Nodes (59): _addRecent, allLogsSelectionId, _analytics, _cleanupFuture, _cleanupLogs, clearAllAppLogs, clearAllLogs, _composeMessage (+51 more)

### Community 2 - "Remote Event Source & Auth"
Cohesion: 0.04
Nodes (56): with, class RemoteEventSource extends _RemoteEventSourceBase, Client, remote_event_source/api_health_status.dart, remote_event_source/author_session.dart, remote_event_source/remote_event_source_exception.dart, Uri, addAdminLayer (+48 more)

### Community 3 - "App Root & Providers"
Cohesion: 0.06
Nodes (32): ../../admin/domain/topic_model.dart, layers, LayerTreeNotifier, _loadTree, refresh, _remoteSource, _repository, autosave (+24 more)

### Community 4 - "Server DB & Auth Sessions"
Cohesion: 0.08
Nodes (28): LogSource, _animateToBottom, content, createState, dispose, initialSource, initState, InlineLogsControls (+20 more)

### Community 5 - "Topic Model & App Settings Screen"
Cohesion: 0.13
Nodes (14): _buildCard, _buildNavigationTile, _buildSectionHeader, createState, _firstTapAt, _handleTripleTapInTwoSeconds, _showConfetti, _tapCount (+6 more)

### Community 6 - "Navigation & Author/Events Screens"
Cohesion: 0.07
Nodes (34): build, auth, ownDraftsProvider, ownEventsProvider, read, AuthorScreen, build, _buildStatTiles (+26 more)

### Community 7 - "Server Build Info & Utils"
Cohesion: 0.12
Nodes (25): BuildInfo, getBuildInfo(), normalizeValue(), shortSha(), cleanupExpiredDrafts(), port, start(), BaseLogFields (+17 more)

### Community 8 - "App Theme & Spacing"
Cohesion: 0.05
Nodes (36): AppSpacing, AppTheme, _build, dark, l, light, m, primary (+28 more)

### Community 9 - "Debug Tools Screen"
Cohesion: 0.09
Nodes (22): _logger, refresh, createState, _debugNavTile, DebugToolsScreen, _DebugToolsScreenState, dispose, inline (+14 more)

### Community 10 - "Event Editor Sheet"
Cohesion: 0.05
Nodes (38): _buildTopicDropdown, _cancel, _continue, createState, _cta1LabelController, _cta1UrlController, _cta2LabelController, _cta2UrlController (+30 more)

### Community 11 - "Widget Test Fakes"
Cohesion: 0.06
Nodes (35): _authorId, clearAuthorSession, clearAuthorTokens, createAdminUser, expectEventuallyFound, fetchAdminLayers, fetchAdminUsers, fetchEvents (+27 more)

### Community 12 - "Test App Bootstrap"
Cohesion: 0.08
Nodes (19): app, trustProxyHops, clearAuthorData(), createAuthorForTesting(), close(), clearDrafts(), clearEvents(), addAuthorTopicGrant() (+11 more)

### Community 13 - "Server Auth Rate Limiting"
Cohesion: 0.12
Nodes (18): box, _buildListEntries, compareByStart, createState, currentMonthKey, entries, event, _EventEntry (+10 more)

### Community 14 - "Admin User Detail Screen"
Cohesion: 0.08
Nodes (31): _addAdminLayers, _deleteUser, _editAuthorGrants, _loadContributions, _loadLayerContext, _reloadUser, _removeAdminLayer, _removeLayerGrant (+23 more)

### Community 15 - "Author Auth Provider"
Cohesion: 0.05
Nodes (37): authorId, authorLockTimeout, changePassword, copyWith, expiresAt, _forceRefresh, getValidAccessToken, isAdmin (+29 more)

### Community 16 - "Confetti Overlay"
Cohesion: 0.06
Nodes (30): Alignment, bottomSpawnHeight, build, color, _controller, createState, dispose, duration (+22 more)

### Community 17 - "Admin Screen & OTP Dialog"
Cohesion: 0.17
Nodes (12): admin_user_detail_screen.dart, AdminUserListScreen, _AdminUserListScreenState, build, createState, _error, initState, _loading (+4 more)

### Community 18 - "Server Data Access Layer"
Cohesion: 0.13
Nodes (39): AuthLoginSession, AuthSession, changeAuthorPassword(), ChangePasswordResult, cleanupExpiredSessions(), createAuthor(), createAuthorLoginSession(), deleteAuthorById() (+31 more)

### Community 19 - "Analytics Service"
Cohesion: 0.08
Nodes (24): AnalyticsService, buildPayload, capture, dispose, _distinctId, _distinctIdOrCreate, _distinctIdStorageKey, _ensureDistinctId (+16 more)

### Community 20 - "Analytics Concept & Events (PostHog/Wiredash)"
Cohesion: 0.12
Nodes (20): Analytics-Opt-in als zentrale Freigabe-Schwelle, error_captured Event, App-Lifecycle Events (app_started, session_duration, ...), settings_changed Event, UI-Interaktions-Events (ui_click, menu_opened, dialog_*), App-Einstellungen (Dark Mode, Tracking-Toggle), Benachrichtigungseinstellungen, Debug & Tools Seite (+12 more)

### Community 21 - "Push Notification Service"
Cohesion: 0.08
Nodes (24): AndroidNotificationChannel, _channel, _ensureApnsTokenAvailable, _fetchTopicNamesById, firebaseMessagingBackgroundHandler, _flutterLocalNotificationsPlugin, _handleInitialMessage, initialize (+16 more)

### Community 22 - "iOS AppDelegate & SceneDelegate"
Cohesion: 0.09
Nodes (17): Any, AppDelegate, SceneDelegate, RunnerTests, Bool, Data, Error, Flutter (+9 more)

### Community 23 - "App Widget Lifecycle"
Cohesion: 0.09
Nodes (27): _analytics, _AppState, appThemeModeProvider, build, createState, currentIndexProvider, didChangeAppLifecycleState, dispose (+19 more)

### Community 24 - "Topic Admin Screen"
Cohesion: 0.17
Nodes (11): build, child, children, DebugButtonGroup, DebugSectionCard, icon, isDestructive, label (+3 more)

### Community 25 - "CI/CD Secrets & Xcode Cloud"
Cohesion: 0.22
Nodes (10): Server Deploy Main Workflow, Secret-Quelle: GitHub Actions, docker-compose.yml postgres service, docker-compose.yml server service, server/deploy docker-compose caddy service, server/deploy docker-compose postgres service, server/deploy docker-compose server service, server/deploy docker-compose watchtower service (+2 more)

### Community 26 - "TypeScript Build Config"
Cohesion: 0.10
Nodes (20): dist, node_modules, src, compilerOptions, esModuleInterop, forceConsistentCasingInFileNames, isolatedModules, module (+12 more)

### Community 27 - "Event Detail Screen"
Cohesion: 0.07
Nodes (31): _canCreateUpdate, _canDeleteEvent, _canEditEvent, _confirmAndOpenInMaps, createState, _deleteUpdate, dispose, _editUpdate (+23 more)

### Community 28 - "Flutter App Project Docs"
Cohesion: 0.14
Nodes (11): Flutter analysis_options.yaml, app/pubspec.yaml (dpsg_news_app manifest), flutter_lints dependency, Approach, Constraints, Output Format, Purpose, Approach (+3 more)

### Community 29 - "App Navigation State"
Cohesion: 0.21
Nodes (11): build, createState, _editorKey, _finish, initState, _skip, WelcomeScreen, _WelcomeScreenState (+3 more)

### Community 30 - "Usage Tracking Service"
Cohesion: 0.12
Nodes (16): endSession, flushPendingSession, logger, now, NowProvider, pause, _pausedAt, _persistPauseSnapshot (+8 more)

### Community 31 - "Event Sync Service"
Cohesion: 0.10
Nodes (19): baseUrl, configuredUrl, eventSyncStatusProvider, _lastSyncedAt, logger, _minSyncInterval, ref, remoteEventSourceProvider (+11 more)

### Community 32 - "Own Events Provider"
Cohesion: 0.10
Nodes (39): maybeAutoDisableAuthor(), setAuthorActive(), syncAdminFlag(), addAdminLayer(), addAuthorLayerGrant(), createLayer(), deleteLayer(), DeleteLayerResult (+31 more)

### Community 33 - "Server Dev Tooling Deps"
Cohesion: 0.11
Nodes (19): cross-env, husky, jest, nodemon, devDependencies, cross-env, husky, jest (+11 more)

### Community 34 - "Settings State Notifiers"
Cohesion: 0.14
Nodes (14): StateNotifier, AnalyticsTrackingNotifier, AppLanguageNotifier, AppThemeModeNotifier, AuthorModeNotifier, AutoSaveEventOnCtaClickNotifier, DeadlineReminderDaysBeforeNotifier, DeadlineReminderNotifier (+6 more)

### Community 35 - "Secure Storage Service"
Cohesion: 0.13
Nodes (14): accessExpiresAt, accessToken, _authorAccessExpiresAtKey, _authorAccessTokenKey, _authorRefreshExpiresAtKey, _authorRefreshTokenKey, AuthorTokenBundle, clearAuthorTokens (+6 more)

### Community 36 - "Welcome Screen Test"
Cohesion: 0.12
Nodes (17): main, FakeRemoteEventSource, fetchLayers, hamburgLayerId, main, pump, pumpUntilFound, pumpWelcomeScreen (+9 more)

### Community 37 - "Event List Tile"
Cohesion: 0.12
Nodes (15): build, createdBy, isSaved, layerName, location, onDelete, onEdit, onTap (+7 more)

### Community 38 - "Wiredash Metadata Service"
Cohesion: 0.08
Nodes (19): buildSafeCustomMetadata, WiredashMetadataService, showAdminOtpDialog, build, clipboardCalls, main, openDialog, main (+11 more)

### Community 39 - "Calendar & Changelog Screens"
Cohesion: 0.25
Nodes (7): alt, _BlockedImagePlaceholder, build, data, SafeMarkdownBody, package:flutter_markdown/flutter_markdown.dart, ../utils/url_utils.dart

### Community 40 - "Dashboard Stats Tests"
Cohesion: 0.07
Nodes (23): layers, main, openDialog, layers, main, topics, main, openDialog (+15 more)

### Community 41 - "Events Screen Test"
Cohesion: 0.12
Nodes (15): _events, _FakeRemoteEventSource, fetchEvents, fetchLayers, hamburgLayerId, koelnLayerId, main, _pumpEventsScreen (+7 more)

### Community 42 - "Server Event CRUD Endpoints"
Cohesion: 0.12
Nodes (20): createAuthorEvent(), createEvent(), deleteAllEvents(), deleteAuthorEventById(), deleteEventById(), Event, EventInput, EventRow (+12 more)

### Community 43 - "Author Change Password Screen"
Cohesion: 0.12
Nodes (16): AuthorChangePasswordScreen, _AuthorChangePasswordScreenState, build, _confirmPasswordController, createState, dispose, _formKey, _newPasswordController (+8 more)

### Community 44 - "Event Detail Smoke Test"
Cohesion: 0.15
Nodes (12): _FakeRemoteEventSource, fetchEventUpdates, fetchLayers, fetchTopics, _koelnLayerId, main, _pfadfinderTopicId, _pumpUntilFound (+4 more)

### Community 45 - "Date Format Utils"
Cohesion: 0.15
Nodes (12): dateTime, diff, formatEventDateTime, formatMonthAbbreviation, formatMonthYearHeader, formatRelativeTime, local, now (+4 more)

### Community 46 - "Author Login Screen"
Cohesion: 0.06
Nodes (34): _admins, _adminsError, _adminsRequestId, allLayers, _authors, _authorsError, _authorsRequestId, build (+26 more)

### Community 47 - "Author Screen Test"
Cohesion: 0.06
Nodes (34): main, main, RemoteEventSourceStub, deleteDraft, deleteDraftCallCount, _drafts, _events, _FakeRemoteEventSource (+26 more)

### Community 48 - "Repo Structure & Endpoints Doc"
Cohesion: 0.29
Nodes (7): Flutter-Frontend (app/), Express-Backend (server/), Backend, Datenbank, Frontend, Push, Tech Stack

### Community 49 - "TS Test Config"
Cohesion: 0.17
Nodes (11): ../src/**/*.ts, ./**/*.ts, ../tsconfig.json, compilerOptions, noEmit, rootDir, types, extends (+3 more)

### Community 50 - "NPM Scripts"
Cohesion: 0.17
Nodes (12): scripts, build, dev, lint, lint:fix, prepare, start, test (+4 more)

### Community 51 - "Hive Local Storage Service"
Cohesion: 0.20
Nodes (9): close, eventsBoxName, getEventsBox, _getHivePath, getSettingsBox, HiveService, initialize, settingsBoxName (+1 more)

### Community 52 - "Admin Dialogs & Log Viewer"
Cohesion: 0.06
Nodes (32): build, _buildBody, _buildLayerRow, _buildTree, _buildTreeNode, _confirm, confirmLabel, _controller (+24 more)

### Community 53 - "Server Runtime Dependencies"
Cohesion: 0.18
Nodes (11): dotenv, express, firebase-admin, pg, redis, dependencies, dotenv, express (+3 more)

### Community 54 - "Event Field Validation"
Cohesion: 0.09
Nodes (28): FieldValidation, invalid(), isHttpOrHttpsUrl(), VALID_RESULT, validateEventTextFields(), validateMessageField(), validateOptionalBoolean(), validateOptionalCtaUrl() (+20 more)

### Community 55 - "Skeleton Loading Animation"
Cohesion: 0.13
Nodes (14): build, _clearFieldError, createState, dispose, _fieldError, _flashError, _formKey, initState (+6 more)

### Community 56 - "App Entry Point"
Cohesion: 0.25
Nodes (10): AppSettingsScreen, build, _languageOptions, _themeOptions, appThemeModeProvider, core/services/analytics_service.dart, static const Map, analyticsTrackingProvider (+2 more)

### Community 57 - "Event Model"
Cohesion: 0.15
Nodes (12): description, endDate, EventModel, fromJson, id, layerId, locationAddress, locationLat (+4 more)

### Community 58 - "Layer Tree Provider"
Cohesion: 0.09
Nodes (20): buildContainer, _FakeRemoteEventSource, logoutAuthor, main, refreshAuthorSession, refreshCallCount, refreshErrorStatusCode, refreshResult (+12 more)

### Community 59 - "Layer Model"
Cohesion: 0.08
Nodes (25): admin_otp_dialog.dart, _adminLayerIds, AdminUserDetailScreen, _AdminUserDetailScreenState, _availableLayers, _availableTopics, _buildAuthorGrantsSection, _buildGrantsCard (+17 more)

### Community 60 - "App Config"
Cohesion: 0.17
Nodes (29): AuthorIdentity, getAuthorSession(), getLayerById(), isLayerInAdminScope(), getTopicById(), logRequestError(), logWarn(), getBearerToken() (+21 more)

### Community 61 - "Error Toast Service"
Cohesion: 0.18
Nodes (10): context, describeRemoteError, safeMessage, showErrorToast, showErrorToastForKey, toString, app_navigation_service.dart, ../../features/events/data/remote_event_source.dart (+2 more)

### Community 62 - "Event Repository (Local)"
Cohesion: 0.22
Nodes (8): _box, EventRepository, eventRepositoryProvider, getLocalEvents, saveEvents, Box, core/services/hive_service.dart, package:hive/hive.dart

### Community 63 - "Notification Preference Providers"
Cohesion: 0.39
Nodes (9): build, NotificationSettingsScreen, deadlineReminderDaysBeforeProvider, deadlineReminderProvider, newEventPushEnabledProvider, notificationsEnabledProvider, subscribedEventsReminderDaysBeforeProvider, subscribedEventsReminderProvider (+1 more)

### Community 64 - "Safe Markdown Rendering"
Cohesion: 0.06
Nodes (30): analyticsTrackingKey, apiBaseUrlKey, appLanguageKey, appThemeModeKey, authorAuthTokenKey, authorIdKey, authorIsAdminKey, authorLastBackgroundedAtKey (+22 more)

### Community 65 - "Config/Env Tests"
Cohesion: 0.25
Nodes (7): _env, LoggingEnv, maxDays, maxSizeBytes, maxSizeMb, _positiveInt, static int get

### Community 66 - "Feedback Service"
Cohesion: 0.11
Nodes (16): analytics_service.dart, app.dart, openFeedbackFlow, target, errorContainer, initialize, initializeDateFormatting, main (+8 more)

### Community 67 - "Logging Env Config"
Cohesion: 0.26
Nodes (11): cleanupExpiredDraftsInternal(), computeDraftTimeUntilDeletion(), createAuthorDraft(), deleteAuthorDraftById(), Draft, DraftInput, draftRetentionDays(), DraftRow (+3 more)

### Community 68 - "Topic Model"
Cohesion: 0.07
Nodes (26): build, _buildLayerNode, _buildRow, _buildTree, createState, _didAutoExpandRoot, disableDescendantsOfSelected, emptyLabel (+18 more)

### Community 69 - "Topic/Event Admin Screens"
Cohesion: 0.13
Nodes (15): API-Spezifikation, Autoren-Events, DELETE /api/author/events/:id, DELETE /api/events, Endpunkte, GET /api/author/events, GET /api/events, GET /health (+7 more)

### Community 70 - "Empty State Widget"
Cohesion: 0.25
Nodes (7): actionLabel, build, EmptyState, icon, message, onAction, VoidCallback?

### Community 71 - "Labeled Chip Widget"
Cohesion: 0.12
Nodes (15): build, color, icon, label, LabeledChip, value, build, color (+7 more)

### Community 72 - "Section Card Widget"
Cohesion: 0.25
Nodes (7): background, build, child, SectionCard, title, String?, Widget

### Community 73 - "Stat Tile Widget"
Cohesion: 0.20
Nodes (9): AppConfig, hasGeoapifyConfig, hasPosthogConfig, hasWiredashConfig, normalizeApiBaseUrl, posthogHost, _readDotenv, static bool get (+1 more)

### Community 74 - "Author & Event Domain Rules"
Cohesion: 0.18
Nodes (10): Autorenbereich auf eigene Events begrenzt, Architektur-Spezifikation, Autoren-Flow, Bereiche, Projektorganisation, Ziel, Administrator, Anonymer Nutzer (+2 more)

### Community 75 - "Server Package Scripts"
Cohesion: 0.25
Nodes (7): description, pre-push, husky, hooks, main, name, version

### Community 76 - "Remote Event Source Test"
Cohesion: 0.29
Nodes (6): baseUrl, main, dart:convert, package:http/http.dart, package:http/testing.dart, TimeoutException

### Community 77 - "Server Push Notification Payloads"
Cohesion: 0.12
Nodes (16): build, createState, initialSelectedLayerIds, initialSelectedTopicIds, layerIds, layers, LayerTopicGrantSelection, _LayerTopicGrantTreeDialog (+8 more)

### Community 78 - "Remote Event Source Fakes"
Cohesion: 0.31
Nodes (11): RemoteEventSource, _FakeRemoteEventSource, FakeRemoteEventSource, _AdminUsersApi, _AuthApi, _DraftsApi, _EventsApi, _GrantsApi (+3 more)

### Community 79 - "Calendar Leaf Widget"
Cohesion: 0.33
Nodes (5): build, CalendarLeaf, date, DateTime, ../utils/date_format_utils.dart

### Community 80 - "Dashboard Stat Row"
Cohesion: 0.40
Nodes (4): build, tiles, List, stat_tile.dart

### Community 81 - "PostHog Rollout Phases"
Cohesion: 0.33
Nodes (6): Phase 1 - Infrastruktur vorbereiten, Phase 2 - Lifecycle und Sessions, Phase 3 - Navigation und UI-Interaktionen, Phase 4 - Einstellungen und Konfigurationsaenderungen, Phase 5 - Fehler- und Qualitaetstracking, Phase 6 - Dashboard und PostHog-Setup

### Community 82 - "Test Server Docker Setup"
Cohesion: 0.47
Nodes (6): scripts/start-test-server.sh, Ephemeral Test-Server (docker-compose.test.yml), docker-compose.yml postgres-test service, docker-compose.test.yml postgres service, docker-compose.test.yml server service, Server Unit-/E2E-Testing (jest, supertest)

### Community 83 - "iOS CI Post-Clone Script"
Cohesion: 0.70
Nodes (4): ensure_flutter(), install_cocoapods(), pod_install_with_retry(), ci_post_clone.sh script

### Community 85 - "Privacy/Terms Jekyll Site"
Cohesion: 0.67
Nodes (4): Jekyll _config.yml (theme minima, lang de), DPSG News Rechtliches Landing Page, Privacy Policy Controller (Janneck Lange), Terms & Conditions License/Open Source Clause

### Community 87 - "Author Auth Notifier Test"
Cohesion: 0.13
Nodes (13): Backend changes, Flutter changes, Risks, Summary, Testing, Approach, Constraints, Key Rotation Reminder Rules (+5 more)

### Community 88 - "Review Skills Trio"
Cohesion: 0.15
Nodes (10): API, Architecture, Performance, Reliability, Security, Accessibility, Architecture, Performance (+2 more)

### Community 90 - "Claude Code Review Workflow"
Cohesion: 0.67
Nodes (3): Claude Code Workflow (@claude mention trigger), Claude Code Review Workflow, code-review Claude Code Plugin

### Community 93 - "Navigation Logging Observer"
Cohesion: 0.25
Nodes (6): main, main, main, package:dpsg_news_app/core/config/app_config.dart, package:dpsg_news_app/core/services/logging_env.dart, package:flutter_dotenv/flutter_dotenv.dart

### Community 94 - "Secure Storage Fake"
Cohesion: 0.15
Nodes (12): accessExpiresAt, accessToken, authorId, AuthorLoginSession, AuthorSessionState, isAdmin, layerGrantIds, refreshExpiresAt (+4 more)

### Community 95 - "API Health Status"
Cohesion: 0.40
Nodes (4): ApiHealthStatus, healthy, message, ApiHealthNotifier

### Community 96 - "Remote Event Source Exception"
Cohesion: 0.18
Nodes (10): exception, message, RemoteEventSourceException, serverMessage, stackTrace, statusCode, toString, Exception (+2 more)

### Community 97 - "Confetti Painter"
Cohesion: 0.22
Nodes (11): _LayerFormDialog, _LayerFormDialogState, _NameDialog, _NameDialogState, _NameDialog, _NameDialogState, LayerTopicTree, _LayerTopicTreeState (+3 more)

### Community 101 - "Secret Leak Incident Process"
Cohesion: 0.12
Nodes (32): App, analyticsServiceProvider, notificationServiceProvider, AuthorLoginScreen, _AuthorLoginScreenState, _confirmAndOpenLink, EventDetailScreen, _EventDetailScreenState (+24 more)

### Community 103 - "ESLint Config"
Cohesion: 0.07
Nodes (27): bundesverband, createLayer, createLayerCallCount, createLayerError, deleteLayer, deleteLayerCallCount, deleteLayerError, fetchAdminLayers (+19 more)

### Community 113 - "Legacy Spring Boot Deployment Plan"
Cohesion: 0.15
Nodes (13): 1.000 Nutzer, Autorenbereich, Betriebskosten, DPSG Events App – Konzept, Eventstatus, Kalender, Leitprinzipien, Links (+5 more)

### Community 120 - "Local Env Config Example"
Cohesion: 0.25
Nodes (7): createdAt, fromJson, id, layerId, name, TopicModel, updatedAt

### Community 126 - "Backend API Design Rules"
Cohesion: 0.20
Nodes (9): Quality Soft Checks Workflow, API design, Architecture, Backend, Code quality, Reliability, Security, Verification (+1 more)

### Community 127 - "Backend Reliability Rules"
Cohesion: 0.09
Nodes (22): _berlinLayerId, _FakeRemoteEventSource, fetchAuthorSession, fetchLayers, fetchTopics, grantedLayerIds, grantedTopicIds, _hamburgLayerId (+14 more)

### Community 128 - "Backend Security Rules"
Cohesion: 0.13
Nodes (13): _FakeRemoteEventSource, fetchAdminLayers, fetchEvents, fetchTopics, _hamburgLayerId, _koelnLayerId, main, pumpScreen (+5 more)

### Community 133 - "Server Logging Format"
Cohesion: 0.18
Nodes (11): Eventdetails, Eventliste, Eventmodell, Filter, MVP-Funktionen, Optionale Felder, Pflichtfelder, Push-Inhalt (+3 more)

### Community 134 - "Request ID Correlation"
Cohesion: 0.17
Nodes (12): availableTopics, build, createState, initialSelectedTopicIds, _selected, showTopicMultiSelectDialog, title, _TopicMultiSelectDialog (+4 more)

### Community 135 - "secure_storage_service_test.dart"
Cohesion: 0.14
Nodes (13): SecureStorageService, backingStore, _data, delete, _FakeFlutterSecureStorage, main, read, service (+5 more)

### Community 138 - "rateLimit.ts"
Cohesion: 0.20
Nodes (9): authorCount, fromJson, hasAuthors, id, LayerModel, name, parentId, toJson (+1 more)

### Community 139 - "layer_multi_select_dialog.dart"
Cohesion: 0.15
Nodes (13): build, createState, disableDescendantsOfSelected, initialSelectedIds, LayerMultiSelectDialog, _LayerMultiSelectDialogState, layers, _selected (+5 more)

### Community 140 - "AppSettingsScreen"
Cohesion: 0.15
Nodes (12): ../../admin/presentation/admin_screen.dart, admin_user_list_screen.dart, AdminScreen, _AdminScreenState, build, createState, _openUserList, build (+4 more)

### Community 141 - "App"
Cohesion: 0.22
Nodes (8): .env.example bundled asset, App, Einrichtung, Flavors (iOS Firebase), Konfiguration, Start, Test, Voraussetzungen

### Community 142 - "MaterialPageRoute"
Cohesion: 0.19
Nodes (13): loggingServiceProvider, apnsTokenProvider, _openContribution, _openLayerDetail, _submit, apiHealthProvider, build, build (+5 more)

### Community 143 - "eventUpdates.ts"
Cohesion: 0.33
Nodes (8): createEventUpdate(), deleteEventUpdateById(), EventUpdate, EventUpdateRow, getEventUpdateById(), getEventUpdates(), mapEventUpdateRow(), updateEventUpdateById()

### Community 144 - "CLAUDE.md"
Cohesion: 0.29
Nodes (4): Copilot Instructions for DPSG News APP, Erwartungen, Projektkontext, Wichtige Hinweise

### Community 145 - "Project"
Cohesion: 0.25
Nodes (8): Context compaction, Git, graphify, Planning, Project, Quality, Repository boundaries, Workflow

### Community 146 - "Project"
Cohesion: 0.29
Nodes (7): Context compaction, Git, Planning, Project, Quality, Repository boundaries, Workflow

### Community 147 - "Wiredash Feedback-/Support-Tool"
Cohesion: 0.50
Nodes (4): PostHog Produkt-Analytics, Wiredash Feedback-/Support-Tool, Privacy Policy Third-Party Services (Firebase, Wiredash, Google Play), Terms & Conditions Third-Party Services (Google Play, Firebase, Wiredash)

### Community 149 - "Projektleitlinien"
Cohesion: 0.29
Nodes (7): Arbeitsweise, Architektur, Dokumentation, Flutter und UI, Projektleitlinien, Tests und Validierung, Versionierung und Release

### Community 151 - "PULL_REQUEST_TEMPLATE.md"
Cohesion: 0.33
Nodes (5): Backend changes, Flutter changes, Risks, Summary, Testing

### Community 152 - "SettingsRepository"
Cohesion: 0.70
Nodes (5): SettingsRepository, _AuthorSessionSettings, _LayerTreeCacheSettings, _NotificationSettings, _SettingsRepositoryBase

### Community 154 - "Analytics-Opt-in als zentrale Freigabe-Schwelle"
Cohesion: 0.15
Nodes (11): CalendarScreen, EventListTile, build, ChangelogScreen, _ColoredLogView, DvSelectionScreen, build, ExternalNotificationsPlaceholderScreen (+3 more)

### Community 155 - "geoapify_service.dart"
Cohesion: 0.15
Nodes (12): apiKey, autocompleteAddress, data, formatted, fromJson, GeoapifyAddress, lat, lon (+4 more)

### Community 156 - "Datenmodell"
Cohesion: 0.40
Nodes (5): Author, Datenmodell, DV, Event, Kategorie

### Community 157 - "skeleton_card_list.dart"
Cohesion: 0.18
Nodes (11): Animation, AnimationController, build, _controller, count, createState, dispose, initState (+3 more)

### Community 158 - "API"
Cohesion: 0.50
Nodes (4): API, Auth, Autoren, Öffentlich

### Community 159 - "admin_screen_test.dart"
Cohesion: 0.17
Nodes (11): _adminState, _FakeRemoteEventSource, fetchAdminLayers, fetchAdminUsers, fetchAdminUsersCallCount, fetchAdminUsersError, fetchTopics, main (+3 more)

### Community 164 - "author_login_screen_test.dart"
Cohesion: 0.17
Nodes (11): _FakeRemoteEventSource, lastPassword, lastUsername, loginAuthor, loginCallCount, loginError, loginResult, main (+3 more)

### Community 165 - "location_map_view.dart"
Cohesion: 0.18
Nodes (10): address, build, height, interactive, lat, lng, LocationMapView, package:flutter_map/flutter_map.dart (+2 more)

### Community 166 - "logging_service_test.dart"
Cohesion: 0.29
Nodes (6): LoggingService, container, logger, main, package:dpsg_news_app/core/services/logging_service.dart, ProviderContainer

### Community 167 - "testOnly.unit.test.ts"
Cohesion: 0.29
Nodes (5): testOnlyRouter, clearAuthorData, clearDrafts, clearEvents, createAuthorForTesting

### Community 168 - "Auth"
Cohesion: 0.33
Nodes (6): Auth, GET /api/auth/me, POST /api/auth/change-password, POST /api/auth/login, POST /api/auth/logout, POST /api/auth/refresh

### Community 169 - "analytics_service_test.dart"
Cohesion: 0.40
Nodes (4): main, ThemeModeStub, package:dpsg_news_app/core/services/analytics_service.dart, package:shared_preferences/shared_preferences.dart

### Community 170 - "Infrastruktur"
Cohesion: 0.40
Nodes (5): Deployment, Infrastruktur, Phase 1, Phase 2, Phase 3

### Community 171 - "AuthorAuthNotifier"
Cohesion: 0.67
Nodes (3): AuthorAuthNotifier, AuthorAuthState, TestAuthorAuthNotifier

### Community 172 - "_ConfettiOverlayState"
Cohesion: 0.67
Nodes (3): ConfettiOverlay, _ConfettiOverlayState, SingleTickerProviderStateMixin

## Ambiguous Edges - Review These
- `Tech Stack` → `Express-Backend (server/)`  [AMBIGUOUS]
  spec/plan.md · relation: conceptually_related_to

## Knowledge Gaps
- **1349 isolated node(s):** `.tmp_restore.sh script`, `id`, `targets`, `UserNotifications`, `XCTest` (+1344 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **37 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Tech Stack` and `Express-Backend (server/)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `_ConfettiPainter` connect `_ConfettiPainter` to `Confetti Overlay`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Why does `SettingsRepository` connect `SettingsRepository` to `Settings Repository & Keys`, `App Root & Providers`, `Welcome Screen Test`, `Author Auth Provider`, `Event Sync Service`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **Why does `authorAuthProvider` connect `Admin User Detail Screen` to `Secret Leak Incident Process`, `Navigation & Author/Events Screens`, `Event Detail Screen`, `Author Change Password Screen`, `AppSettingsScreen`, `Author Login Screen`, `Author Auth Provider`, `MaterialPageRoute`, `Admin Screen & OTP Dialog`, `Admin Dialogs & Log Viewer`, `App Widget Lifecycle`, `Layer Model`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **What connects `.tmp_restore.sh script`, `id`, `targets` to the rest of the system?**
  _1349 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Settings Repository & Keys` be split into smaller, more focused modules?**
  _Cohesion score 0.022222222222222223 - nodes in this community are weakly interconnected._
- **Should `Logging Service Core` be split into smaller, more focused modules?**
  _Cohesion score 0.03333333333333333 - nodes in this community are weakly interconnected._