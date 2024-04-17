import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webapp/api.dart' as A;
import 'package:webapp/base_model.dart';
import 'package:webapp/components/message.dart';
import 'package:webapp/components/presets.dart';
import 'package:webapp/config.dart';

class HomeModel extends BaseModel {
  A.BackendInfo? backendInfo;
  List<A.ModelInfo> modelInfos = [];
  String? model;
  List<A.ModelOutput> outputs = [];

  bool chatMode = false;

  Map<String, Constraint> constraints = {};

  String? constraint;

  Queue<Message> messages = Queue();

  late TextEditingController inputController;

  late TextEditingController regexController;

  late TextEditingController grammarController;
  late TextEditingController lexerController;

  bool get validModel =>
      model != null &&
      modelInfos.indexWhere((info) => info.name == model!) != -1;

  bool _ready = false;

  bool get ready => _ready;

  bool get available => modelInfos.isNotEmpty;

  bool _waiting = false;

  bool get waiting => _waiting;

  bool get hasResults => outputs.isNotEmpty;

  bool get hasInput => inputController.text.isNotEmpty;

  bool sampling = true;

  Future<void> init(
    TextEditingController inputController,
    TextEditingController regexController,
    TextEditingController grammarController,
    TextEditingController lexerController,
  ) async {
    this.inputController = inputController;
    this.regexController = regexController;

    this.grammarController = grammarController;
    this.lexerController = lexerController;

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
    model = prefs.getString("model");
    chatMode = prefs.getBool("chatMode") ?? false;
    sampling = prefs.getBool("sampling") ?? true;
    if (!validModel) {
      model = modelInfos.firstOrNull?.name;
    }

    _ready = true;
    notifyListeners();
  }

  saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (model != null) {
      await prefs.setString("model", model!);
    } else {
      await prefs.remove("model");
    }
    await prefs.setBool("chatMode", chatMode);
    await prefs.setBool("sampling", sampling);
  }

  bool isValidPreset(Preset preset) {
    return modelInfos.indexWhere((info) => info.name == preset.model) != -1;
  }

  List<Map<String, String>> getChat(String inputString) {
    return outputs
            .map(
              (output) => [
                {"role": "user", "text": output.input},
                {"role": "assistant", "text": output.output}
              ],
            )
            .flattened
            .toList() +
        [
          {"role": "user", "text": inputString}
        ];
  }

  Future<void> run(String inputString) async {
    final stop = Stopwatch()..start();
    _waiting = true;
    if (!chatMode) {
      outputs.clear();
    }
    notifyListeners();

    Constraint? ct = constraints[constraint];
    if (constraint == customRegexConstraint) {
      ct = Constraint.withRegex(regexController.text);
    } else if (constraint == customCfgConstraint) {
      ct = Constraint.withGrammar(
        grammarController.text,
        lexerController.text,
      );
    }

    final stream = await A.api.generate(
      inputString,
      chatMode ? getChat(inputString) : null,
      model!,
      sampling,
      ct,
    );
    if (stream == null) {
      messages.add(Message("failed to get response", Status.error));
    } else {
      bool added = false;
      stream.listen(
        (data) async {
          try {
            final json = jsonDecode(data);
            if (json.containsKey("error")) {
              messages.add(Message(json["error"], Status.error));
              notifyListeners();
              return;
            }
            final output = A.ModelOutput(
              inputString,
              json["output"],
              A.Runtime.fromJson(
                json["runtime"],
                stop.elapsed.inMilliseconds / 1000,
              ),
            );
            if (outputs.isEmpty || !added) {
              outputs.add(output);
              added = true;
            } else {
              outputs.last = output;
            }
            notifyListeners();
          } catch (e) {
            return;
          }
        },
        onError: (_) {},
        cancelOnError: true,
      );
    }
    _waiting = false;
    notifyListeners();
  }
}
