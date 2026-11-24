enum InstallMode {
  /// Nothing to offer: a native app, an unsupported browser, or no prompt yet.
  none,

  /// The browser handed over an install prompt (Chrome, Edge, Samsung Internet).
  prompt,

  /// Safari on iPhone or iPad: installing is Share > Add to Home Screen.
  iosShare,

  /// Already running as an installed app.
  installed,
}
