import 'package:device_apps/device_apps.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'apps_cubit.dart';

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
      debugShowCheckedModeBanner: false,
      home: BlocProvider(
        create: (context) => AppsCubit(),
        child: const LauncherScreen(),
      ),
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
      onKey: (e) {
        if (e is RawKeyDownEvent) {
          switch (e.logicalKey.keyLabel) {
            case 'Arrow Up':
              context.read<AppsCubit>().handleKeyUp();
              break;
            case 'Arrow Down':
              context.read<AppsCubit>().handleKeyDown();
              break;
            case 'Arrow Left':
              context.read<AppsCubit>().handleKeyLeft();
              break;
            case 'Arrow Right':
              context.read<AppsCubit>().handleKeyRight();
              break;
            case 'Select':
              var state = context.read<AppsCubit>().state;
              if (state.applications == null || state.selectedIndex == null) {
                return;
              }

              DeviceApps.openApp(
                state.applications![state.selectedIndex!].packageName,
              );
              break;
            default:
          }
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
                child: Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('background.jpg'),
                      fit: BoxFit.cover,
                      isAntiAlias: true,
                      colorFilter: ColorFilter.mode(
                        Color(0xFF222222),
                        BlendMode.hardLight,
                      ),
                    ),
                  ),
                ),
              ),
              BlocBuilder<AppsCubit, AppsState>(
                builder: (context, state) {
                  if (state.applications != null) {
                    return GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                      ),
                      itemCount: state.applications!.length,
                      itemBuilder: (context, index) {
                        final app = state.applications![index];
                        return GestureDetector(
                          onTap: () {
                            DeviceApps.openApp(app.packageName);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: index == state.selectedIndex
                                  ? Colors.black.withOpacity(0.85)
                                  : null,
                              borderRadius: BorderRadius.circular(16),
                              border: index == state.selectedIndex
                                  ? Border.all(color: Colors.white, width: 1)
                                  : null,
                            ),
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                app is ApplicationWithIcon
                                    ? Expanded(
                                        child: Image.memory(
                                          app.icon,
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                                Text(
                                  app.appName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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
              // FutureBuilder(
              //   future: DeviceApps.getInstalledApplications(
              //     includeAppIcons: true,
              //     includeSystemApps: true,
              //     onlyAppsWithLaunchIntent: true,
              //   ),
              //   builder: (context, AsyncSnapshot<List<Application>> snapshot) {
              //     if (snapshot.connectionState == ConnectionState.done &&
              //         snapshot.data != null) {
              //       return ;
              //     }

              //     return const Center(
              //       child: CircularProgressIndicator(),
              //     );
              //   },
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
