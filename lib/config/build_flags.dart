import 'package:flutter/foundation.dart';

/// Whether this build was compiled with the developer tools switched on.
///
/// Supplied at build time with `--dart-define=ENABLE_DEV_TOOLS=true`. A
/// release build simply omits it, so the constant folds to false and
/// everything gated on it drops out of the build.
const bool enableDevTools = bool.fromEnvironment(
  'ENABLE_DEV_TOOLS',
  defaultValue: false,
);

/// Whether the Developer tools section should be present at all.
///
/// Debug builds always have it, so everyday development needs no define. A
/// beta build opts in with [enableDevTools]. A release build has neither, so
/// the role simulation and the payment rehearsal cannot be reached.
bool get devToolsEnabled => kDebugMode || enableDevTools;
