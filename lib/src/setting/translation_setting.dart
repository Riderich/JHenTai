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
  RxString translationProvider = 'openai_compatible'.obs;
  RxString apiBaseUrl = 'https://api.deepseek.com'.obs;
  RxString apiKey = ''.obs;
  RxString apiModel = 'deepseek-v4-flash'.obs;
  RxBool disableThinking = true.obs;
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
    final String savedProvider =
        map['translationProvider'] ?? translationProvider.value;
    translationProvider.value =
        savedProvider == 'deepseek' ? 'openai_compatible' : savedProvider;
    apiBaseUrl.value = map['apiBaseUrl'] ?? apiBaseUrl.value;
    apiKey.value = map['apiKey'] ?? map['deepSeekApiKey'] ?? apiKey.value;
    apiModel.value = map['apiModel'] ?? map['deepSeekModel'] ?? apiModel.value;
    disableThinking.value = map['disableThinking'] ?? disableThinking.value;
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
      'apiBaseUrl': apiBaseUrl.value,
      'apiKey': apiKey.value,
      'apiModel': apiModel.value,
      'disableThinking': disableThinking.value,
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
    required String apiBaseUrl,
    required String apiKey,
    required String apiModel,
    required bool disableThinking,
    required String sourceLanguage,
    required String targetLanguage,
    required int requestTimeoutSeconds,
  }) async {
    this.serviceUrl.value = _normalizeServiceUrl(serviceUrl);
    this.apiToken.value = apiToken.trim();
    this.translationProvider.value = translationProvider;
    this.apiBaseUrl.value = _normalizeApiBaseUrl(apiBaseUrl);
    this.apiKey.value = apiKey.trim();
    this.apiModel.value =
        apiModel.trim().isEmpty ? 'deepseek-v4-flash' : apiModel.trim();
    this.disableThinking.value = disableThinking;
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

  String _normalizeApiBaseUrl(String value) {
    String result = value.trim();
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result.isEmpty ? 'https://api.deepseek.com' : result;
  }
}
