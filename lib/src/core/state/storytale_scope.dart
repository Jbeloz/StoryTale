import 'package:flutter/widgets.dart';

import 'storytale_controller.dart';

class StoryTaleScope extends InheritedNotifier<StoryTaleController> {
  const StoryTaleScope({
    required StoryTaleController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static StoryTaleController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoryTaleScope>();
    assert(scope != null, 'StoryTaleScope is missing above this context.');
    return scope!.notifier!;
  }
}
