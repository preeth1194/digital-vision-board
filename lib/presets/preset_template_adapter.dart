import 'package:flutter/material.dart';

import '../models/action_step_template.dart';
import 'models/preset_template_config.dart';

abstract class PresetTemplateAdapter {
  const PresetTemplateAdapter();

  bool supportsTemplate(ActionStepTemplate template);

  PresetTemplateConfig buildConfig(ActionStepTemplate template);

  Future<ActionStepTemplate?> openEditor(
    BuildContext context,
    ActionStepTemplate template,
  );
}
