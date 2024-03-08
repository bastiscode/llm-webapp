import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webapp/api.dart' as A;
import 'package:webapp/base_model.dart';
import 'package:webapp/components/message.dart';
import 'package:webapp/components/presets.dart';
import 'package:webapp/config.dart';
import 'package:webapp/utils.dart';

class HomeModel extends BaseModel {
  A.BackendInfo? backendInfo;
  List<A.ModelInfo> modelInfos = [];
  String? model;
  A.ModelOutput? output;

  Map<String, Constraint> constraints = {};

  String? constraint;

  int _inputBytes = 0;

  int get inputBytes => _inputBytes;

  Queue<Message> messages = Queue();

  late TextEditingController inputController;

  bool get validModel =>
      model != null &&
      modelInfos.indexWhere((info) => info.name == model!) != -1;

  bool _ready = false;

  bool get ready => _ready;

  bool get available => modelInfos.isNotEmpty;

  bool _waiting = false;

  bool get waiting => _waiting;

  bool get hasResults => output != null;

  double get totalClientRuntime => output?.runtime.clientS ?? 0.0;

  double get totalBackendRuntime => output?.runtime.backendS ?? 0.0;

  bool get hasInput => inputController.text.isNotEmpty;

  bool hideModel = false;

  bool hq = false;

  Future<void> init(
    TextEditingController inputController,
  ) async {
    this.inputController = inputController;

    constraints = await loadConstraints();

    final modelRes = await A.api.models();
    if (modelRes.value != null) {
      modelInfos = modelRes.value!;
    }

    final infoRes = await A.api.info();
    if (infoRes.value != null) {
      backendInfo = infoRes.value!;
    }

    final prefs = await SharedPreferences.getInstance();
    hideModel = prefs.getBool("hideModel") ?? false;
    model = prefs.getString("model");
    if (!validModel) {
      model = null;
      hideModel = false;
    }

    _ready = true;
    notifyListeners();
  }

  saveModel() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString("model", model!);
    prefs.setBool("hideModel", hideModel);
  }

  bool isValidPreset(Preset preset) {
    return modelInfos.indexWhere((info) => info.name == preset.model) != -1;
  }

  Future<void> run(String inputString) async {
    _waiting = true;
    output = null;
    notifyListeners();
    final result = await A.api.generateText(
      [inputString],
      model!,
      hq,
      constraints[constraint]
    );
    if (result.statusCode == 200) {
      output = result.value!;
      _inputBytes = numBytes(inputString);
    } else {
      messages.add(A.errorMessageFromApiResult(result));
    }
    _waiting = false;
    notifyListeners();
  }
}
