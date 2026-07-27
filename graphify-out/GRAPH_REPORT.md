# Graph Report - feat-99  (2026-07-27)

## Corpus Check
- 198 files · ~96,689 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 2506 nodes · 4104 edges · 164 communities (138 shown, 26 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 67 edges (avg confidence: 0.77)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `39e18e1b`
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
- Project Env/Docs Organization
- src/index.ts
- author_auth_provider_test.dart
- Plan: Umbau der Einstellungen nach NamiApp-Vorbild
- App Logs
- CI/CD Prozess (iOS + Server)
- App
- Vorgehen in kleinen Schritten
- CLAUDE.md
- Project
- Project
- Wiredash Feedback-/Support-Tool
- Umsetzungsplan
- Projektleitlinien
- Allgemein
- getAuthorDrafts
- PULL_REQUEST_TEMPLATE.md
- Architektur
- Analytics-Opt-in als zentrale Freigabe-Schwelle
- server/.github/agents/development.agent.md
- Datenmodell
- API-Spezifikation
- API
- testing.md
- typescript

## God Nodes (most connected - your core abstractions)
1. `ensureClient()` - 78 edges
2. `authorAuthProvider` - 60 edges
3. `ensureClient()` - 51 edges
4. `analyticsServiceProvider` - 26 edges
5. `connect()` - 23 edges
6. `connect()` - 18 edges
7. `Terms & Conditions` - 16 edges
8. `_AppState` - 15 edges
9. `Privacy Policy` - 15 edges
10. `layerNamesByIdProvider` - 14 edges

## Surprising Connections (you probably didn't know these)
- `Development Agent (server)` --semantically_similar_to--> `Workflow`  [INFERRED] [semantically similar]
  server/.github/agents/development.agent.md → readme.md
- `CI/CD` --semantically_similar_to--> `Quality Soft Checks Workflow`  [INFERRED] [semantically similar]
  readme.md → doc/process/ci_cd_ios_server.md
- `Endpunkte` --semantically_similar_to--> `GET /health`  [INFERRED] [semantically similar]
  server/README.md → spec/api.md
- `Event-Datenmodell` --semantically_similar_to--> `Eventmodell`  [INFERRED] [semantically similar]
  server/README.md → spec/plan.md
- `Express-Backend (server/)` --semantically_similar_to--> `Schnittstelle`  [INFERRED] [semantically similar]
  doc/architecture.md → spec/architecture.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **GitHub Agent/Prompt Pairing Pattern** — github_agents_ci_agent, github_agents_development_agent, github_agents_plan_agent, github_prompts_ci_prompt, github_prompts_development_prompt, github_prompts_plan_prompt [INFERRED 0.85]
- **Claude Code Feature Development Lifecycle Skills** — claude_skills_investigate_skill, claude_skills_verify_feature_skill, claude_skills_publish_feature_skill, claude_skills_backend_review_skill, claude_skills_flutter_review_skill [INFERRED 0.75]
- **Repo-wide AI Assistant Instruction Convergence** — claude, app_claude, github_instructions_codex_instructions, github_copilot_instructions [INFERRED 0.75]
- **PostHog Analytics Rollout Plan Phases** — doc_planning_posthog_analytics_plan_phase1_infrastruktur, doc_planning_posthog_analytics_plan_phase2_lifecycle_sessions, doc_planning_posthog_analytics_plan_phase3_navigation_ui, doc_planning_posthog_analytics_plan_phase4_einstellungen, doc_planning_posthog_analytics_plan_phase5_fehler_qualitaet, doc_planning_posthog_analytics_plan_phase6_dashboard [EXTRACTED 1.00]
- **Settings Relaunch Main Categories (NamiApp-Vorbild)** — doc_planning_settings_relaunch_plan_profilbereich, doc_planning_settings_relaunch_plan_app_einstellungen, doc_planning_settings_relaunch_plan_benachrichtigungseinstellungen, doc_planning_settings_relaunch_plan_debug_tools, doc_planning_settings_relaunch_plan_rechtliches_footer [EXTRACTED 1.00]
- **Secrets across Xcode Cloud, GitHub Actions and Linux Host** — doc_app_store_connect_xcode_cloud_xcode_cloud_variablen_fuer_app_env, doc_process_ci_cd_ios_server_github_secrets, doc_process_ci_cd_ios_server_xcode_cloud_vars, doc_security_runbook_secret_quellen_xcode_cloud, doc_security_runbook_secret_quellen_github_actions [INFERRED 0.85]

## Communities (164 total, 26 thin omitted)

### Community 0 - "Settings Repository & Keys"
Cohesion: 0.02
Nodes (104): addEvent, analyticsTrackingKey, apiBaseUrlKey, appLanguageKey, appThemeModeKey, appThemeModeProvider, authorAuthTokenKey, authorIdKey (+96 more)

### Community 1 - "Logging Service Core"
Cohesion: 0.03
Nodes (61): _addRecent, allLogsSelectionId, _analytics, AppNavigationLoggingObserver, _cleanupFuture, _cleanupLogs, clearAllAppLogs, clearAllLogs (+53 more)

### Community 2 - "Remote Event Source & Auth"
Cohesion: 0.03
Nodes (71): accessExpiresAt, accessToken, addAdminLayer, addAuthorLayerGrant, addAuthorTopicGrant, authorId, AuthorSessionState, baseUrl (+63 more)

### Community 3 - "App Root & Providers"
Cohesion: 0.06
Nodes (49): ../../admin/domain/topic_model.dart, analyticsServiceProvider, notificationServiceProvider, _openLayerDetail, build, _submit, _confirmAndOpenLink, _EventDetailScreenState (+41 more)

### Community 4 - "Server DB & Auth Sessions"
Cohesion: 0.26
Nodes (13): accessSessionTtlMinutes(), buildHoursExpiry(), buildTokenExpiry(), cleanupExpiredSessions(), createAuthorLoginSession(), createRefreshTokenValue(), hashToken(), loginAuthor() (+5 more)

### Community 5 - "Topic Model & App Settings Screen"
Cohesion: 0.12
Nodes (16): _buildCard, _buildNavigationTile, _buildSectionHeader, createState, _firstTapAt, _handleTripleTapInTwoSeconds, SettingsScreen, _showConfetti (+8 more)

### Community 6 - "Navigation & Author/Events Screens"
Cohesion: 0.06
Nodes (44): build, auth, ownDraftsProvider, ownEventsProvider, read, token, AuthorScreen, build (+36 more)

### Community 7 - "Server Build Info & Utils"
Cohesion: 0.19
Nodes (17): respondBadRequest(), BaseLogFields, currentHourStartUtc(), emit(), environment(), ErrorLogFields, formatPrettyLine(), HourBucket (+9 more)

### Community 8 - "App Theme & Spacing"
Cohesion: 0.05
Nodes (36): AppSpacing, AppTheme, _build, dark, l, light, m, primary (+28 more)

### Community 9 - "Debug Tools Screen"
Cohesion: 0.05
Nodes (51): loggingServiceProvider, apnsTokenProvider, apiHealthProvider, _animateToBottom, apiHealthProvider, build, child, children (+43 more)

### Community 10 - "Event Editor Sheet"
Cohesion: 0.06
Nodes (34): _buildTopicDropdown, _cancel, _continue, createState, _cta1LabelController, _cta1UrlController, _cta2LabelController, _cta2UrlController (+26 more)

### Community 11 - "Widget Test Fakes"
Cohesion: 0.05
Nodes (39): _authorId, clearAuthorSession, clearAuthorTokens, createAdminUser, expectEventuallyFound, FakeAdminRemoteEventSource, FakeSettingsRepository, fetchAdminUsers (+31 more)

### Community 12 - "Test App Bootstrap"
Cohesion: 0.10
Nodes (19): app, clearAuthorData(), createAuthorForTesting(), clearAuthorData(), clearEvents(), close(), close(), createAuthorForTesting() (+11 more)

### Community 13 - "Server Auth Rate Limiting"
Cohesion: 0.06
Nodes (33): authRateLimiter, authRateLimitMax, authRateLimitWindowMs, createRateLimiter(), getBearerToken(), getViewerSession(), globalRateLimiter, globalRateLimitMax (+25 more)

### Community 14 - "Admin User Detail Screen"
Cohesion: 0.09
Nodes (43): AdminScreen, _AdminScreenState, _createUser, _loadUsers, _addAdminLayers, AdminUserDetailScreen, _AdminUserDetailScreenState, _deleteContribution (+35 more)

### Community 15 - "Author Auth Provider"
Cohesion: 0.05
Nodes (40): AuthorAuthNotifier, AuthorAuthState, authorId, authorLockTimeout, changePassword, copyWith, expiresAt, _forceRefresh (+32 more)

### Community 16 - "Confetti Overlay"
Cohesion: 0.04
Nodes (46): Alignment, Animation, AnimationController, bottomSpawnHeight, build, color, ConfettiOverlay, _ConfettiOverlayState (+38 more)

### Community 17 - "Admin Screen & OTP Dialog"
Cohesion: 0.11
Nodes (18): admin_otp_dialog.dart, admin_user_detail_screen.dart, build, createState, dispose, _error, _formKey, initState (+10 more)

### Community 18 - "Server Data Access Layer"
Cohesion: 0.07
Nodes (56): AuthLoginSession, AuthorIdentity, AuthorRecord, AuthorRow, AuthSession, ChangePasswordResult, clearDrafts(), connect() (+48 more)

### Community 19 - "Analytics Service"
Cohesion: 0.08
Nodes (23): buildPayload, capture, dispose, _distinctId, _distinctIdOrCreate, _distinctIdStorageKey, _ensureDistinctId, initialize (+15 more)

### Community 20 - "Analytics Concept & Events (PostHog/Wiredash)"
Cohesion: 0.15
Nodes (19): App-Einstellungen (Dark Mode, Tracking-Toggle), Benachrichtigungseinstellungen, Changelog, Dark Mode, Debug & Tools Seite, Lokalisierung und Sprache, NamiApp als Design-/Funktions-Referenz, Neue Funktionen im Detail (+11 more)

### Community 21 - "Push Notification Service"
Cohesion: 0.08
Nodes (24): AndroidNotificationChannel, _channel, _ensureApnsTokenAvailable, _fetchTopicNamesById, firebaseMessagingBackgroundHandler, _flutterLocalNotificationsPlugin, _handleInitialMessage, initialize (+16 more)

### Community 22 - "iOS AppDelegate & SceneDelegate"
Cohesion: 0.09
Nodes (17): Any, AppDelegate, SceneDelegate, RunnerTests, Bool, Data, Error, Flutter (+9 more)

### Community 23 - "App Widget Lifecycle"
Cohesion: 0.08
Nodes (26): _analytics, appThemeModeProvider, createState, didChangeAppLifecycleState, dispose, hasSeenWelcomeProvider, _isPaused, _logger (+18 more)

### Community 24 - "Topic Admin Screen"
Cohesion: 0.08
Nodes (23): ../../admin/presentation/admin_screen.dart, _buildTopicList, _confirm, confirmLabel, _controller, createState, dispose, _formKey (+15 more)

### Community 25 - "CI/CD Secrets & Xcode Cloud"
Cohesion: 0.18
Nodes (12): GitHub Secrets, Server Deploy Main Workflow, Secret-Quelle: GitHub Actions, docker-compose.yml postgres service, docker-compose.yml server service, CI/CD, server/deploy docker-compose caddy service, server/deploy docker-compose postgres service (+4 more)

### Community 26 - "TypeScript Build Config"
Cohesion: 0.10
Nodes (20): dist, node_modules, src, compilerOptions, esModuleInterop, forceConsistentCasingInFileNames, isolatedModules, module (+12 more)

### Community 27 - "Event Detail Screen"
Cohesion: 0.07
Nodes (27): _canCreateUpdate, _canDeleteEvent, _canEditEvent, createState, _deleteUpdate, dispose, _editEvent, _editUpdate (+19 more)

### Community 28 - "Flutter App Project Docs"
Cohesion: 0.14
Nodes (11): Flutter analysis_options.yaml, app/pubspec.yaml (dpsg_news_app manifest), flutter_lints dependency, Approach, Constraints, Output Format, Purpose, Approach (+3 more)

### Community 29 - "App Navigation State"
Cohesion: 0.09
Nodes (30): App, _AppState, build, currentIndexProvider, appNavigatorKeyProvider, eventsProvider, build, createState (+22 more)

### Community 30 - "Usage Tracking Service"
Cohesion: 0.11
Nodes (17): endSession, flushPendingSession, logger, now, NowProvider, pause, _pausedAt, _persistPauseSnapshot (+9 more)

### Community 31 - "Event Sync Service"
Cohesion: 0.10
Nodes (20): initState, baseUrl, configuredUrl, eventSyncStatusProvider, _lastSyncedAt, logger, _minSyncInterval, ref (+12 more)

### Community 32 - "Own Events Provider"
Cohesion: 0.05
Nodes (39): _admins, _adminsError, _adminsRequestId, allLayers, _authors, _authorsError, _authorsRequestId, build (+31 more)

### Community 33 - "Server Dev Tooling Deps"
Cohesion: 0.11
Nodes (19): cross-env, eslint, husky, jest, nodemon, devDependencies, cross-env, eslint (+11 more)

### Community 34 - "Settings State Notifiers"
Cohesion: 0.11
Nodes (19): ApiHealthStatus, ApiHealthNotifier, LayerTreeNotifier, AnalyticsTrackingNotifier, AppLanguageNotifier, AppThemeModeNotifier, AuthorModeNotifier, AutoSaveEventOnCtaClickNotifier (+11 more)

### Community 35 - "Secure Storage Service"
Cohesion: 0.11
Nodes (18): accessExpiresAt, accessToken, _authorAccessExpiresAtKey, _authorAccessTokenKey, _authorRefreshExpiresAtKey, _authorRefreshTokenKey, AuthorTokenBundle, clearAuthorTokens (+10 more)

### Community 36 - "Welcome Screen Test"
Cohesion: 0.13
Nodes (15): SettingsRepository, fetchLayers, hamburgLayerId, main, pump, pumpUntilFound, pumpWelcomeScreen, repository (+7 more)

### Community 37 - "Event List Tile"
Cohesion: 0.12
Nodes (15): build, createdBy, isSaved, layerName, location, onDelete, onEdit, onTap (+7 more)

### Community 38 - "Wiredash Metadata Service"
Cohesion: 0.07
Nodes (21): buildSafeCustomMetadata, WiredashMetadataService, showAdminOtpDialog, build, CalendarScreen, build, ChangelogScreen, build (+13 more)

### Community 39 - "Calendar & Changelog Screens"
Cohesion: 0.10
Nodes (21): _ColoredLogView, ChangelogScreen, _ColoredLogView, _DebugActionButton, _DebugButtonGroup, _DebugSectionCard, ExternalNotificationsPlaceholderScreen, DvSelectionScreen (+13 more)

### Community 40 - "Dashboard Stats Tests"
Cohesion: 0.09
Nodes (16): main, main, main, main, main, main, main, main (+8 more)

### Community 41 - "Events Screen Test"
Cohesion: 0.13
Nodes (14): _events, fetchEvents, fetchLayers, hamburgLayerId, koelnLayerId, main, _pumpEventsScreen, remote (+6 more)

### Community 42 - "Server Event CRUD Endpoints"
Cohesion: 0.20
Nodes (8): deleteAllEvents(), deleteEventById(), SEED_DVS, SeedLayer, mockClientConstructor, mockConnect, mockEnd, mockQuery

### Community 43 - "Author Change Password Screen"
Cohesion: 0.07
Nodes (27): build, _confirmPasswordController, createState, dispose, _formKey, _newPasswordController, _obscureConfirmPassword, _obscureNewPassword (+19 more)

### Community 44 - "Event Detail Smoke Test"
Cohesion: 0.13
Nodes (13): fetchEventUpdates, fetchLayers, fetchTopics, _koelnLayerId, main, _pfadfinderTopicId, _pumpUntilFound, _sampleEvent (+5 more)

### Community 45 - "Date Format Utils"
Cohesion: 0.15
Nodes (12): dateTime, diff, formatEventDateTime, formatMonthAbbreviation, formatMonthYearHeader, formatRelativeTime, local, now (+4 more)

### Community 46 - "Author Login Screen"
Cohesion: 0.14
Nodes (30): createAuthorEvent(), createEvent(), deleteAllEvents(), deleteAuthorEventById(), deleteEventById(), Event, EventInput, EventRow (+22 more)

### Community 47 - "Author Screen Test"
Cohesion: 0.18
Nodes (9): EventListTile, main, main, wrap, package:dpsg_news_app/core/theme/app_theme.dart, package:dpsg_news_app/features/author/data/author_auth_provider.dart, package:dpsg_news_app/features/author/data/own_events_provider.dart, package:dpsg_news_app/features/author/presentation/author_screen.dart (+1 more)

### Community 48 - "Repo Structure & Endpoints Doc"
Cohesion: 0.18
Nodes (11): Flutter-Frontend (app/), Express-Backend (server/), Ziel, Backend, Datenbank, DPSG Events App – Konzept, Frontend, Leitprinzipien (+3 more)

### Community 49 - "TS Test Config"
Cohesion: 0.17
Nodes (11): ../src/**/*.ts, ./**/*.ts, ../tsconfig.json, compilerOptions, noEmit, rootDir, types, extends (+3 more)

### Community 50 - "NPM Scripts"
Cohesion: 0.17
Nodes (12): scripts, build, dev, lint, lint:fix, prepare, start, test (+4 more)

### Community 51 - "Hive Local Storage Service"
Cohesion: 0.18
Nodes (10): close, eventsBoxName, getEventsBox, _getHivePath, getSettingsBox, HiveService, initialize, settingsBoxName (+2 more)

### Community 52 - "Admin Dialogs & Log Viewer"
Cohesion: 0.17
Nodes (15): _CreateUserDialog, _CreateUserDialogState, _LayerFormDialog, _LayerFormDialogState, _NameDialog, _NameDialogState, _NameDialog, _NameDialogState (+7 more)

### Community 53 - "Server Runtime Dependencies"
Cohesion: 0.18
Nodes (11): dotenv, express, firebase-admin, pg, redis, dependencies, dotenv, express (+3 more)

### Community 54 - "Event Field Validation"
Cohesion: 0.36
Nodes (9): FieldValidation, invalid(), isHttpOrHttpsUrl(), VALID_RESULT, validateEventTextFields(), validateMessageField(), validateOptionalCtaUrl(), validateOptionalText() (+1 more)

### Community 55 - "Skeleton Loading Animation"
Cohesion: 0.06
Nodes (32): 10. Children, 11. Security, 12. Data Breach Notification, 13. Changes to this Policy, 14. Contact, 1. Controller, 2. Scope of this Policy, 3. Data We Process (+24 more)

### Community 56 - "App Entry Point"
Cohesion: 0.18
Nodes (10): app.dart, errorContainer, initialize, initializeDateFormatting, main, startupAnalytics, core/services/notification_service.dart, package:firebase_core/firebase_core.dart (+2 more)

### Community 57 - "Event Model"
Cohesion: 0.20
Nodes (9): description, endDate, EventModel, fromJson, id, layerId, location, startDate (+1 more)

### Community 58 - "Layer Tree Provider"
Cohesion: 0.06
Nodes (32): build, _buildBody, _buildLayerRow, _buildTree, _buildTreeNode, _confirm, confirmLabel, _controller (+24 more)

### Community 59 - "Layer Model"
Cohesion: 0.20
Nodes (9): fromJson, id, LayerModel, name, parentId, toJson, type, url (+1 more)

### Community 60 - "App Config"
Cohesion: 0.22
Nodes (8): AppConfig, hasPosthogConfig, hasWiredashConfig, normalizeApiBaseUrl, posthogHost, _readDotenv, dart:io, static bool get

### Community 61 - "Error Toast Service"
Cohesion: 0.18
Nodes (10): context, describeRemoteError, safeMessage, showErrorToast, showErrorToastForKey, toString, app_navigation_service.dart, ../../features/events/data/remote_event_source.dart (+2 more)

### Community 62 - "Event Repository (Local)"
Cohesion: 0.22
Nodes (8): _box, EventRepository, eventRepositoryProvider, getLocalEvents, saveEvents, Box, core/services/hive_service.dart, package:hive/hive.dart

### Community 63 - "Notification Preference Providers"
Cohesion: 0.36
Nodes (9): deadlineReminderDaysBeforeProvider, deadlineReminderProvider, newEventPushEnabledProvider, notificationsEnabledProvider, subscribedEventsReminderDaysBeforeProvider, subscribedEventsReminderProvider, weeklyPushSummaryProvider, build (+1 more)

### Community 64 - "Safe Markdown Rendering"
Cohesion: 0.25
Nodes (7): alt, _BlockedImagePlaceholder, build, data, SafeMarkdownBody, package:flutter_markdown/flutter_markdown.dart, ../utils/url_utils.dart

### Community 65 - "Config/Env Tests"
Cohesion: 0.18
Nodes (23): AuthorIdentity, getAuthorSession(), listAuthors(), getLayerById(), isLayerInAdminScope(), getTopics(), logRequestError(), getBearerToken() (+15 more)

### Community 66 - "Feedback Service"
Cohesion: 0.25
Nodes (7): analytics_service.dart, openFeedbackFlow, target, ../config/app_config.dart, dart:async, package:wiredash/wiredash.dart, required String screen,
  String

### Community 67 - "Logging Env Config"
Cohesion: 0.25
Nodes (7): _env, LoggingEnv, maxDays, maxSizeBytes, maxSizeMb, _positiveInt, static int get

### Community 68 - "Topic Model"
Cohesion: 0.25
Nodes (7): createdAt, fromJson, id, layerId, name, TopicModel, updatedAt

### Community 69 - "Topic/Event Admin Screens"
Cohesion: 0.07
Nodes (30): LogSource, _animateToBottom, content, createState, dispose, initialSource, initState, InlineLogsControls (+22 more)

### Community 70 - "Empty State Widget"
Cohesion: 0.07
Nodes (29): actionLabel, build, EmptyState, icon, message, onAction, build, color (+21 more)

### Community 71 - "Labeled Chip Widget"
Cohesion: 0.07
Nodes (27): _adminLayerIds, _availableLayers, _availableTopics, _buildAuthorGrantsSection, _buildGrantsCard, _buildGrantSection, _confirm, _contributions (+19 more)

### Community 72 - "Section Card Widget"
Cohesion: 0.07
Nodes (26): build, _buildLayerNode, _buildRow, _buildTree, createState, _didAutoExpandRoot, disableDescendantsOfSelected, emptyLabel (+18 more)

### Community 73 - "Stat Tile Widget"
Cohesion: 0.17
Nodes (22): AuthLoginSession, AuthSession, ChangePasswordResult, createAuthorLoginSession(), deleteAuthorById(), logoutAuthor(), normalizeAuthor(), refreshAuthorSession() (+14 more)

### Community 74 - "Author & Event Domain Rules"
Cohesion: 0.18
Nodes (11): Autorenbereich auf eigene Events begrenzt, Autoren-Session-Handling, Architektur-Spezifikation, Autoren-Flow, Bereiche, Projektorganisation, Ziel, Administrator (+3 more)

### Community 75 - "Server Package Scripts"
Cohesion: 0.25
Nodes (7): description, pre-push, husky, hooks, main, name, version

### Community 76 - "Remote Event Source Test"
Cohesion: 0.29
Nodes (6): baseUrl, main, dart:convert, package:dpsg_news_app/features/events/data/remote_event_source.dart, package:http/http.dart, package:http/testing.dart

### Community 77 - "Server Push Notification Payloads"
Cohesion: 0.19
Nodes (23): changeAuthorPassword(), cleanupExpiredSessions(), createAuthor(), getAuthorById(), loginAuthor(), mapAuthorRecord(), resetAuthorPassword(), revokeAuthorSessions() (+15 more)

### Community 78 - "Remote Event Source Fakes"
Cohesion: 0.29
Nodes (7): RemoteEventSource, _FakeRemoteEventSource, RemoteEventSourceStub, _FakeRemoteEventSource, _FakeRemoteEventSource, FakeRemoteEventSource, FakeRemoteEventSource

### Community 79 - "Calendar Leaf Widget"
Cohesion: 0.33
Nodes (5): build, CalendarLeaf, date, DateTime, ../utils/date_format_utils.dart

### Community 80 - "Dashboard Stat Row"
Cohesion: 0.33
Nodes (5): build, DashboardStatRow, tiles, List, stat_tile.dart

### Community 81 - "PostHog Rollout Phases"
Cohesion: 0.33
Nodes (6): Phase 1 - Infrastruktur vorbereiten, Phase 2 - Lifecycle und Sessions, Phase 3 - Navigation und UI-Interaktionen, Phase 4 - Einstellungen und Konfigurationsaenderungen, Phase 5 - Fehler- und Qualitaetstracking, Phase 6 - Dashboard und PostHog-Setup

### Community 82 - "Test Server Docker Setup"
Cohesion: 0.47
Nodes (6): scripts/start-test-server.sh, Ephemeral Test-Server (docker-compose.test.yml), docker-compose.yml postgres-test service, docker-compose.test.yml postgres service, docker-compose.test.yml server service, Server Unit-/E2E-Testing (jest, supertest)

### Community 83 - "iOS CI Post-Clone Script"
Cohesion: 0.70
Nodes (4): ensure_flutter(), install_cocoapods(), pod_install_with_retry(), ci_post_clone.sh script

### Community 84 - "Claude Plugins & Skills Setup"
Cohesion: 0.18
Nodes (11): 0. Worktree anlegen, 1. Neues Feature starten, 2. Aufgabe analysieren, 3. Implementierung, 4. Feature überprüfen, 5. Optionales Review, 6. Pull Request veröffentlichen, 7. Worktree aufräumen (+3 more)

### Community 85 - "Privacy/Terms Jekyll Site"
Cohesion: 0.67
Nodes (4): Jekyll _config.yml (theme minima, lang de), DPSG News Rechtliches Landing Page, Privacy Policy Controller (Janneck Lange), Terms & Conditions License/Open Source Clause

### Community 87 - "Author Auth Notifier Test"
Cohesion: 0.09
Nodes (22): box, _buildListEntries, compareByStart, createState, currentMonthKey, entries, event, _EventEntry (+14 more)

### Community 88 - "Review Skills Trio"
Cohesion: 0.15
Nodes (10): API, Architecture, Performance, Reliability, Security, Accessibility, Architecture, Performance (+2 more)

### Community 89 - "Server Setup Instructions"
Cohesion: 0.17
Nodes (12): Server starten (npm install / npm start), Server-Setup (npm install/start), Build-Stand in Logs, Deployment (Linux + Docker), Docker Compose, Firebase Prod Key auf Server tauschen, Installation, Logging-Format (+4 more)

### Community 90 - "Claude Code Review Workflow"
Cohesion: 0.67
Nodes (3): Claude Code Workflow (@claude mention trigger), Claude Code Review Workflow, code-review Claude Code Plugin

### Community 93 - "Navigation Logging Observer"
Cohesion: 0.13
Nodes (21): maybeAutoDisableAuthor(), syncAdminFlag(), addAdminLayer(), createLayer(), deleteLayer(), DeleteLayerResult, getAdminLayerIds(), getAuthorLayerGrantIds() (+13 more)

### Community 94 - "Secure Storage Fake"
Cohesion: 0.11
Nodes (14): authRateLimiter, authRateLimitMax, authRateLimitWindowMs, createRateLimiter(), globalRateLimiter, globalRateLimitMax, globalRateLimitWindowMs, RateLimiterOptions (+6 more)

### Community 95 - "API Health Status"
Cohesion: 0.13
Nodes (19): Endpunkte, Auth, Autoren-Events, DELETE /api/author/events/:id, DELETE /api/events, Endpunkte, GET /api/auth/me, GET /api/author/events (+11 more)

### Community 97 - "Confetti Painter"
Cohesion: 0.12
Nodes (16): build, createState, initialSelectedLayerIds, initialSelectedTopicIds, layerIds, layers, LayerTopicGrantSelection, _LayerTopicGrantTreeDialog (+8 more)

### Community 99 - "App Store Connect & Xcode Cloud"
Cohesion: 0.18
Nodes (11): App Store Connect, App Store Connect und Xcode Cloud Vorbereitung, ios/ci_scripts (post_clone, pre_xcodebuild, post_xcodebuild), Hinweise, Nächste Schritte in App Store Connect, Wichtige Werte, Xcode Cloud, Xcode-Cloud-Variablen fuer app/.env (+3 more)

### Community 100 - "Monorepo Overview"
Cohesion: 0.18
Nodes (10): Monorepo Systemuebersicht, App, DPSG News APP, Eigene Claude Skills, Installierte Claude Plugins, Konfiguration, Server, Setup (+2 more)

### Community 101 - "Secret Leak Incident Process"
Cohesion: 0.18
Nodes (11): Geltungsbereich, GitHub Actions (Server Build/Deploy), Incident-Ablauf bei Secret-Leak, Linux Host (Server Runtime), Review-Checkliste je Release, Rotation, Runtime-Prinzipien, Secret-Quellen (+3 more)

### Community 103 - "ESLint Config"
Cohesion: 0.13
Nodes (13): Backend changes, Flutter changes, Risks, Summary, Testing, Approach, Constraints, Key Rotation Reminder Rules (+5 more)

### Community 113 - "Legacy Spring Boot Deployment Plan"
Cohesion: 0.13
Nodes (15): 1.000 Nutzer, Autorenbereich, Betriebskosten, Deployment, Eventstatus, Infrastruktur, Kalender, Links (+7 more)

### Community 120 - "Local Env Config Example"
Cohesion: 0.33
Nodes (5): App starten, Lokale Konfiguration, Server starten, Setup, Voraussetzungen

### Community 126 - "Backend API Design Rules"
Cohesion: 0.20
Nodes (9): Quality Soft Checks Workflow, API design, Architecture, Backend, Code quality, Reliability, Security, Verification (+1 more)

### Community 127 - "Backend Reliability Rules"
Cohesion: 0.15
Nodes (13): build, createState, disableDescendantsOfSelected, initialSelectedIds, LayerMultiSelectDialog, _LayerMultiSelectDialogState, layers, _selected (+5 more)

### Community 128 - "Backend Security Rules"
Cohesion: 0.17
Nodes (12): availableTopics, build, createState, initialSelectedTopicIds, _selected, showTopicMultiSelectDialog, title, _TopicMultiSelectDialog (+4 more)

### Community 133 - "Server Logging Format"
Cohesion: 0.15
Nodes (12): 1. App-Lifecycle, 2. Navigation und Screens, 3. Interaktionen, 4. Einstellungen und Präferenzen, 5. Fehler und Ausnahmen, Aktueller Stand, Empfehlung für die Implementierung, Metriken und Events (+4 more)

### Community 134 - "Request ID Correlation"
Cohesion: 0.26
Nodes (12): cleanupExpiredDrafts(), cleanupExpiredDraftsInternal(), computeDraftTimeUntilDeletion(), createAuthorDraft(), deleteAuthorDraftById(), Draft, DraftInput, draftRetentionDays() (+4 more)

### Community 135 - "Project Env/Docs Organization"
Cohesion: 0.17
Nodes (12): Event-Datenmodell, Eventdetails, Eventliste, Eventmodell, Filter, MVP-Funktionen, Optionale Felder, Pflichtfelder (+4 more)

### Community 136 - "src/index.ts"
Cohesion: 0.30
Nodes (9): BuildInfo, getBuildInfo(), normalizeValue(), shortSha(), cleanupExpiredDrafts(), port, start(), logError() (+1 more)

### Community 137 - "author_auth_provider_test.dart"
Cohesion: 0.18
Nodes (10): AuthorLoginSession, buildContainer, logoutAuthor, main, refreshAuthorSession, refreshCallCount, refreshErrorStatusCode, refreshResult (+2 more)

### Community 138 - "Plan: Umbau der Einstellungen nach NamiApp-Vorbild"
Cohesion: 0.18
Nodes (10): Aktueller Stand in der Ziel-App, Befund nach abgebrochenem Durchgang, Entscheide für die erste Version, Geplante Struktur, Nächster Schritt, Offene Fragen, Plan: Umbau der Einstellungen nach NamiApp-Vorbild, Umsetzungsempfehlung (+2 more)

### Community 139 - "App Logs"
Cohesion: 0.20
Nodes (11): Akzeptanzkriterien, App Logs, Datenschutz und Robustheit, Debug & Tools Anforderungen fuer Logs, Logging-Scope (neu), LoggingService, Nami-Referenz, die uebernommen wird, Speicher- und Loeschstrategie (aus Nami uebernehmen) (+3 more)

### Community 140 - "CI/CD Prozess (iOS + Server)"
Cohesion: 0.18
Nodes (10): 1) Quality Soft Checks, 2) Server Deploy Main, Betriebsmodus, CI/CD Prozess (iOS + Server), iOS Xcode Cloud Variablen, Linux Host Struktur, Workflows, Zielbild (+2 more)

### Community 141 - "App"
Cohesion: 0.22
Nodes (8): .env.example bundled asset, App, Einrichtung, Flavors (iOS Firebase), Konfiguration, Start, Test, Voraussetzungen

### Community 142 - "Vorgehen in kleinen Schritten"
Cohesion: 0.22
Nodes (9): Phase 1 – Struktur vorbereiten, Phase 2 – Profilbereich und Einstieg, Phase 3 – App-Einstellungen, Phase 4 – Benachrichtigungseinstellungen, Phase 5 – Debug & Tools, Phase-5 Umsetzungsstrategie (NamiApp-Paritaet), Phase 6 – Rechtliches und Footer, Textvorschläge für Benachrichtigungsseite (+1 more)

### Community 143 - "CLAUDE.md"
Cohesion: 0.29
Nodes (4): Copilot Instructions for DPSG News APP, Erwartungen, Projektkontext, Wichtige Hinweise

### Community 144 - "Project"
Cohesion: 0.25
Nodes (8): Context compaction, Git, graphify, Planning, Project, Quality, Repository boundaries, Workflow

### Community 145 - "Project"
Cohesion: 0.29
Nodes (7): Context compaction, Git, Planning, Project, Quality, Repository boundaries, Workflow

### Community 146 - "Wiredash Feedback-/Support-Tool"
Cohesion: 0.29
Nodes (7): Grundsatzentscheidungen, PostHog Produkt-Analytics, Wiredash Feedback-/Support-Tool, Wiredash, Wiredash-Plan (Einbau + Anbindung), Privacy Policy Third-Party Services (Firebase, Wiredash, Google Play), Terms & Conditions Third-Party Services (Google Play, Firebase, Wiredash)

### Community 147 - "Umsetzungsplan"
Cohesion: 0.29
Nodes (7): Phase 1 – Infrastruktur vorbereiten, Phase 2 – Lifecycle und Sessions, Phase 3 – Navigation und UI-Interaktionen, Phase 4 – Einstellungen und Konfigurationsänderungen, Phase 5 – Fehler- und Qualitätstracking, Phase 6 – Dashboard und PostHog-Setup, Umsetzungsplan

### Community 148 - "Projektleitlinien"
Cohesion: 0.29
Nodes (7): Arbeitsweise, Architektur, Dokumentation, Flutter und UI, Projektleitlinien, Tests und Validierung, Versionierung und Release

### Community 149 - "Allgemein"
Cohesion: 0.29
Nodes (7): Allgemein, `/clear`, `/compact`, `/context`, `/doctor`, `/resume`, `/status`

### Community 150 - "getAuthorDrafts"
Cohesion: 0.29
Nodes (7): cleanupExpiredDraftsInternal(), computeDraftTimeUntilDeletion(), createAuthorDraft(), draftRetentionDays(), getAuthorDrafts(), mapDraftRow(), updateAuthorDraftById()

### Community 151 - "PULL_REQUEST_TEMPLATE.md"
Cohesion: 0.33
Nodes (5): Backend changes, Flutter changes, Risks, Summary, Testing

### Community 152 - "Architektur"
Cohesion: 0.40
Nodes (4): Architektur, Systemübersicht, Trennung, Zukunft

### Community 153 - "Analytics-Opt-in als zentrale Freigabe-Schwelle"
Cohesion: 0.40
Nodes (5): Analytics-Opt-in als zentrale Freigabe-Schwelle, error_captured Event, App-Lifecycle Events (app_started, session_duration, ...), settings_changed Event, UI-Interaktions-Events (ui_click, menu_opened, dialog_*)

### Community 154 - "server/.github/agents/development.agent.md"
Cohesion: 0.40
Nodes (4): Approach, Constraints, Output Format, Purpose

### Community 155 - "Datenmodell"
Cohesion: 0.40
Nodes (5): Author, Datenmodell, DV, Event, Kategorie

### Community 156 - "API-Spezifikation"
Cohesion: 0.50
Nodes (3): API-Spezifikation, Hinweise, Ziel

### Community 157 - "API"
Cohesion: 0.50
Nodes (4): API, Auth, Autoren, Öffentlich

## Ambiguous Edges - Review These
- `Tech Stack` → `Express-Backend (server/)`  [AMBIGUOUS]
  spec/plan.md · relation: conceptually_related_to

## Knowledge Gaps
- **1362 isolated node(s):** `.tmp_restore.sh script`, `id`, `targets`, `UserNotifications`, `XCTest` (+1357 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **26 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Tech Stack` and `Express-Backend (server/)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `SettingsRepository` connect `Welcome Screen Test` to `Settings Repository & Keys`, `Author Auth Provider`, `Navigation & Author/Events Screens`, `Event Sync Service`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `LoggingService` connect `App Widget Lifecycle` to `Logging Service Core`, `Remote Event Source & Auth`, `Debug Tools Screen`, `Usage Tracking Service`, `Event Sync Service`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **What connects `.tmp_restore.sh script`, `id`, `targets` to the rest of the system?**
  _1362 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Settings Repository & Keys` be split into smaller, more focused modules?**
  _Cohesion score 0.01904761904761905 - nodes in this community are weakly interconnected._
- **Should `Logging Service Core` be split into smaller, more focused modules?**
  _Cohesion score 0.03225806451612903 - nodes in this community are weakly interconnected._
- **Should `Remote Event Source & Auth` be split into smaller, more focused modules?**
  _Cohesion score 0.027777777777777776 - nodes in this community are weakly interconnected._