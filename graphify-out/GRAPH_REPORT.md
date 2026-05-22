# Graph Report - /home/user/workspace/zipline-native  (2026-05-22)

## Corpus Check
- 77 files · ~132,472 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 363 nodes · 438 edges · 19 communities (17 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Core Services & Config|Core Services & Config]]
- [[_COMMUNITY_Auth & Upload Services|Auth & Upload Services]]
- [[_COMMUNITY_Share Screen UI|Share Screen UI]]
- [[_COMMUNITY_Theme & UI Primitives|Theme & UI Primitives]]
- [[_COMMUNITY_App Bootstrap|App Bootstrap]]
- [[_COMMUNITY_Upload Queue UI|Upload Queue UI]]
- [[_COMMUNITY_Login Screen|Login Screen]]
- [[_COMMUNITY_Debug Screen (Server Config)|Debug Screen (Server Config)]]
- [[_COMMUNITY_Global App State|Global App State]]
- [[_COMMUNITY_Debug Screen (Logs View)|Debug Screen (Logs View)]]
- [[_COMMUNITY_Home Screen|Home Screen]]
- [[_COMMUNITY_Debug Logging Service|Debug Logging Service]]
- [[_COMMUNITY_Minimal Text Field Widget|Minimal Text Field Widget]]
- [[_COMMUNITY_Android Native Bridge|Android Native Bridge]]
- [[_COMMUNITY_Cloudflare Worker (Share Redirect)|Cloudflare Worker (Share Redirect)]]
- [[_COMMUNITY_Build Config Pair|Build Config Pair]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 17 edges
2. `package:flutter/services.dart` - 9 edges
3. `dart:io` - 8 edges
4. `package:shared_preferences/shared_preferences.dart` - 7 edges
5. `debug_service.dart` - 7 edges
6. `MainActivity` - 6 edges
7. `../services/auth_service.dart` - 6 edges
8. `dart:convert` - 6 edges
9. `dart:async` - 5 edges
10. `../services/upload_queue_service.dart` - 5 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (19 total, 2 thin omitted)

### Community 0 - "Core Services & Config"
Cohesion: 0.05
Nodes (44): biometric_service.dart, ../core/build_config.dart, ../core/constants.dart, dart:convert, dart:math, debug_service.dart, _saveTheme, ThemeProvider (+36 more)

### Community 1 - "Auth & Upload Services"
Cohesion: 0.05
Nodes (37): auth_service.dart, dart:collection, dart:io, file_upload_service.dart, Exception, FileUploadService, isValidUrl, _resolveAuthService (+29 more)

### Community 2 - "Share Screen UI"
Cohesion: 0.05
Nodes (37): build, _buildButton, _buildCard, _buildIcon, _buildShareActionChip, Color, Container, _copyShareAndNotify (+29 more)

### Community 3 - "Theme & UI Primitives"
Cohesion: 0.06
Nodes (26): AppConstants, AppTheme, AppButton, build, Color, Container, SizedBox, AppTextField (+18 more)

### Community 4 - "App Bootstrap"
Cohesion: 0.07
Nodes (27): setupServiceLocator, build, Color, initState, main, MaterialApp, Positioned, Scaffold (+19 more)

### Community 5 - "Upload Queue UI"
Cohesion: 0.07
Nodes (25): build, _buildTaskItem, _buildUploadQueue, Container, dispose, Icon, initState, Positioned (+17 more)

### Community 6 - "Login Screen"
Cohesion: 0.08
Nodes (24): AlertDialog, _attemptBiometricLogin, build, _buildButton, _buildCard, _buildTextField, _checkAndPromptForBiometric, Color (+16 more)

### Community 7 - "Debug Screen (Server Config)"
Cohesion: 0.09
Nodes (22): debug_screen.dart, build, _buildButton, _buildCard, _buildIcon, _buildServerUrlTextField, _buildTextField, Color (+14 more)

### Community 8 - "Global App State"
Cohesion: 0.1
Nodes (18): ../core/service_locator.dart, dart:async, AppState, clearError, dispose, hideUploadQueue, _initializeState, logout (+10 more)

### Community 9 - "Debug Screen (Logs View)"
Cohesion: 0.11
Nodes (18): build, Card, Chip, _clearLogs, DebugScreen, _DebugScreenState, _formatLogData, _getLevelColor (+10 more)

### Community 10 - "Home Screen"
Cohesion: 0.11
Nodes (17): home_screen.dart, build, _buildButton, _buildCard, Color, Container, dispose, HomeScreen (+9 more)

### Community 11 - "Debug Logging Service"
Cohesion: 0.15
Nodes (12): clearLogs, DebugLog, DebugService, getLogsAsJson, jsonEncode, _loadLogs, log, logAuth (+4 more)

### Community 12 - "Minimal Text Field Widget"
Cohesion: 0.22
Nodes (8): build, Column, dispose, Function, initState, MinimalTextField, _MinimalTextFieldState, SizedBox

### Community 14 - "Cloudflare Worker (Share Redirect)"
Cohesion: 0.47
Nodes (4): fetch(), redirectToApp(), encodedCookie, response

## Knowledge Gaps
- **281 isolated node(s):** `main`, `package:zipline_native_app/services/upload_queue_service.dart`, `main`, `package:zipline_native_app/services/auth_service.dart`, `response` (+276 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Theme & UI Primitives` to `Core Services & Config`, `Share Screen UI`, `App Bootstrap`, `Upload Queue UI`, `Login Screen`, `Debug Screen (Server Config)`, `Global App State`, `Debug Screen (Logs View)`, `Home Screen`, `Minimal Text Field Widget`?**
  _High betweenness centrality (0.368) - this node is a cross-community bridge._
- **Why does `dart:io` connect `Auth & Upload Services` to `Debug Screen (Logs View)`, `Share Screen UI`, `Debug Logging Service`?**
  _High betweenness centrality (0.143) - this node is a cross-community bridge._
- **Why does `package:flutter/services.dart` connect `Core Services & Config` to `Auth & Upload Services`, `Share Screen UI`, `Theme & UI Primitives`, `Login Screen`, `Debug Screen (Server Config)`, `Debug Screen (Logs View)`, `Home Screen`, `Minimal Text Field Widget`?**
  _High betweenness centrality (0.122) - this node is a cross-community bridge._
- **What connects `main`, `package:zipline_native_app/services/upload_queue_service.dart`, `main` to the rest of the system?**
  _281 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Core Services & Config` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Auth & Upload Services` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Share Screen UI` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._