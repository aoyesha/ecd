import 'package:flutter/material.dart';

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class NoTransitionRoute<T> extends MaterialPageRoute<T> {
  NoTransitionRoute({required WidgetBuilder builder}) : super(builder: builder);

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => Duration.zero;
}

Future<T?> navPushNoTransition<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(NoTransitionRoute(builder: (_) => page));
}

Future<T?> navReplaceNoTransition<T>(BuildContext context, Widget page) {
  return Navigator.of(context)
      .pushReplacement<T, T>(NoTransitionRoute(builder: (_) => page));
}

void navPopToRoot(BuildContext context) {
  Navigator.of(context).popUntil((r) => r.isFirst);
}
