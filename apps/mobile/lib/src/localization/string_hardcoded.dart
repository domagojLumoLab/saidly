/// Marks a user-facing string that has no translation key yet.
///
/// It does nothing at runtime. Its only job is to be greppable: when the .arb
/// files arrive, `rg '\.hardcoded'` is the complete list of what still needs a
/// key. A bare literal is indistinguishable from a log line, a map key or a
/// route name, so the list would have to be rebuilt by reading every widget.
extension StringHardcoded on String {
  String get hardcoded => this;
}
