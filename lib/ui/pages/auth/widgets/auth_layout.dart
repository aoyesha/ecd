import 'package:flutter/material.dart';

class AuthLayout extends StatelessWidget {
  final Widget form;
  final String heading;
  final String? subheading;

  const AuthLayout({
    super.key,
    required this.form,
    required this.heading,
    this.subheading,
  });

  static const _title = 'Early Childhood\nDevelopment Checklist';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) =>
              c.maxWidth > 900 ? _desktop() : _mobile(c.maxHeight),
        ),
      ),
    );
  }

  Widget _hero({required bool desktop}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image(
          image: ResizeImage(
            AssetImage('assets/kids.png'),
            width: desktop ? 600 : 360,
            height: desktop ? 400 : 280,
          ),
          width: desktop ? 500 : 320,
        ),
        const SizedBox(height: 24),
        const Text(
          _title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 46,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  Widget _panel({double? width}) {
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            heading,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          if (subheading != null) ...[
            const SizedBox(height: 6),
            Text(
              subheading!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.9)),
            ),
          ],
          const SizedBox(height: 18),
          form,
        ],
      ),
    );
  }

  Widget _desktop() {
    return Center(
      child: SizedBox(
        width: 1140,
        child: Row(
          children: [
            Expanded(flex: 5, child: _hero(desktop: true)),
            const SizedBox(width: 40),
            Expanded(flex: 4, child: _panel(width: 440)),
          ],
        ),
      ),
    );
  }

  Widget _mobile(double maxHeight) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: maxHeight),
        child: Builder(
          builder: (context) {
            // Add padding to account for bottom navigation bar on mobile
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final viewPadding = MediaQuery.of(context).padding.bottom;
            final totalBottomPadding = 32 + bottomInset + (viewPadding > 0 ? viewPadding + 16 : 0);
            
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 32,
                bottom: totalBottomPadding,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _hero(desktop: false),
                    const SizedBox(height: 20),
                    _panel(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
