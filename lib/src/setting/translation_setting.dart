import 'dart:convert';

import 'package:get/get.dart';

import '../enum/config_enum.dart';
import '../service/jh_service.dart';
import '../service/log.dart';

TranslationSetting translationSetting = TranslationSetting();

class TranslationSetting
    with JHLifeCircleBeanWithConfigStorage
    implements JHLifeCircleBean {
  RxString serviceUrl = 'http://127.0.0.1:5100'.obs;
  RxString apiToken = ''.obs;
  RxString translationProvider = 'deepseek'.obs;
  RxString deepSeekApiKey = ''.obs;
  RxString deepSeekModel = 'deepseek-v4-flash'.obs;
  RxString sourceLanguage = 'auto'.obs;
  RxString targetLanguage = 'zh-CN'.obs;
  RxInt requestTimeoutSeconds = 300.obs;

  @override
  ConfigEnum get configEnum => ConfigEnum.translationSetting;

  @override
  void applyBeanConfig(String configString) {
    final Map<String, dynamic> map = jsonDecode(configString);
    serviceUrl.value = map['serviceUrl'] ?? serviceUrl.value;
    apiToken.value = map['apiToken'] ?? apiToken.value;
    translationProvider.value =
        map['translationProvider'] ?? translationProvider.value;
    deepSeekApiKey.value = map['deepSeekApiKey'] ?? deepSeekApiKey.value;
    deepSeekModel.value = map['deepSeekModel'] ?? deepSeekModel.value;
    sourceLanguage.value = map['sourceLanguage'] ?? sourceLanguage.value;
    targetLanguage.value = map['targetLanguage'] ?? targetLanguage.value;
    requestTimeoutSeconds.value =
        map['requestTimeoutSeconds'] ?? requestTimeoutSeconds.value;
  }

  @override
  String toConfigString() {
    return jsonEncode({
      'serviceUrl': serviceUrl.value,
      'apiToken': apiToken.value,
      'translationProvider': translationProvider.value,
      'deepSeekApiKey': deepSeekApiKey.value,
      'deepSeekModel': deepSeekModel.value,
      'sourceLanguage': sourceLanguage.value,
      'targetLanguage': targetLanguage.value,
      'requestTimeoutSeconds': requestTimeoutSeconds.value,
    });
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  Future<void> save({
    required String serviceUrl,
    required String apiToken,
    required String translationProvider,
    required String deepSeekApiKey,
    required String deepSeekModel,
    required String sourceLanguage,
    required String targetLanguage,
    required int requestTimeoutSeconds,
  }) async {
    this.serviceUrl.value = _normalizeServiceUrl(serviceUrl);
    this.apiToken.value = apiToken.trim();
    this.translationProvider.value = translationProvider;
    this.deepSeekApiKey.value = deepSeekApiKey.trim();
    this.deepSeekModel.value = deepSeekModel;
    this.sourceLanguage.value =
        sourceLanguage.trim().isEmpty ? 'auto' : sourceLanguage.trim();
    this.targetLanguage.value =
        targetLanguage.trim().isEmpty ? 'zh-CN' : targetLanguage.trim();
    this.requestTimeoutSeconds.value =
        requestTimeoutSeconds.clamp(10, 1800).toInt();
    log.info('Save image translation settings: ${this.serviceUrl.value}');
    await saveBeanConfig();
  }

  String _normalizeServiceUrl(String value) {
    String result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result.isEmpty ? 'http://127.0.0.1:5100' : result;
  }
}
