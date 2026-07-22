# Graph Report - .  (2026-07-22)

## Corpus Check
- 198 files · ~83,550 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1717 nodes · 2581 edges · 136 communities (96 shown, 40 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 59 edges (avg confidence: 0.81)
- Token cost: 195,639 input · 0 output

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

## God Nodes (most connected - your core abstractions)
1. `ensureClient()` - 51 edges
2. `authorAuthProvider` - 36 edges
3. `analyticsServiceProvider` - 25 edges
4. `connect()` - 18 edges
5. `_AppState` - 15 edges
6. `layerNamesByIdProvider` - 14 edges
7. `compilerOptions` - 13 edges
8. `_EventsScreenState` - 12 edges
9. `scripts` - 12 edges
10. `refreshAuthorSession()` - 12 edges

## Surprising Connections (you probably didn't know these)
- `Lokalisierung und Sprache` --semantically_similar_to--> `Einstellungen (Profilbereich, Hauptkategorien)`  [INFERRED] [semantically similar]
  doc/planning/settings_relaunch_plan.md → spec/plan.md
- `docker-compose.yml server service` --semantically_similar_to--> `server/deploy docker-compose server service`  [INFERRED] [semantically similar]
  docker-compose.yml → server/deploy/docker-compose.server.yml
- `investigate Skill` --semantically_similar_to--> `Plan Agent`  [INFERRED] [semantically similar]
  .claude/skills/investigate/SKILL.md → .github/agents/plan.agent.md
- `publish-feature Skill` --semantically_similar_to--> `CI Agent`  [INFERRED] [semantically similar]
  .claude/skills/publish-feature/SKILL.md → .github/agents/ci.agent.md
- `Copilot Instructions for DPSG News APP` --semantically_similar_to--> `Root CLAUDE.md Project Instructions`  [INFERRED] [semantically similar]
  .github/copilot-instructions.md → CLAUDE.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **GitHub Agent/Prompt Pairing Pattern** — github_agents_ci_agent, github_agents_development_agent, github_agents_plan_agent, github_prompts_ci_prompt, github_prompts_development_prompt, github_prompts_plan_prompt [INFERRED 0.85]
- **Claude Code Feature Development Lifecycle Skills** — claude_skills_investigate_skill, claude_skills_verify_feature_skill, claude_skills_publish_feature_skill, claude_skills_backend_review_skill, claude_skills_flutter_review_skill [INFERRED 0.75]
- **Repo-wide AI Assistant Instruction Convergence** — claude, app_claude, github_instructions_codex_instructions, github_copilot_instructions [INFERRED 0.75]
- **PostHog Analytics Rollout Plan Phases** — doc_planning_posthog_analytics_plan_phase1_infrastruktur, doc_planning_posthog_analytics_plan_phase2_lifecycle_sessions, doc_planning_posthog_analytics_plan_phase3_navigation_ui, doc_planning_posthog_analytics_plan_phase4_einstellungen, doc_planning_posthog_analytics_plan_phase5_fehler_qualitaet, doc_planning_posthog_analytics_plan_phase6_dashboard [EXTRACTED 1.00]
- **Settings Relaunch Main Categories (NamiApp-Vorbild)** — doc_planning_settings_relaunch_plan_profilbereich, doc_planning_settings_relaunch_plan_app_einstellungen, doc_planning_settings_relaunch_plan_benachrichtigungseinstellungen, doc_planning_settings_relaunch_plan_debug_tools, doc_planning_settings_relaunch_plan_rechtliches_footer [EXTRACTED 1.00]
- **Secrets across Xcode Cloud, GitHub Actions and Linux Host** — doc_app_store_connect_xcode_cloud_env_vars, doc_process_ci_cd_ios_server_github_secrets, doc_process_ci_cd_ios_server_xcode_cloud_vars, doc_security_runbook_secret_quellen_xcode_cloud, doc_security_runbook_secret_quellen_github_actions [INFERRED 0.85]

## Communities (136 total, 40 thin omitted)

### Community 0 - "Settings Repository & Keys"
Cohesion: 0.02
Nodes (98): addEvent, analyticsTrackingKey, apiBaseUrlKey, appLanguageKey, appThemeModeKey, appThemeModeProvider, authorAuthTokenKey, authorIdKey (+90 more)

### Community 1 - "Logging Service Core"
Cohesion: 0.03
Nodes (59): _addRecent, allLogsSelectionId, _analytics, _cleanupFuture, _cleanupLogs, clearAllAppLogs, clearAllLogs, _composeMessage (+51 more)

### Community 2 - "Remote Event Source & Auth"
Cohesion: 0.04
Nodes (56): accessExpiresAt, accessToken, authorId, AuthorLoginSession, AuthorSessionState, baseUrl, changeAuthorPassword, checkHealth (+48 more)

### Community 3 - "App Root & Providers"
Cohesion: 0.09
Nodes (45): App, initState, analyticsServiceProvider, loggingServiceProvider, apnsTokenProvider, notificationServiceProvider, syncServiceProvider, AuthorChangePasswordScreen (+37 more)

### Community 4 - "Server DB & Auth Sessions"
Cohesion: 0.08
Nodes (42): accessSessionTtlMinutes(), AuthLoginSession, AuthorIdentity, AuthorRecord, AuthorRow, AuthSession, buildHoursExpiry(), buildTokenExpiry() (+34 more)

### Community 5 - "Topic Model & App Settings Screen"
Cohesion: 0.06
Nodes (38): ../../admin/domain/topic_model.dart, analyticsTrackingProvider, appLanguageProvider, autoSaveEventOnCtaClickProvider, AppSettingsScreen, build, _languageOptions, _themeOptions (+30 more)

### Community 6 - "Navigation & Author/Events Screens"
Cohesion: 0.06
Nodes (38): _buildStatTiles, _deleteDraft, _openForm, events, box, _buildListEntries, compareByStart, createState (+30 more)

### Community 7 - "Server Build Info & Utils"
Cohesion: 0.09
Nodes (31): respondBadRequest(), BuildInfo, getBuildInfo(), normalizeValue(), shortSha(), cleanupExpiredDrafts(), port, start() (+23 more)

### Community 8 - "App Theme & Spacing"
Cohesion: 0.05
Nodes (36): AppSpacing, AppTheme, _build, dark, l, light, m, primary (+28 more)

### Community 9 - "Debug Tools Screen"
Cohesion: 0.06
Nodes (35): LogSource, _animateToBottom, child, children, content, createState, _debugNavTile, dispose (+27 more)

### Community 10 - "Event Editor Sheet"
Cohesion: 0.06
Nodes (35): _buildTopicDropdown, _cancel, _continue, createState, _cta1LabelController, _cta1UrlController, _cta2LabelController, _cta2UrlController (+27 more)

### Community 11 - "Widget Test Fakes"
Cohesion: 0.06
Nodes (34): _authorId, clearAuthorSession, clearAuthorTokens, createAdminUser, expectEventuallyFound, FakeAdminRemoteEventSource, FakeSettingsRepository, fetchAdminUsers (+26 more)

### Community 12 - "Test App Bootstrap"
Cohesion: 0.10
Nodes (12): app, clearAuthorData(), clearDrafts(), clearEvents(), close(), connect(), createAuthorForTesting(), ensureSeedLayers() (+4 more)

### Community 13 - "Server Auth Rate Limiting"
Cohesion: 0.08
Nodes (25): authRateLimiter, authRateLimitMax, authRateLimitWindowMs, createRateLimiter(), getBearerToken(), getViewerSession(), globalRateLimiter, globalRateLimitMax (+17 more)

### Community 14 - "Admin User Detail Screen"
Cohesion: 0.10
Nodes (31): didChangeAppLifecycleState, build, _loadUsers, AdminUserDetailScreen, _AdminUserDetailScreenState, _confirm, _contributions, _contributionsRequestId (+23 more)

### Community 15 - "Author Auth Provider"
Cohesion: 0.06
Nodes (31): authorId, authorLockTimeout, changePassword, copyWith, expiresAt, getValidAccessToken, isAdmin, isLocked (+23 more)

### Community 16 - "Confetti Overlay"
Cohesion: 0.06
Nodes (30): Alignment, bottomSpawnHeight, build, color, _controller, createState, dispose, duration (+22 more)

### Community 17 - "Admin Screen & OTP Dialog"
Cohesion: 0.08
Nodes (24): admin_otp_dialog.dart, ../../admin/presentation/admin_screen.dart, admin_user_detail_screen.dart, AdminScreen, _AdminScreenState, createState, _createUser, dispose (+16 more)

### Community 18 - "Server Data Access Layer"
Cohesion: 0.11
Nodes (25): changeAuthorPassword(), createAuthor(), createEventUpdate(), createTopic(), deleteAuthorById(), deleteAuthorDraftById(), deleteAuthorEventById(), deleteLayer() (+17 more)

### Community 19 - "Analytics Service"
Cohesion: 0.08
Nodes (23): buildPayload, capture, dispose, _distinctId, _distinctIdOrCreate, _distinctIdStorageKey, _ensureDistinctId, initialize (+15 more)

### Community 20 - "Analytics Concept & Events (PostHog/Wiredash)"
Cohesion: 0.11
Nodes (24): Analytics-Opt-in als zentrale Freigabe-Schwelle, error_captured Event, Grundsatzentscheidungen PostHog/Wiredash, App-Lifecycle Events (app_started, session_duration, ...), PostHog Produkt-Analytics, settings_changed Event, UI-Interaktions-Events (ui_click, menu_opened, dialog_*), Wiredash Feedback-/Support-Tool (+16 more)

### Community 21 - "Push Notification Service"
Cohesion: 0.09
Nodes (22): AndroidNotificationChannel, _channel, _ensureApnsTokenAvailable, firebaseMessagingBackgroundHandler, _flutterLocalNotificationsPlugin, _handleInitialMessage, initialize, _initializeLocalNotifications (+14 more)

### Community 22 - "iOS AppDelegate & SceneDelegate"
Cohesion: 0.09
Nodes (17): Any, AppDelegate, SceneDelegate, RunnerTests, Bool, Data, Error, Flutter (+9 more)

### Community 23 - "App Widget Lifecycle"
Cohesion: 0.09
Nodes (22): _analytics, appThemeModeProvider, createState, dispose, hasSeenWelcomeProvider, _isPaused, _logger, _usageTracking (+14 more)

### Community 24 - "Topic Admin Screen"
Cohesion: 0.10
Nodes (20): _buildTopicList, _confirm, confirmLabel, _controller, createState, dispose, _formKey, initialValue (+12 more)

### Community 25 - "CI/CD Secrets & Xcode Cloud"
Cohesion: 0.10
Nodes (21): ios/ci_scripts (post_clone, pre_xcodebuild, post_xcodebuild), Xcode-Cloud-Variablen fuer app/.env, GitHub Secrets fuer Server Deploy, Linux Host Struktur (/opt/dpsg-news), Quality Soft Checks Workflow, Server Deploy Main Workflow, iOS Xcode Cloud Variablen fuer app/.env, Secret-Klassen (Build-Config, App-Secrets, Server-Secrets) (+13 more)

### Community 26 - "TypeScript Build Config"
Cohesion: 0.10
Nodes (20): dist, node_modules, src, compilerOptions, esModuleInterop, forceConsistentCasingInFileNames, isolatedModules, module (+12 more)

### Community 27 - "Event Detail Screen"
Cohesion: 0.10
Nodes (19): createState, dispose, event, _eventId, _eventIdAsInt, _loadingUpdates, _postingUpdate, _saving (+11 more)

### Community 28 - "Flutter App Project Docs"
Cohesion: 0.13
Nodes (19): Flutter analysis_options.yaml, app/Claude.md (Projektleitlinien duplicate), app/pubspec.yaml (dpsg_news_app manifest), .env.example bundled asset, flutter_lints dependency, App README (Flutter-Frontend), Root CLAUDE.md Project Instructions, investigate Skill (+11 more)

### Community 29 - "App Navigation State"
Cohesion: 0.15
Nodes (18): _AppState, build, currentIndexProvider, appNavigatorKeyProvider, eventsProvider, build, createState, _editorKey (+10 more)

### Community 30 - "Usage Tracking Service"
Cohesion: 0.11
Nodes (18): LoggingService, endSession, flushPendingSession, logger, now, NowProvider, pause, _pausedAt (+10 more)

### Community 31 - "Event Sync Service"
Cohesion: 0.11
Nodes (18): baseUrl, configuredUrl, eventSyncStatusProvider, _lastSyncedAt, logger, _minSyncInterval, ref, remoteEventSourceProvider (+10 more)

### Community 32 - "Own Events Provider"
Cohesion: 0.14
Nodes (18): build, auth, ownDraftsProvider, ownEventsProvider, read, token, AuthorScreen, build (+10 more)

### Community 33 - "Server Dev Tooling Deps"
Cohesion: 0.11
Nodes (19): cross-env, husky, jest, nodemon, devDependencies, cross-env, husky, jest (+11 more)

### Community 34 - "Settings State Notifiers"
Cohesion: 0.11
Nodes (18): AnalyticsTrackingNotifier, AppLanguageNotifier, AppThemeModeNotifier, AuthorModeNotifier, AutoSaveEventOnCtaClickNotifier, DeadlineReminderDaysBeforeNotifier, DeadlineReminderNotifier, EventViewedAtNotifier (+10 more)

### Community 35 - "Secure Storage Service"
Cohesion: 0.12
Nodes (16): accessExpiresAt, accessToken, _authorAccessExpiresAtKey, _authorAccessTokenKey, _authorRefreshExpiresAtKey, _authorRefreshTokenKey, AuthorTokenBundle, clearAuthorTokens (+8 more)

### Community 36 - "Welcome Screen Test"
Cohesion: 0.13
Nodes (15): SettingsRepository, fetchLayers, hamburgLayerId, main, pump, pumpUntilFound, pumpWelcomeScreen, repository (+7 more)

### Community 37 - "Event List Tile"
Cohesion: 0.12
Nodes (15): build, createdBy, isSaved, layerName, location, onDelete, onEdit, onTap (+7 more)

### Community 38 - "Wiredash Metadata Service"
Cohesion: 0.13
Nodes (11): buildSafeCustomMetadata, WiredashMetadataService, showAdminOtpDialog, main, pumpMarkdown, main, package:dpsg_news_app/core/services/wiredash_metadata_service.dart, package:dpsg_news_app/shared/widgets/safe_markdown_body.dart (+3 more)

### Community 39 - "Calendar & Changelog Screens"
Cohesion: 0.13
Nodes (13): build, CalendarScreen, ChangelogScreen, _ColoredLogView, _DebugActionButton, _DebugButtonGroup, _DebugSectionCard, ExternalNotificationsPlaceholderScreen (+5 more)

### Community 40 - "Dashboard Stats Tests"
Cohesion: 0.13
Nodes (10): main, main, main, main, main, package:dpsg_news_app/core/services/analytics_service.dart, package:dpsg_news_app/features/author/presentation/author_dashboard_stats.dart, package:dpsg_news_app/features/events/presentation/events_dashboard_stats.dart (+2 more)

### Community 41 - "Events Screen Test"
Cohesion: 0.13
Nodes (14): _events, fetchEvents, fetchLayers, hamburgLayerId, koelnLayerId, main, _pumpEventsScreen, remote (+6 more)

### Community 42 - "Server Event CRUD Endpoints"
Cohesion: 0.14
Nodes (13): createAuthorEvent(), createEvent(), deleteAllEvents(), deleteEventById(), getAuthorEvents(), getEvents(), mapEventRow(), updateAuthorEventById() (+5 more)

### Community 43 - "Author Change Password Screen"
Cohesion: 0.14
Nodes (13): build, _confirmPasswordController, createState, dispose, _formKey, _newPasswordController, _obscureConfirmPassword, _obscureNewPassword (+5 more)

### Community 44 - "Event Detail Smoke Test"
Cohesion: 0.14
Nodes (12): fetchEventUpdates, fetchLayers, fetchTopics, _koelnLayerId, main, _pfadfinderTopicId, _pumpUntilFound, _sampleEvent (+4 more)

### Community 45 - "Date Format Utils"
Cohesion: 0.15
Nodes (12): dateTime, diff, formatEventDateTime, formatMonthAbbreviation, formatMonthYearHeader, formatRelativeTime, local, now (+4 more)

### Community 46 - "Author Login Screen"
Cohesion: 0.17
Nodes (11): build, createState, dispose, _formKey, _obscurePassword, _passwordController, _submitting, _usernameController (+3 more)

### Community 47 - "Author Screen Test"
Cohesion: 0.17
Nodes (10): EventListTile, main, main, wrap, package:dpsg_news_app/core/theme/app_theme.dart, package:dpsg_news_app/features/author/data/author_auth_provider.dart, package:dpsg_news_app/features/author/data/own_events_provider.dart, package:dpsg_news_app/features/author/presentation/author_screen.dart (+2 more)

### Community 48 - "Repo Structure & Endpoints Doc"
Cohesion: 0.20
Nodes (12): Flutter-Frontend (app/), Express-Backend (server/), Repo-Ziel: neutrale Basisstruktur, Server API-Endpunkte, Auth-Endpunkte (login/logout/refresh/me/change-password), Autoren-Events CRUD-Endpunkte, GET /api/events, GET /health (+4 more)

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
Cohesion: 0.25
Nodes (11): _CreateUserDialog, _CreateUserDialogState, ConfettiOverlay, _ConfettiOverlayState, _LogViewerPage, _LogViewerPageState, SkeletonCardList, _SkeletonCardListState (+3 more)

### Community 53 - "Server Runtime Dependencies"
Cohesion: 0.18
Nodes (11): dotenv, express, firebase-admin, pg, redis, dependencies, dotenv, express (+3 more)

### Community 54 - "Event Field Validation"
Cohesion: 0.36
Nodes (9): FieldValidation, invalid(), isHttpOrHttpsUrl(), VALID_RESULT, validateEventTextFields(), validateMessageField(), validateOptionalCtaUrl(), validateOptionalText() (+1 more)

### Community 55 - "Skeleton Loading Animation"
Cohesion: 0.20
Nodes (9): Animation, AnimationController, build, _controller, count, createState, dispose, initState (+1 more)

### Community 56 - "App Entry Point"
Cohesion: 0.20
Nodes (9): app.dart, errorContainer, initialize, initializeDateFormatting, main, startupAnalytics, package:firebase_core/firebase_core.dart, package:firebase_messaging/firebase_messaging.dart (+1 more)

### Community 57 - "Event Model"
Cohesion: 0.20
Nodes (9): description, endDate, EventModel, fromJson, id, layerId, location, startDate (+1 more)

### Community 58 - "Layer Tree Provider"
Cohesion: 0.20
Nodes (9): layers, LayerTreeNotifier, _loadTree, _remoteSource, _repository, AsyncValue, ../domain/layer_model.dart, ../../events/data/remote_event_source.dart (+1 more)

### Community 59 - "Layer Model"
Cohesion: 0.20
Nodes (9): fromJson, id, LayerModel, name, parentId, toJson, type, url (+1 more)

### Community 60 - "App Config"
Cohesion: 0.22
Nodes (8): AppConfig, hasPosthogConfig, hasWiredashConfig, normalizeApiBaseUrl, posthogHost, _readDotenv, dart:io, static bool get

### Community 61 - "Error Toast Service"
Cohesion: 0.22
Nodes (8): context, describeRemoteError, safeMessage, showErrorToast, toString, app_navigation_service.dart, ../../features/events/data/remote_event_source.dart, package:my_toastify/my_toastify.dart

### Community 62 - "Event Repository (Local)"
Cohesion: 0.22
Nodes (8): _box, EventRepository, eventRepositoryProvider, getLocalEvents, saveEvents, Box, core/services/hive_service.dart, package:hive/hive.dart

### Community 63 - "Notification Preference Providers"
Cohesion: 0.39
Nodes (9): deadlineReminderDaysBeforeProvider, deadlineReminderProvider, newEventPushEnabledProvider, notificationsEnabledProvider, subscribedEventsReminderDaysBeforeProvider, subscribedEventsReminderProvider, weeklyPushSummaryProvider, build (+1 more)

### Community 64 - "Safe Markdown Rendering"
Cohesion: 0.22
Nodes (8): alt, _BlockedImagePlaceholder, build, data, SafeMarkdownBody, package:flutter_markdown/flutter_markdown.dart, String?, ../utils/url_utils.dart

### Community 65 - "Config/Env Tests"
Cohesion: 0.25
Nodes (6): main, main, main, package:dpsg_news_app/core/config/app_config.dart, package:dpsg_news_app/core/services/logging_env.dart, package:flutter_dotenv/flutter_dotenv.dart

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
Cohesion: 0.25
Nodes (8): build, TopicAdminScreen, _TopicAdminScreenState, build, EventEditorPage, _EventEditorPageState, layerTreeProvider, build

### Community 70 - "Empty State Widget"
Cohesion: 0.25
Nodes (7): actionLabel, build, EmptyState, icon, message, onAction, VoidCallback?

### Community 71 - "Labeled Chip Widget"
Cohesion: 0.25
Nodes (7): build, color, icon, label, LabeledChip, value, IconData

### Community 72 - "Section Card Widget"
Cohesion: 0.25
Nodes (7): background, build, child, SectionCard, title, Color?, Widget

### Community 73 - "Stat Tile Widget"
Cohesion: 0.25
Nodes (7): build, color, icon, label, onTap, StatTile, value

### Community 74 - "Author & Event Domain Rules"
Cohesion: 0.29
Nodes (8): Autorenbereich auf eigene Events begrenzt, Autoren-Session-Handling (Secure Storage, Token-Rotation), Server Event-Datenmodell, Autoren-Flow (Login, Passwortwechsel, Biometrie-Relock), Benutzerrollen (Anonym, Autor, Administrator), Eventmodell (Pflicht-/Optionalfelder, Status), MVP-Funktionen (Eventliste, Details, Suche, Filter), Push-Konzept (FCM Topics nach DV/Kategorie)

### Community 75 - "Server Package Scripts"
Cohesion: 0.25
Nodes (7): description, pre-push, husky, hooks, main, name, version

### Community 76 - "Remote Event Source Test"
Cohesion: 0.29
Nodes (6): baseUrl, main, dart:convert, package:dpsg_news_app/features/events/data/remote_event_source.dart, package:http/http.dart, package:http/testing.dart

### Community 77 - "Server Push Notification Payloads"
Cohesion: 0.43
Nodes (6): getTopicById(), EventNotificationPayload, EventUpdateNotificationPayload, normalizeTopicName(), sendEventNotification(), sendEventUpdateNotification()

### Community 78 - "Remote Event Source Fakes"
Cohesion: 0.33
Nodes (6): RemoteEventSource, RemoteEventSourceStub, _FakeRemoteEventSource, _FakeRemoteEventSource, FakeRemoteEventSource, FakeRemoteEventSource

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
Cohesion: 0.40
Nodes (5): Installierte Claude Plugins (typescript-lsp, security-guidance, code-review, posthog), Eigene Claude Skills (/investigate, /verify-feature, /flutter-review, /backend-review, /publish-feature), Claude Code Worktree-Workflow, Backend Architektur-Regeln (Claude.md), Development Agent (server)

### Community 85 - "Privacy/Terms Jekyll Site"
Cohesion: 0.67
Nodes (4): Jekyll _config.yml (theme minima, lang de), DPSG News Rechtliches Landing Page, Privacy Policy Controller (Janneck Lange), Terms & Conditions License/Open Source Clause

### Community 87 - "Author Auth Notifier Test"
Cohesion: 0.67
Nodes (3): AuthorAuthNotifier, AuthorAuthState, TestAuthorAuthNotifier

### Community 88 - "Review Skills Trio"
Cohesion: 0.67
Nodes (3): backend-review Skill, flutter-review Skill, verify-feature Skill

### Community 89 - "Server Setup Instructions"
Cohesion: 1.00
Nodes (3): Server starten (npm install / npm start), Server-Setup (npm install/start), Server Installation/Lokaler Start

### Community 90 - "Claude Code Review Workflow"
Cohesion: 0.67
Nodes (3): Claude Code Workflow (@claude mention trigger), Claude Code Review Workflow, code-review Claude Code Plugin

## Ambiguous Edges - Review These
- `Express-Backend (server/)` → `Tech Stack (Flutter, Spring Boot, PostgreSQL, FCM)`  [AMBIGUOUS]
  spec/plan.md · relation: conceptually_related_to

## Knowledge Gaps
- **924 isolated node(s):** `.tmp_restore.sh script`, `id`, `targets`, `UserNotifications`, `XCTest` (+919 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **40 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Express-Backend (server/)` and `Tech Stack (Flutter, Spring Boot, PostgreSQL, FCM)`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `SettingsRepository` connect `Welcome Screen Test` to `Settings Repository & Keys`, `Layer Tree Provider`, `Author Auth Provider`, `Event Sync Service`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Why does `LoggingService` connect `Usage Tracking Service` to `Logging Service Core`, `Remote Event Source & Auth`, `Debug Tools Screen`, `App Widget Lifecycle`, `Event Sync Service`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **Why does `LayerTreeNotifier` connect `Layer Tree Provider` to `Settings State Notifiers`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **What connects `.tmp_restore.sh script`, `id`, `targets` to the rest of the system?**
  _924 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Settings Repository & Keys` be split into smaller, more focused modules?**
  _Cohesion score 0.020202020202020204 - nodes in this community are weakly interconnected._
- **Should `Logging Service Core` be split into smaller, more focused modules?**
  _Cohesion score 0.03333333333333333 - nodes in this community are weakly interconnected._