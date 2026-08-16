import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

import '../model/gallery_image.dart';
import '../model/read_page_info.dart';
import '../setting/translation_setting.dart';
import 'gallery_download/gallery_download_service.dart';
import 'jh_service.dart';
import 'log.dart';
import 'path_service.dart';

enum ImageTranslationStatus { idle, translating, success, error }

class ImageTranslationEntry {
  ImageTranslationStatus status;
  String? relativePath;
  String? error;

  ImageTranslationEntry({
    this.status = ImageTranslationStatus.idle,
    this.relativePath,
    this.error,
  });
}

ImageTranslationService imageTranslationService = ImageTranslationService();

class ImageTranslationService extends GetxController
    with JHLifeCircleBeanErrorCatch
    implements JHLifeCircleBean {
  static const String updateIdPrefix = 'imageTranslation';

  final Map<String, ImageTranslationEntry> _entries = {};
  late Directory _cacheDirectory;

  @override
  List<JHLifeCircleBean> get initDependencies => [
        pathService,
        log,
        translationSetting,
      ];

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
    _cacheDirectory = Directory(
      path.join(pathService.getVisibleDir().path, 'translation_cache'),
    );
    await _cacheDirectory.create(recursive: true);
    super.onInit();
  }

  @override
  Future<void> doAfterBeanReady() async {}

  String updateId(ReadPageInfo info, int index) =>
      '$updateIdPrefix::${_pageKey(info, index)}';

  ImageTranslationEntry entry(ReadPageInfo info, int index) {
    final String key = _pageKey(info, index);
    return _entries.putIfAbsent(key, () {
      final String? cachedPath = _findCachedRelativePath(info, index);
      return ImageTranslationEntry(
        status: cachedPath == null
            ? ImageTranslationStatus.idle
            : ImageTranslationStatus.success,
        relativePath: cachedPath,
      );
    });
  }

  GalleryImage translatedImageOrOriginal(
    ReadPageInfo info,
    int index,
    GalleryImage original, {
    required bool showTranslated,
  }) {
    if (!showTranslated) {
      return original;
    }
    final ImageTranslationEntry current = entry(info, index);
    if (current.status != ImageTranslationStatus.success ||
        current.relativePath == null) {
      return original;
    }
    return original.copyWith(
      path: current.relativePath,
      downloadStatus: DownloadStatus.downloaded,
    );
  }

  Future<void> translate({
    required ReadPageInfo info,
    required int index,
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final String key = _pageKey(info, index);
    final ImageTranslationEntry current = entry(info, index);
    if (current.status == ImageTranslationStatus.translating) {
      return;
    }

    current
      ..status = ImageTranslationStatus.translating
      ..error = null;
    update([updateId(info, index)]);

    try {
      final Duration timeout = Duration(
        seconds: translationSetting.requestTimeoutSeconds.value,
      );
      final Dio client = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          sendTimeout: timeout,
          receiveTimeout: timeout,
          responseType: ResponseType.bytes,
          headers: {
            if (translationSetting.apiToken.value.isNotEmpty)
              'Authorization': 'Bearer ${translationSetting.apiToken.value}',
          },
        ),
      );
      final FormData body = FormData.fromMap({
        'image': MultipartFile.fromBytes(imageBytes, filename: fileName),
        'gallery_id': _galleryKey(info),
        'page_index': index,
        'source_language': translationSetting.sourceLanguage.value,
        'target_language': translationSetting.targetLanguage.value,
      });
      final Response<List<int>> response = await client.post<List<int>>(
        '${translationSetting.serviceUrl.value}/v1/translate',
        data: body,
        options: Options(responseType: ResponseType.bytes),
      );
      final List<int>? translatedBytes = response.data;
      if (translatedBytes == null || translatedBytes.isEmpty) {
        throw StateError('Translation service returned an empty image');
      }

      final String extension = _extensionFromContentType(
        response.headers.value(Headers.contentTypeHeader),
      );
      final String relativePath = _cacheRelativePath(info, index, extension);
      final File output = File(
        path.join(pathService.getVisibleDir().path, relativePath),
      );
      await output.create(recursive: true);
      await output.writeAsBytes(translatedBytes, flush: true);

      current
        ..status = ImageTranslationStatus.success
        ..relativePath = relativePath
        ..error = null;
      log.info('Translated page cached: $key -> $relativePath');
    } catch (e, stack) {
      current
        ..status = ImageTranslationStatus.error
        ..error = e.toString();
      log.error('Translate page failed: $key', e, stack);
      rethrow;
    } finally {
      update([updateId(info, index)]);
    }
  }

  Future<bool> testConnection() async {
    try {
      final Dio client = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final Response response = await client.get(
        '${translationSetting.serviceUrl.value}/health',
      );
      return response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
    } catch (e) {
      log.warning('Image translation service health check failed', e);
      return false;
    }
  }

  Future<void> clearCache() async {
    final List<String> updateIds =
        _entries.keys.map((key) => '$updateIdPrefix::$key').toList();
    if (await _cacheDirectory.exists()) {
      await _cacheDirectory.delete(recursive: true);
    }
    await _cacheDirectory.create(recursive: true);
    _entries.clear();
    if (updateIds.isNotEmpty) {
      update(updateIds);
    }
  }

  String _galleryKey(ReadPageInfo info) {
    return info.gid != null
        ? '${info.gid}_${info.token ?? ''}'
        : info.readProgressRecordStorageKey;
  }

  String _pageKey(ReadPageInfo info, int index) =>
      '${_galleryKey(info)}::$index::${translationSetting.targetLanguage.value}';

  String _cacheBaseName(ReadPageInfo info, int index) {
    final String identity =
        '${_galleryKey(info)}::$index::${translationSetting.sourceLanguage.value}::${translationSetting.targetLanguage.value}';
    return sha256.convert(utf8.encode(identity)).toString();
  }

  String _cacheRelativePath(ReadPageInfo info, int index, String extension) {
    return path.join(
      'translation_cache',
      '${_cacheBaseName(info, index)}.$extension',
    );
  }

  String? _findCachedRelativePath(ReadPageInfo info, int index) {
    for (final String extension in const ['png', 'jpg', 'webp']) {
      final String relativePath = _cacheRelativePath(info, index, extension);
      if (File(
        path.join(pathService.getVisibleDir().path, relativePath),
      ).existsSync()) {
        return relativePath;
      }
    }
    return null;
  }

  String _extensionFromContentType(String? contentType) {
    if (contentType?.contains('webp') == true) {
      return 'webp';
    }
    if (contentType?.contains('jpeg') == true ||
        contentType?.contains('jpg') == true) {
      return 'jpg';
    }
    return 'png';
  }
}
