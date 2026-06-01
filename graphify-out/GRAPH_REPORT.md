# Graph Report - .  (2026-06-01)

## Corpus Check
- 112 files · ~147,728 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 358 nodes · 465 edges · 19 communities (18 shown, 1 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Community 10|Community 10]]
- [[_COMMUNITY_Community 12|Community 12]]
- [[_COMMUNITY_Community 11|Community 11]]
- [[_COMMUNITY_Community 15|Community 15]]
- [[_COMMUNITY_Community 0|Community 0]]
- [[_COMMUNITY_Community 3|Community 3]]
- [[_COMMUNITY_Community 1|Community 1]]
- [[_COMMUNITY_Community 4|Community 4]]
- [[_COMMUNITY_Community 8|Community 8]]
- [[_COMMUNITY_Community 9|Community 9]]
- [[_COMMUNITY_Community 2|Community 2]]
- [[_COMMUNITY_Community 5|Community 5]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Community 6|Community 6]]
- [[_COMMUNITY_Community 13|Community 13]]
- [[_COMMUNITY_Community 14|Community 14]]

## God Nodes (most connected - your core abstractions)
1. `MainActivity` - 9 edges
2. `scripts` - 4 edges
3. `String` - 3 edges
4. `redirectToApp()` - 3 edges
5. `Intent` - 2 edges
6. `fetch()` - 2 edges
7. `List` - 1 edges
8. `FlutterEngine` - 1 edges
9. `Boolean` - 1 edges
10. `v` - 1 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (19 total, 1 thin omitted)

### Community 10 - "Community 10"
Cohesion: 0.24
Nodes (7): MainActivity, FlutterFragmentActivity, List, String, FlutterEngine, Intent, Boolean

### Community 12 - "Community 12"
Cohesion: 0.18
Nodes (10): v, fr, ip, op, w, h, nm, ddd (+2 more)

### Community 11 - "Community 11"
Cohesion: 0.17
Nodes (11): name, version, description, type, main, scripts, deploy, dev (+3 more)

### Community 0 - "Community 0"
Cohesion: 0.05
Nodes (41): BuildConfig, ThemeProvider, _saveTheme, ActivityService, initialize, AuthService, _ensurePrefsInitialized, migrateKey (+33 more)

### Community 3 - "Community 3"
Cohesion: 0.06
Nodes (27): AppConstants, AppTheme, ResponsiveLayout, ResponsiveGrid, isMobile, isTablet, isDesktop, responsivePadding (+19 more)

### Community 1 - "Community 1"
Cohesion: 0.07
Nodes (34): setupServiceLocator, FileUploadService, _resolveAuthService, StateError, _resolveQueueService, _resolveDebugService, Exception, uploadFile (+26 more)

### Community 4 - "Community 4"
Cohesion: 0.07
Nodes (28): ZiplineNativeApp, SplashScreen, _SplashScreenState, main, build, MaterialApp, UploadQueueOverlay, Positioned (+20 more)

### Community 8 - "Community 8"
Cohesion: 0.11
Nodes (17): AppState, _initializeState, setUser, logout, toggleUploadQueue, showUploadQueue, hideUploadQueue, setUploadQueueUiEnabled (+9 more)

### Community 9 - "Community 9"
Cohesion: 0.11
Nodes (18): DebugScreen, _DebugScreenState, initState, _refreshLogs, Text, SizedBox, _shareLogFile, SnackBar (+10 more)

### Community 2 - "Community 2"
Cohesion: 0.05
Nodes (36): HomeScreen, _HomeScreenState, _HeaderNotificationOverlay, _HeaderNotificationOverlayState, initState, _setupSharingService, _uploadFiles, _shortenUrl (+28 more)

### Community 5 - "Community 5"
Cohesion: 0.08
Nodes (23): LoginScreen, _LoginScreenState, initState, HomeScreen, SlideTransition, _showErrorSnackBar, Icon, SizedBox (+15 more)

### Community 7 - "Community 7"
Cohesion: 0.10
Nodes (20): SettingsScreen, _SettingsScreenState, initState, _onFieldChanged, _showSuccessSnackBar, Icon, SizedBox, _showErrorSnackBar (+12 more)

### Community 6 - "Community 6"
Cohesion: 0.08
Nodes (23): SimpleLoginScreen, _SimpleLoginScreenState, initState, _attemptBiometricLogin, _checkAndPromptForBiometric, HomeScreen, SlideTransition, AlertDialog (+15 more)

### Community 13 - "Community 13"
Cohesion: 0.20
Nodes (9): SkeletonLoader, _SkeletonLoaderState, SkeletonListItem, initState, dispose, build, AnimatedBuilder, Container (+1 more)

### Community 14 - "Community 14"
Cohesion: 0.22
Nodes (8): UploadQueueWidget, build, Container, SizedBox, Spacer, _buildTaskItem, _showQueueDetails, _buildDetailedTaskItem

## Knowledge Gaps
- **280 isolated node(s):** `List`, `FlutterEngine`, `Boolean`, `v`, `fr` (+275 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What connects `List`, `FlutterEngine`, `Boolean` to the rest of the system?**
  _280 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Community 0` be split into smaller, more focused modules?**
  _Cohesion score 0.05272108843537415 - nodes in this community are weakly interconnected._
- **Should `Community 3` be split into smaller, more focused modules?**
  _Cohesion score 0.06451612903225806 - nodes in this community are weakly interconnected._
- **Should `Community 1` be split into smaller, more focused modules?**
  _Cohesion score 0.06538461538461539 - nodes in this community are weakly interconnected._
- **Should `Community 4` be split into smaller, more focused modules?**
  _Cohesion score 0.06896551724137931 - nodes in this community are weakly interconnected._
- **Should `Community 8` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._
- **Should `Community 9` be split into smaller, more focused modules?**
  _Cohesion score 0.10526315789473684 - nodes in this community are weakly interconnected._