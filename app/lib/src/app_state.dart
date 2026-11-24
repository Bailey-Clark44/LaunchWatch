import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'account.dart';
import 'launch_repository.dart';
import 'space_data.dart';

/// Gives every screen the account and the launch catalog.
class LaunchWatchScope extends InheritedNotifier<AccountController> {
  const LaunchWatchScope({super.key, required AccountController state, required this.repository, required this.space, required super.child}) : super(notifier: state);

  final LaunchRepository repository;
  final SpaceRepository space;

  static AccountController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LaunchWatchScope>();
    assert(scope != null, 'LaunchWatchScope is missing');
    return scope!.notifier!;
  }

  static LaunchRepository repositoryOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<LaunchWatchScope>()!.repository;
  }

  static SpaceRepository spaceOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<LaunchWatchScope>()!.space;
  }
}

/// On wide screens the launch list and the launch page sit side by side.
/// Rows select into this instead of pushing a new page.
class SplitSelection extends InheritedNotifier<ValueNotifier<String?>> {
  const SplitSelection({super.key, required ValueNotifier<String?> selection, required super.child}) : super(notifier: selection);

  static ValueNotifier<String?>? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SplitSelection>()?.notifier;
  }
}

/// Opens a launch: selects it in split view, or pushes `/launch/{id}` so the
/// address bar shows a link people can share.
void openLaunch(BuildContext context, String id) {
  final split = SplitSelection.maybeOf(context);
  if (split != null) {
    split.value = id;
    SystemNavigator.routeInformationUpdated(uri: Uri(path: '/launch/$id'));
    return;
  }
  Navigator.of(context).pushNamed('/launch/$id');
}

/// Public site used for share links and calendar feeds on every platform.
const siteOrigin = String.fromEnvironment('SITE_ORIGIN', defaultValue: 'https://launchwatch-c77fa.web.app');

String launchLink(String id) => '$siteOrigin/launch/$id';

void openEvent(BuildContext context, String id) => Navigator.of(context).pushNamed('/event/$id');
void openStation(BuildContext context, String id) => Navigator.of(context).pushNamed('/station/$id');
void openAstronaut(BuildContext context, String id) => Navigator.of(context).pushNamed('/astronaut/$id');
