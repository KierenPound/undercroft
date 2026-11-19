import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Forwards runtime errors to Sentry.
///
/// UnderCroft holds sensitive estate material, so reporting is deliberately
/// conservative: no user identity, no request data and no breadcrumbs ever
/// leave the device, and the free text of an error is redacted for email
/// addresses and long opaque tokens before it is sent. Only the error type,
/// its message (redacted), the stack trace and basic device/app context are
/// reported.
///
/// The DSN is supplied at build time (see supabase_config.json and
/// scripts/generate_ios_local_xcconfig.sh). When it is absent — a local debug
/// run without the define, say — the service stays inert and every method
/// here is a no-op.
class CrashReportingService {
  CrashReportingService._();

  static const String _dsn = String.fromEnvironment('SENTRY_DSN');

  static bool _initialized = false;

  /// Whether a DSN was supplied at build time.
  static bool get isConfigured => _dsn.trim().isNotEmpty;

  /// Whether the SDK actually initialised and is capturing events.
  static bool get isEnabled => _initialized;

  /// Initialises the SDK. Safe to call when unconfigured: it simply returns.
  /// A failure to initialise is swallowed — crash reporting must never take
  /// the app down with it.
  static Future<void> initialize() async {
    if (!isConfigured) return;
    try {
      await SentryFlutter.init(
        _configure,
        appRunner: () async => _initialized = true,
      );
    } catch (error) {
      debugPrint(
        '[crash-reporting] init failed errorType=${error.runtimeType}',
      );
    }
  }

  static void _configure(SentryFlutterOptions options) {
    options.dsn = _dsn;
    // No personally identifying data, and no session/user tracking: this is an
    // error log, not an analytics product.
    options.sendDefaultPii = false;
    options.enableAutoSessionTracking = false;
    options.attachStacktrace = true;
    // Drop every breadcrumb. The SDK's defaults include navigation routes and
    // HTTP URLs, which can carry estate identifiers.
    options.beforeBreadcrumb = (_, __) => null;
    options.beforeSend = _scrub;
  }

  /// Reports an error from the app's own handlers in lib/main.dart.
  static Future<void> reportError(
    String source,
    Object error, [
    StackTrace? stackTrace,
  ]) async {
    if (!_initialized) return;
    try {
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setTag('source', source);
          scope.setUser(null);
        },
      );
    } catch (_) {
      // Reporting must never throw.
    }
  }

  /// Sends a harmless event so a build can be confirmed end to end. Only
  /// reachable from the Developer tools section of Settings.
  static Future<void> reportTestEvent() async {
    if (!_initialized) return;
    try {
      await Sentry.captureMessage(
        'UnderCroft test event',
        level: SentryLevel.info,
      );
    } catch (_) {
      // Reporting must never throw.
    }
  }

  /// Last line of defence before an event leaves the device.
  static SentryEvent? _scrub(SentryEvent event, Hint hint) {
    event.user = null;
    event.request = null;
    event.breadcrumbs = null;

    // The exception's message is the one place user text could creep in — a
    // Supabase error quoting an email address, for instance.
    final exceptions = event.exceptions;
    if (exceptions != null) {
      for (final exception in exceptions) {
        final value = exception.value;
        if (value != null) exception.value = _redact(value);
      }
    }

    final message = event.message;
    if (message != null) {
      message.formatted = _redact(message.formatted);
      final template = message.template;
      if (template != null) message.template = _redact(template);
    }

    return event;
  }

  static final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');
  static final RegExp _opaqueToken = RegExp(r'\b[A-Za-z0-9_-]{32,}\b');

  static String _redact(String input) => input
      .replaceAll(_email, '[email]')
      .replaceAll(_opaqueToken, '[redacted]');
}
