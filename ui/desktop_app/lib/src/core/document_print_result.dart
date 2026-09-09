/// Outcome of asking the platform to print a document.
enum PrintOutcome {
  /// The print job was handed to the printing subsystem.
  printed,

  /// The print dialog opened and the admin dismissed it.
  cancelled,

  /// The platform offers no printing path at all.
  unavailable,
}
