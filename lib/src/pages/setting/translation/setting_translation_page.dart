import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../service/image_translation_service.dart';
import '../../../service/translation_runtime_service.dart';
import '../../../setting/translation_setting.dart';
import '../../../utils/toast_util.dart';

class SettingTranslationPage extends StatefulWidget {
  const SettingTranslationPage({super.key});

  @override
  State<SettingTranslationPage> createState() => _SettingTranslationPageState();
}

class _SettingTranslationPageState extends State<SettingTranslationPage> {
  late final TextEditingController serviceUrlController;
  late final TextEditingController apiTokenController;
  late final TextEditingController deepSeekApiKeyController;
  late final TextEditingController sourceLanguageController;
  late final TextEditingController targetLanguageController;
  late final TextEditingController timeoutController;
  bool testing = false;
  late String translationProvider;
  late String deepSeekModel;

  @override
  void initState() {
    super.initState();
    translationRuntimeService.refreshRuntime();
    serviceUrlController = TextEditingController(
      text: translationSetting.serviceUrl.value,
    );
    apiTokenController = TextEditingController(
      text: translationSetting.apiToken.value,
    );
    deepSeekApiKeyController = TextEditingController(
      text: translationSetting.deepSeekApiKey.value,
    );
    translationProvider = translationSetting.translationProvider.value;
    deepSeekModel = translationSetting.deepSeekModel.value;
    sourceLanguageController = TextEditingController(
      text: translationSetting.sourceLanguage.value,
    );
    targetLanguageController = TextEditingController(
      text: translationSetting.targetLanguage.value,
    );
    timeoutController = TextEditingController(
      text: translationSetting.requestTimeoutSeconds.value.toString(),
    );
  }

  @override
  void dispose() {
    serviceUrlController.dispose();
    apiTokenController.dispose();
    deepSeekApiKeyController.dispose();
    sourceLanguageController.dispose();
    targetLanguageController.dispose();
    timeoutController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    await translationSetting.save(
      serviceUrl: serviceUrlController.text,
      apiToken: apiTokenController.text,
      translationProvider: translationProvider,
      deepSeekApiKey: deepSeekApiKeyController.text,
      deepSeekModel: deepSeekModel,
      sourceLanguage: sourceLanguageController.text,
      targetLanguage: targetLanguageController.text,
      requestTimeoutSeconds: int.tryParse(timeoutController.text) ?? 300,
    );
    toast('saveSuccess'.tr);
  }

  Future<void> testConnection() async {
    await save();
    setState(() => testing = true);
    final bool success = await imageTranslationService.testConnection();
    if (mounted) {
      setState(() => testing = false);
    }
    toast(
      success
          ? 'translationServiceConnected'.tr
          : 'translationServiceUnavailable'.tr,
      isShort: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('imageTranslation'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('translationServiceHint'.tr),
            const SizedBox(height: 20),
            if (GetPlatform.isWindows) ...[
              GetBuilder<TranslationRuntimeService>(
                init: translationRuntimeService,
                id: TranslationRuntimeService.updateId,
                builder: (runtime) => Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              runtime.status == TranslationRuntimeStatus.ready
                                  ? Icons.check_circle
                                  : runtime.status ==
                                          TranslationRuntimeStatus.error
                                      ? Icons.error_outline
                                      : Icons.downloading_outlined,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'translationRuntimeTitle'.tr,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(runtime.message),
                        if (runtime.isBusy) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                              value: runtime.progress > 0
                                  ? runtime.progress / 100
                                  : null),
                          const SizedBox(height: 6),
                          Text('${runtime.progress}%'),
                        ],
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: runtime.isBusy
                              ? null
                              : runtime.isInitialized
                                  ? runtime.start
                                  : runtime.initialize,
                          icon: Icon(runtime.isInitialized
                              ? Icons.play_arrow
                              : Icons.download),
                          label: Text(
                            runtime.isInitialized
                                ? 'startTranslationRuntime'.tr
                                : 'initializeTranslationRuntime'.tr,
                          ),
                        ),
                        if (!runtime.isInitialized) ...[
                          const SizedBox(height: 8),
                          Text(
                            'translationRuntimeSizeHint'.tr,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            TextField(
              controller: serviceUrlController,
              decoration: InputDecoration(
                labelText: 'translationServiceUrl'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: apiTokenController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'translationApiToken'.tr,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: translationProvider,
              decoration: InputDecoration(
                labelText: 'translationProvider'.tr,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'deepseek',
                  child: Text('deepSeekApi'.tr),
                ),
                DropdownMenuItem(
                  value: 'sugoi',
                  child: Text('sugoiLocal'.tr),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => translationProvider = value);
                }
              },
            ),
            if (translationProvider == 'deepseek') ...[
              const SizedBox(height: 16),
              TextField(
                controller: deepSeekApiKeyController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'deepSeekApiKey'.tr,
                  helperText: 'deepSeekApiKeyHint'.tr,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: deepSeekModel,
                decoration: InputDecoration(
                  labelText: 'deepSeekModel'.tr,
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'deepseek-v4-flash',
                    child: Text('DeepSeek V4 Flash'),
                  ),
                  DropdownMenuItem(
                    value: 'deepseek-v4-pro',
                    child: Text('DeepSeek V4 Pro'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => deepSeekModel = value);
                  }
                },
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: sourceLanguageController,
                    decoration: InputDecoration(
                      labelText: 'sourceLanguage'.tr,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: targetLanguageController,
                    decoration: InputDecoration(
                      labelText: 'targetLanguage'.tr,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: timeoutController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'translationTimeout'.tr,
                suffixText: 's',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(Icons.save),
              label: Text('saveTranslationSettings'.tr),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: testing ? null : testConnection,
              icon: testing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.health_and_safety_outlined),
              label: Text('testConnection'.tr),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () async {
                await imageTranslationService.clearCache();
                toast('translationCacheCleared'.tr);
              },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text('clearTranslationCache'.tr),
            ),
          ],
        ),
      ),
    );
  }
}
