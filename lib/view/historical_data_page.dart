import 'package:flutter/material.dart';
import '../util/navbar.dart';
import '../util/navbar_back_button.dart';

class HistoricalDataPage extends StatelessWidget {
  final String role;
  final int userId;

  const HistoricalDataPage({
    Key? key,
    required this.role,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      drawer: isMobile
          ? Navbar(
        selectedIndex: 4,
        onItemSelected: (_) {},
        role: role,
        userId: userId,
      )
          : null,

      appBar: null,

      body: Stack(
        children: [
          SafeArea(
            child: Row(
              children: [
                if (!isMobile)
                  Navbar(
                    selectedIndex: 4,
                    onItemSelected: (_) {},
                    role: role,
                    userId: userId,
                  ),

                Expanded(
                  child: Column(
                    children: [
                      if (isMobile) _mobileHeader(context),
                      if (!isMobile) _desktopHeader(),

                      const Expanded(
                        child: Center(
                          child: Text(
                            "Historical analysis wiring will be added after archive + summaries.",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (!isMobile)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 285,
              child: const NavbarBackButton(),
            ),
        ],
      ),
    );
  }


  Widget _mobileHeader(BuildContext context) {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            left: 64,
            right: 64,
            child: Center(
              child: Text(
                "Historical Data Analysis",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 6,
            bottom: 6,
            child: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _desktopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black12, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: const [
          Text(
            "Historical Data Analysis",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 18),
        ],
      ),
    );
  }
}