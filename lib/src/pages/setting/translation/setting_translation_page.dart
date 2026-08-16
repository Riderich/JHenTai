import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../service/image_translation_service.dart';
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
  late final TextEditingController sourceLanguageController;
  late final TextEditingController targetLanguageController;
  late final TextEditingController timeoutController;
  bool testing = false;

  @override
  void initState() {
    super.initState();
    serviceUrlController = TextEditingController(
      text: translationSetting.serviceUrl.value,
    );
    apiTokenController = TextEditingController(
      text: translationSetting.apiToken.value,
    );
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
    sourceLanguageController.dispose();
    targetLanguageController.dispose();
    timeoutController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    await translationSetting.save(
      serviceUrl: serviceUrlController.text,
      apiToken: apiTokenController.text,
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
