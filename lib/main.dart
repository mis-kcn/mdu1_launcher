import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MDU1 Launcher',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      home: const LauncherScreen(),
    );
  }
}

class LauncherScreen extends StatelessWidget {
  const LauncherScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final node = FocusNode();

    return RawKeyboardListener(
      focusNode: node,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          print(event.logicalKey.keyLabel.toString());
        }
      },
      child: WillPopScope(
        onWillPop: () async {
          DeviceApps.openApp('tv.mdu1.iptv');

          return false;
        },
        child: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'background.jpg',
                  fit: BoxFit.cover,
                ),
              ),
              FutureBuilder(
                future: DeviceApps.getInstalledApplications(
                  includeAppIcons: true,
                  includeSystemApps: true,
                  onlyAppsWithLaunchIntent: true,
                ),
                builder: (context, AsyncSnapshot<List<Application>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.data != null) {
                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                      ),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final app = snapshot.data![index];
                        return GestureDetector(
                          onTap: () {
                            DeviceApps.openApp(app.packageName);
                          },
                          child: GridTile(
                            header: app is ApplicationWithIcon
                                ? Image.memory(
                                    app.icon,
                                  )
                                : null,
                            footer: Center(
                              child: Text(
                                snapshot.data![index].appName,
                                textAlign: TextAlign.center,
                              ),
                            ),
                            child: SizedBox.shrink(),
                          ),
                        );
                      },
                    );
                  }

                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
