/// Every named destination in the app.
///
/// Navigation goes through these names — `context.goNamed(AppRoute.plan.name)`
/// — never through a path literal. A typo in a name is a compile error; a typo
/// in a string is a blank screen at runtime.
///
/// It lives in its own file rather than beside the GoRouter because screens
/// need the names and the router needs the screens. With everything in
/// `app_router.dart`, nothing compiles until all of it exists at once.
enum AppRoute {
  signIn,
  home,

  /// Reserved for 007–009. Listed here so the shape of the app is visible in
  /// one place; each gains a route when its screen lands.
  plan,
  planReview,
  tasks,
  settings,
}
