import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

import 'log.dart';
import 'path_service.dart';

enum TranslationRuntimeStatus {
  notInitialized,
  initializing,
  starting,
  ready,
  error
}

TranslationRuntimeService translationRuntimeService =
    TranslationRuntimeService();

class TranslationRuntimeService extends GetxController {
  static const String updateId = 'translationRuntime';

  TranslationRuntimeStatus status = TranslationRuntimeStatus.notInitialized;
  int progress = 0;
  String message = '';
  String? error;
  bool nvidiaAvailable = false;
  bool useCuda = false;
  Process? _engineProcess;
  Process? _adapterProcess;

  Directory get runtimeRoot => Directory(
      path.join(pathService.getVisibleDir().path, 'translation_runtime'));
  bool get isBusy =>
      status == TranslationRuntimeStatus.initializing ||
      status == TranslationRuntimeStatus.starting;
  bool get isInitialized =>
      File(path.join(runtimeRoot.path, 'initialized.txt')).existsSync();

  Future<void> refreshRuntime() async {
    await detectNvidia();
    if (await _isHealthy()) {
      status = TranslationRuntimeStatus.ready;
      progress = 100;
      message = 'translationRuntimeReady'.tr;
    } else {
      status = TranslationRuntimeStatus.notInitialized;
      progress = isInitialized ? 100 : 0;
      message = isInitialized
          ? 'translationRuntimeStopped'.tr
          : 'translationRuntimeNotInitialized'.tr;
    }
    update([updateId]);
  }

  Future<void> detectNvidia() async {
    if (!Platform.isWindows) {
      return;
    }
    try {
      final ProcessResult result = await Process.run('nvidia-smi.exe', ['-L']);
      nvidiaAvailable =
          result.exitCode == 0 && result.stdout.toString().contains('GPU');
      useCuda = useCuda || nvidiaAvailable;
    } catch (_) {
      nvidiaAvailable = false;
    }
    update([updateId]);
  }

  void setUseCuda(bool value) {
    useCuda = value;
    update([updateId]);
  }

  Future<void> startIfInitialized() async {
    if (Platform.isWindows && isInitialized && !isBusy) {
      await start();
    }
  }

  Future<void> initialize() async {
    if (isBusy || !Platform.isWindows) {
      return;
    }
    status = TranslationRuntimeStatus.initializing;
    progress = 0;
    error = null;
    message = 'translationRuntimePreparing'.tr;
    update([updateId]);

    try {
      final Directory bundleRoot = _findBundleRoot();
      final File bootstrap = File(path.join(
          bundleRoot.path, 'translation_service', 'bootstrap_windows.ps1'));
      if (!bootstrap.existsSync()) {
        throw StateError('translationRuntimeBundleMissing'.tr);
      }
      await runtimeRoot.create(recursive: true);
      final Process process = await Process.start(
        'powershell.exe',
        [
          '-NoLogo',
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          bootstrap.path,
          '-RuntimeRoot',
          runtimeRoot.path,
          '-BundleRoot',
          bundleRoot.path,
          '-UseCuda',
          '$useCuda',
        ],
        mode: ProcessStartMode.normal,
        runInShell: false,
      );
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_handleInstallerLine);
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.trim().isNotEmpty) {
          message = line.trim();
          update([updateId]);
        }
      });
      final int exitCode = await process.exitCode;
      if (exitCode != 0) {
        throw ProcessException('powershell.exe', const [], message, exitCode);
      }
      await start();
    } catch (e, stack) {
      status = TranslationRuntimeStatus.error;
      error = e.toString();
      message = error!;
      log.error('Translation runtime initialization failed', e, stack);
      update([updateId]);
    }
  }

  Future<void> start() async {
    if (!isInitialized) {
      await initialize();
      return;
    }
    if (await _isHealthy()) {
      status = TranslationRuntimeStatus.ready;
      progress = 100;
      message = 'translationRuntimeReady'.tr;
      update([updateId]);
      return;
    }
    status = TranslationRuntimeStatus.starting;
    message = 'translationRuntimeStarting'.tr;
    update([updateId]);
    try {
      final String python =
          path.join(runtimeRoot.path, 'venv', 'Scripts', 'python.exe');
      final String engine = path.join(runtimeRoot.path, 'engine');
      final String adapter = path.join(runtimeRoot.path, 'adapter');
      final Map<String, String> environment = Map.of(Platform.environment)
        ..['MT_MODEL_DIR'] = path.join(runtimeRoot.path, 'models')
        ..['PYTHONPATH'] = engine;
      final List<String> engineArguments = [
        'server/main.py',
        '--host',
        '127.0.0.1',
        '--port',
        '8000',
        '--start-instance',
        if (File(path.join(runtimeRoot.path, 'cuda.txt')).existsSync())
          '--use-gpu',
      ];
      _engineProcess = await Process.start(
        python,
        engineArguments,
        workingDirectory: engine,
        environment: environment,
        mode: ProcessStartMode.detachedWithStdio,
      );
      _pipeLogs(_engineProcess!, 'translation-engine');
      _adapterProcess = await Process.start(
        python,
        ['-m', 'uvicorn', 'app:app', '--host', '127.0.0.1', '--port', '5100'],
        workingDirectory: adapter,
        environment: environment,
        mode: ProcessStartMode.detachedWithStdio,
      );
      _pipeLogs(_adapterProcess!, 'translation-adapter');
      for (int attempt = 0; attempt < 30; attempt++) {
        if (await _isHealthy()) {
          status = TranslationRuntimeStatus.ready;
          progress = 100;
          message = 'translationRuntimeReady'.tr;
          update([updateId]);
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      throw TimeoutException('translationRuntimeStartTimeout'.tr);
    } catch (e, stack) {
      status = TranslationRuntimeStatus.error;
      error = e.toString();
      message = error!;
      log.error('Translation runtime start failed', e, stack);
      update([updateId]);
    }
  }

  void _handleInstallerLine(String line) {
    if (!line.startsWith('JHENTAI_STATUS|')) {
      return;
    }
    final List<String> parts = line.split('|');
    if (parts.length < 3) {
      return;
    }
    progress = int.tryParse(parts[1]) ?? progress;
    message = parts.sublist(2).join('|');
    update([updateId]);
  }

  Directory _findBundleRoot() {
    final Directory executableDir = File(Platform.resolvedExecutable).parent;
    final List<Directory> candidates = [
      executableDir.parent,
      executableDir,
      Directory.current,
      Directory.current.parent,
    ];
    for (final Directory candidate in candidates) {
      if (Directory(path.join(candidate.path, 'translation_service'))
              .existsSync() &&
          Directory(path.join(candidate.path, 'translation_engine'))
              .existsSync()) {
        return candidate;
      }
    }
    throw StateError('translationRuntimeBundleMissing'.tr);
  }

  Future<bool> _isHealthy() async {
    try {
      final dio.Response<dynamic> response = await dio.Dio(dio.BaseOptions(
              connectTimeout: const Duration(seconds: 2),
              receiveTimeout: const Duration(seconds: 3)))
          .get<dynamic>('http://127.0.0.1:5100/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _pipeLogs(Process process, String name) {
    process.stdout
        .transform(utf8.decoder)
        .listen((line) => debugPrint('[$name] $line'));
    process.stderr
        .transform(utf8.decoder)
        .listen((line) => debugPrint('[$name] $line'));
  }
}
