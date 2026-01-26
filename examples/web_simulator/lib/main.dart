import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'src/simulated_environment.dart';
import 'src/views/app_pane.dart';
import 'src/views/debugger_pane.dart';

void main() {
  runApp(const SimulatorApp());
}

class SimulatorApp extends StatelessWidget {
  const SimulatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth Service Simulator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: ThemeMode.system,
      home: const SimulatorHome(),
    );
  }
}

class SimulatorHome extends StatefulWidget {
  const SimulatorHome({super.key});

  @override
  State<SimulatorHome> createState() => _SimulatorHomeState();
}

class _SimulatorHomeState extends State<SimulatorHome> {
  final SimulatedEnvironment _env = SimulatedEnvironment();

  @override
  Widget build(BuildContext context) {
    return SimulationProvider(
      env: _env,
      child: ListenableBuilder(
        listenable: _env,
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              // Mobile Layout
              if (constraints.maxWidth < 900) {
                return DefaultTabController(
                  length: 2,
                  child: Scaffold(
                    appBar: AppBar(
                      title: const Text('Auth Simulator'),
                      bottom: const TabBar(
                        tabs: [
                          Tab(text: 'App', icon: Icon(Icons.touch_app)),
                          Tab(text: 'Debugger', icon: Icon(Icons.bug_report)),
                        ],
                      ),
                    ),
                    body: const SelectionArea(
                      child: TabBarView(children: [AppPane(), DebuggerPane()]),
                    ),
                  ),
                );
              }

              // Desktop/Tablet Layout
              return Scaffold(
                body: SelectionArea(
                  child: Row(
                    children: [
                      const Expanded(flex: 2, child: AppPane()),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 3, child: DebuggerPane()),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class SimulationProvider extends InheritedWidget {
  final SimulatedEnvironment env;

  const SimulationProvider({
    super.key,
    required this.env,
    required super.child,
  });

  static SimulatedEnvironment of(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<SimulationProvider>();
    assert(result != null, 'No SimulationProvider found in context');
    return result!.env;
  }

  @override
  bool updateShouldNotify(SimulationProvider oldWidget) => env != oldWidget.env;
}
