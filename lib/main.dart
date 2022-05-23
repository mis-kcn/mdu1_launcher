import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_apps/device_apps.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

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
      navigatorObservers: [FlutterSmartDialog.observer],
      builder: FlutterSmartDialog.init(),
    );
  }
}

class LauncherScreen extends StatefulWidget {
  const LauncherScreen({Key? key}) : super(key: key);

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen>
    with WidgetsBindingObserver {
  DateTime? lastCheckExpiration;
  AppLifecycleState? _notification;
  late AutoScrollController controller;
  bool isFirstTimeBooting = true;

  final Connectivity _connectivity = Connectivity();
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = AutoScrollController(
      viewportBoundaryGetter: () =>
          Rect.fromLTRB(0, 0, 0, MediaQuery.of(context).padding.bottom),
      axis: Axis.vertical,
    );

    openIptv();
    initConnectivity();

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> openIptv() async {
    await LaunchApp.openApp(
      androidPackageName: 'tv.mdu1.iptv',
    );
  }

  Future<void> fetchOtaUpdate() async {
    try {
      setState(() {
        lastCheckExpiration = DateTime.now().add(const Duration(minutes: 1));
      });

      final deviceInfoPlugin = DeviceInfoPlugin();
      final packageInfoPlugin = await PackageInfo.fromPlatform();
      final androidVersion = await deviceInfoPlugin.androidInfo;

      final resp = await http.post(
        Uri.parse('https://smoggy-fifth-tub.glitch.me/apiv2/launcher/upgrade'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'api_version': androidVersion.version.sdkInt.toString(),
          'app_version': packageInfoPlugin.version,
        }),
      );

      if (resp.statusCode != 200) {
        if (!isFirstTimeBooting) return;

        if (resp.statusCode == 401) {
          await SmartDialog.showToast(
            'Minimum app version is greater than your current app version.',
            time: const Duration(seconds: 5),
          );
        } else {
          if (resp.statusCode == 404) {
            await SmartDialog.showToast(
              'Your launcher is up to date. (v.${packageInfoPlugin.version})',
              time: const Duration(seconds: 5),
            );
          }
        }
        return;
      }

      SmartDialog.showToast(
        'Downloading new update for launcher...',
      );

      OtaUpdate()
          .execute(
        resp.body,
      )
          .listen((event) {
        switch (event.status) {
          case OtaStatus.INSTALLING:
            SmartDialog.showToast(
              'Installing new update for launcher...',
            );
            break;
          case OtaStatus.ALREADY_RUNNING_ERROR:
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
          case OtaStatus.INTERNAL_ERROR:
          case OtaStatus.DOWNLOAD_ERROR:
          case OtaStatus.CHECKSUM_ERROR:
            SmartDialog.showToast(
              'There was a problem updating your launcher.',
            );
            break;
          case OtaStatus.DOWNLOADING:
            break;
        }
      });

      return;
    } catch (e, st) {
      log(
        e.toString(),
        error: st,
      );
      await SmartDialog.showToast(
        'There was a problem fetching new updates.',
        time: const Duration(seconds: 5),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> initConnectivity() async {
    late ConnectivityResult result;

    try {
      result = await _connectivity.checkConnectivity();
    } on PlatformException {
      return;
    }

    if (!mounted) {
      return Future.value(null);
    }

    return _updateConnectionStatus(result);
  }

  Future<void> _updateConnectionStatus(ConnectivityResult result) async {
    setState(() {
      if (result != ConnectivityResult.none) {
        fetchOtaUpdate().then((_) async {
          // await LaunchApp.openApp(
          //   androidPackageName: 'tv.mdu1.iptv',
          // );
          isFirstTimeBooting = false;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_notification?.name == 'paused' && state.name == 'resumed') {
      fetchOtaUpdate();
    }

    setState(() {
      _notification = state;
    });
  }

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
          await LaunchApp.openApp(
            androidPackageName: 'tv.mdu1.iptv',
          );

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
              BlocConsumer<AppsCubit, AppsState>(
                listener: (context, state) {
                  controller.scrollToIndex(
                    state.selectedIndex ?? 0,
                    preferPosition: AutoScrollPosition.middle,
                    duration: const Duration(milliseconds: 1),
                  );
                },
                builder: (context, state) {
                  if (state.applications != null) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(48.0),
                      controller: controller,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                      ),
                      itemCount: state.applications!.length,
                      itemBuilder: (context, index) {
                        final app = state.applications![index];
                        return GestureDetector(
                          onTap: () {
                            DeviceApps.openApp(app.packageName);
                          },
                          child: AutoScrollTag(
                            key: ValueKey(index),
                            controller: controller,
                            index: index,
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
                                          child: Padding(
                                            padding: const EdgeInsets.all(6.0),
                                            child: Image.memory(
                                              app.icon,
                                            ),
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
