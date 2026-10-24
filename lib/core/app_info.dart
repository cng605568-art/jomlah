/// Set at build time (the GitHub workflow fills these in automatically).
const kApiUrl = String.fromEnvironment('API_URL');
const kFeedbackUrl = String.fromEnvironment('FEEDBACK_URL');
const kPrivacyUrl = String.fromEnvironment('PRIVACY_URL');

/// Without a backend, alerts are fake and live only on this phone.
const kDemoMode = kApiUrl == '';

const kAppVersion = '0.1.0 beta';
