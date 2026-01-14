import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider? fileImageProviderFromPath(String path) => FileImage(File(path));

