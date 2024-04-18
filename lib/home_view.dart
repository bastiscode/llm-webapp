import 'package:collection/collection.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webapp/api.dart' as A;
import 'package:webapp/base_view.dart';
import 'package:webapp/colors.dart';
import 'package:webapp/components/links.dart';
import 'package:webapp/components/message.dart';
import 'package:webapp/components/presets.dart';
import 'package:webapp/config.dart';
import 'package:webapp/home_model.dart';
import 'package:webapp/utils.dart';

Widget wrapScaffold(Widget widget) {
  return SafeArea(child: Scaffold(body: widget));
}

Widget wrapPadding(Widget widget) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
    child: widget,
  );
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final TextEditingController inputController = TextEditingController();
  final TextEditingController regexController = TextEditingController();
  final TextEditingController grammarController = TextEditingController();
  final TextEditingController lexerController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final FocusNode inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    inputController.addListener(() {
      setState(() {});
    });
    inputFocus.requestFocus();
  }

  @override
  void dispose() {
    inputController.dispose();
    grammarController.dispose();
    lexerController.dispose();
    regexController.dispose();
    scrollController.dispose();
    inputFocus.dispose();
    super.dispose();
  }

  Future<void> Function() launchOrMessage(String address) {
    return () async {
      await launchUrl(Uri.parse(address));
    };
  }

  @override
  Widget build(BuildContext homeContext) {
    return BaseView<HomeModel>(
      onModelReady: (model) async {
        await model.init(
          inputController,
          regexController,
          grammarController,
          lexerController,
        );
      },
      builder: (context, model, child) {
        Future.delayed(
          Duration.zero,
          () {
            while (model.messages.isNotEmpty) {
              final message = model.messages.removeFirst();
              showMessage(context, message);
            }
          },
        );
        if (!model.ready) {
          return wrapScaffold(
            const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          );
        } else if (model.ready && !model.available) {
          return wrapScaffold(
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Could not find any models, "
                    "please check your backends and reload.",
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await model.init(
                        inputController,
                        regexController,
                        grammarController,
                        lexerController,
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Reload"),
                  )
                ],
              ),
            ),
          );
        }
        return SafeArea(
          child: Scaffold(
            body: wrapPadding(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  buildHeading(model),
                  const SizedBox(height: 8),
                  Expanded(child: buildOutputs(model)),
                  const SizedBox(height: 8),
                  buildInput(model)
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget buildHeading(HomeModel model) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: links
                      .map((l) => LinkChip(l, launchOrMessage(l.url)))
                      .toList(),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: launchOrMessage(
                      "https://ad.informatik.uni-freiburg.de",
                    ),
                    child: SizedBox(
                      width: 160,
                      child: Image.network(
                        "${A.api.webBaseURL}"
                        "/assets/images/logo.png",
                      ),
                    ),
                  ),
                ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              trailing: Wrap(
                runSpacing: 8,
                spacing: 8,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.info_outlined,
                    ),
                    splashRadius: 16,
                    tooltip: "Show backend information",
                    onPressed: () {
                      if (model.backendInfo == null) {
                        showMessage(
                          context,
                          Message(
                            "backend info not available",
                            Status.warn,
                          ),
                        );
                        return;
                      }
                      showInfoDialog(
                        model.backendInfo!,
                      );
                    },
                  ),
                ],
              ),
              title: const Text(
                title,
                style: TextStyle(fontSize: 22),
              ),
              subtitle: const Text(
                description,
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget inputTextField(HomeModel model) {
    final canRun = model.validModel &&
        !model.generating &&
        inputController.text.isNotEmpty;

    final buttons = [
      IconButton(
        onPressed: canRun
            ? () async {
                final numOutputs = model.outputs.length;
                await model.run(model.inputController.text);
                if ((!model.chatMode && model.outputs.isNotEmpty) ||
                    (model.chatMode && model.outputs.length > numOutputs)) {
                  model.inputController.text = "";
                  model.notifyListeners();
                }
              }
            : null,
        icon: const Icon(Icons.start),
        color: uniBlue,
        tooltip: "Run model on prompt",
        splashRadius: 16,
      ),
      IconButton(
        onPressed: model.generating
            ? () async {
                await model.stop();
              }
            : null,
        icon: const Icon(Icons.stop_circle),
        color: uniBlue,
        tooltip: "Stop generation",
        splashRadius: 16,
      ),
    ];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.enter,
          control: true,
        ): () async {
          if (!canRun) return;
          final numOutputs = model.outputs.length;
          await model.run(model.inputController.text);
          if ((!model.chatMode && model.outputs.isNotEmpty) ||
              (model.chatMode && model.outputs.length > numOutputs)) {
            model.inputController.text = "";
            model.notifyListeners();
          }
        }
      },
      child: TextField(
        controller: model.inputController,
        readOnly: model.generating,
        minLines: 1,
        maxLines: 8,
        keyboardType: TextInputType.multiline,
        focusNode: inputFocus,
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          hintText: "Enter your prompt",
          helperText: model.validModel
              ? model.hasResults
                  ? "${formatRuntime(model.outputs.last.runtime)} with ${model.model!}"
                  : "Running ${model.model!}"
              : "No model selected",
          helperMaxLines: 2,
          suffixIcon: model.inputController.text.contains("\n")
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: buttons,
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: buttons,
                ),
        ),
      ),
    );
  }

  Widget buildInput(HomeModel model) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            inputTextField(model),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    runSpacing: 8,
                    spacing: 8,
                    children: model.constraints.entries.map((pair) {
                          final matching = pair.key == model.constraint;
                          return ChoiceChip(
                            label: Text(pair.key),
                            labelPadding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
                            visualDensity: VisualDensity.compact,
                            selected: matching,
                            onSelected: (_) {
                              if (matching) {
                                model.constraint = null;
                              } else {
                                model.constraint = pair.key;
                              }
                              model.notifyListeners();
                            },
                          );
                        }).toList() +
                        [
                          ChoiceChip(
                            label: const Text(customRegexConstraint),
                            labelPadding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
                            visualDensity: VisualDensity.compact,
                            selected: model.constraint == customRegexConstraint,
                            onSelected: (_) {
                              if (model.constraint == customRegexConstraint) {
                                model.constraint = null;
                              } else {
                                model.constraint = customRegexConstraint;
                                if (regexController.text.isEmpty) {
                                  showConfigurationSheet(model);
                                }
                              }
                              model.notifyListeners();
                            },
                          ),
                          ChoiceChip(
                            label: const Text(customCfgConstraint),
                            labelPadding: const EdgeInsets.fromLTRB(0, 0, 4, 0),
                            visualDensity: VisualDensity.compact,
                            selected: model.constraint == customCfgConstraint,
                            onSelected: (_) {
                              if (model.constraint == customCfgConstraint) {
                                model.constraint = null;
                              } else {
                                model.constraint = customCfgConstraint;
                                if (grammarController.text.isEmpty) {
                                  showConfigurationSheet(model);
                                }
                              }
                              model.notifyListeners();
                            },
                          ),
                        ],
                  ),
                ),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      IconButton(
                        splashRadius: 16,
                        onPressed: () {
                          showConfigurationSheet(model);
                        },
                        tooltip: "Show configuration",
                        icon: const Icon(Icons.settings),
                      ),
                      IconButton(
                        onPressed: !model.generating
                            ? () async {
                                model.outputs.clear();
                                model.notifyListeners();
                              }
                            : null,
                        icon: const Icon(Icons.clear),
                        color: !model.generating ? uniRed : null,
                        tooltip: "Clear ${model.chatMode ? "chat" : "output"}",
                        splashRadius: 16,
                      ),
                      IconButton(
                        icon: Icon(
                          model.chatMode ? Icons.chat : Icons.chat_outlined,
                        ),
                        tooltip:
                            "${model.chatMode ? "Disable" : "Enable"} chat mode",
                        splashRadius: 16,
                        onPressed: () async {
                          model.chatMode = !model.chatMode;
                          await model.saveSettings();
                          model.notifyListeners();
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          model.sampling
                              ? Icons.change_circle
                              : Icons.change_circle_outlined,
                        ),
                        tooltip:
                            "${!model.sampling ? "Disable" : "Enable"} determinism",
                        splashRadius: 16,
                        onPressed: () async {
                          model.sampling = !model.sampling;
                          await model.saveSettings();
                          model.notifyListeners();
                        },
                      ),
                      if (examples.isNotEmpty)
                        IconButton(
                          onPressed: !model.generating
                              ? () async {
                                  final example = await showExamplesDialog(
                                    examples,
                                  );
                                  if (example == null) {
                                    return;
                                  }
                                  if (model.constraints
                                      .containsKey(example[0])) {
                                    model.constraint = example[0];
                                  } else {
                                    model.constraint = null;
                                  }
                                  inputController.value = TextEditingValue(
                                    text: example[1],
                                    composing: TextRange.collapsed(
                                      example.length,
                                    ),
                                  );
                                  inputFocus.requestFocus();
                                  model.notifyListeners();
                                }
                              : null,
                          icon: const Icon(Icons.list),
                          tooltip: "Choose an example prompt",
                          splashRadius: 16,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  showConfigurationSheet(HomeModel model) {
    showModalBottomSheet(
      context: context,
      constraints: BoxConstraints.loose(
        const Size(double.infinity, double.infinity),
      ),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
      ),
      isScrollControlled: true,
      isDismissible: true,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (_, setModalState) {
            String? infoText;
            if (model.validModel) {
              final info = model.modelInfos.firstWhere(
                (info) => info.name == model.model,
              );
              infoText = info.description;
              if (info.tags.isNotEmpty) {
                infoText += " (${info.tags.join(', ')})";
              }
            }
            final validPresets = presets
                .where(
                  (preset) => model.isValidPreset(preset),
                )
                .toList();
            return SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  if (validPresets.isNotEmpty) ...[
                    Presets(
                      presets: validPresets,
                      model: model.model,
                      onSelected: (preset) {
                        if (preset == null) {
                          model.model = null;
                        } else {
                          model.model = preset.model;
                        }
                        setModalState(() {});
                        model.notifyListeners();
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                  DropdownButtonFormField<String>(
                    value: model.model,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.text_snippet_outlined),
                      suffixIcon: IconButton(
                        splashRadius: 16,
                        tooltip: "Clear model",
                        color: uniRed,
                        icon: const Icon(Icons.clear),
                        onPressed: model.validModel
                            ? () async {
                                model.model = null;
                                await model.saveSettings();
                                setModalState(() {});
                                model.notifyListeners();
                              }
                            : null,
                      ),
                      hintText: "Select a model",
                      labelText: "Text generation model",
                      helperMaxLines: 10,
                      helperText: infoText,
                    ),
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                    items: model.modelInfos.map<DropdownMenuItem<String>>(
                      (modelInfo) {
                        return DropdownMenuItem(
                          value: modelInfo.name,
                          child: Text(modelInfo.name),
                        );
                      },
                    ).toList(),
                    onChanged: (String? modelName) async {
                      model.model = modelName;
                      await model.saveSettings();
                      setModalState(() {});
                      model.notifyListeners();
                    },
                  ),
                  if (model.constraint == customRegexConstraint) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: regexController,
                      keyboardType: TextInputType.multiline,
                      minLines: 1,
                      maxLines: 20,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Define your regular expression",
                        helperText: "Regular expression",
                      ),
                    ),
                  ] else if (model.constraint == customCfgConstraint) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: lexerController,
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: 16,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: "Define your lexer",
                              helperText: "Lexer",
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: grammarController,
                            keyboardType: TextInputType.multiline,
                            minLines: 1,
                            maxLines: 16,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: "Define your grammar",
                              helperText: "Grammar",
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget outputCard(String text, bool user) {
    List<Widget> children = [];
    int lastEnd = 0;
    for (final match in RegExp(
      r"```(.*?)```",
      multiLine: true,
      dotAll: true,
      unicode: true,
    ).allMatches(text)) {
      final sub = text.substring(lastEnd, match.start).trim();
      if (sub.isNotEmpty) {
        children.add(SelectableText(sub));
      }
      var code = match.group(1)!;
      final codeLang = languagePattern.firstMatch(code);
      String language = "UNKNOWN";
      if (codeLang != null) {
        language = codeLang.group(1)!;
        code = code.substring(codeLang.end);
      }
      code = code.trim();
      children.addAll([
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.black, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          margin: EdgeInsets.zero,
          child: wrapPadding(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language,
                      textScaler: const TextScaler.linear(0.75),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                      },
                      tooltip: "Copy to clipboard",
                      iconSize: 16,
                      splashRadius: 20,
                      icon: const Icon(Icons.copy),
                    )
                  ],
                ),
                const Divider(thickness: 1, height: 16),
                SelectableText(code)
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ]);
      lastEnd = match.end;
    }
    if (text.length > lastEnd) {
      final sub = text.substring(lastEnd, text.length).trim();
      if (sub.isNotEmpty) {
        children.add(SelectableText(sub));
      }
    } else if (children.isNotEmpty) {
      children.removeLast();
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          user ? Icons.person : Icons.computer,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            margin: EdgeInsets.zero,
            child: wrapPadding(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
          },
          tooltip: "Copy to clipboard",
          iconSize: 18,
          icon: const Icon(Icons.copy),
        )
      ],
    );
  }

  Widget buildOutputs(HomeModel model) {
    return ListView.separated(
      reverse: true,
      separatorBuilder: (_, __) {
        return const SizedBox(height: 8);
      },
      itemBuilder: (_, index) {
        if (model.waiting && index == 0) {
          return const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          );
        } else if (model.waiting) {
          index--;
        }
        final outputIndex = index ~/ 2;
        final output = model.outputs[model.outputs.length - 1 - outputIndex];
        final isOutput = index % 2 == 0;
        return outputCard(
          isOutput ? output.output : output.input,
          !isOutput,
        );
      },
      itemCount: model.outputs.length * 2 + (model.waiting ? 1 : 0),
    );
  }

  showInfoDialog(A.BackendInfo info) async {
    const optionPadding = EdgeInsets.symmetric(vertical: 8, horizontal: 8);
    await showDialog(
      context: context,
      builder: (infoContext) {
        return SimpleDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          clipBehavior: Clip.antiAlias,
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
          title: const Text(
            "Info",
            textAlign: TextAlign.center,
          ),
          children: [
            SimpleDialogOption(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
                elevation: 2,
                child: Column(
                  children: [
                    const SimpleDialogOption(
                      padding: optionPadding,
                      child: Text(
                        "Backend",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    SimpleDialogOption(
                      padding: optionPadding,
                      child: Text(
                        "Timeout: ${info.timeout.toStringAsFixed(2)} seconds",
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SimpleDialogOption(
                      padding: optionPadding,
                      child: Text(
                        "CPU: ${info.cpuInfo}",
                        textAlign: TextAlign.center,
                      ),
                    ),
                    ...info.gpuInfos.mapIndexed(
                      (idx, info) => SimpleDialogOption(
                        padding: optionPadding,
                        child: Text(
                          "GPU ${idx + 1}: $info",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget exampleGroup(
    String groupName,
    List<String> items,
    Function(List<String>) onSelected,
  ) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              visualDensity: VisualDensity.compact,
              title: Text(
                groupName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListView.separated(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (_, idx) {
                return ListTile(
                  visualDensity: VisualDensity.compact,
                  title: Text(items[idx]),
                  subtitle: Text(
                    "Example ${idx + 1}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => onSelected([groupName, items[idx]]),
                  // leading: const Icon(Icons.notes),
                );
              },
              separatorBuilder: (_, __) {
                return const Divider(height: 1);
              },
            )
          ],
        ),
      ),
    );
  }

  Future<List<String>?> showExamplesDialog(
    Map<String, List<String>> examples,
  ) async {
    return await showDialog<List<String>?>(
      context: context,
      builder: (dialogContext) {
        final exampleGroups = examples.entries
            .map((entry) {
              return exampleGroup(
                entry.key,
                entry.value,
                (item) => Navigator.of(dialogContext).pop(item),
              );
            })
            .toList()
            .cast<Widget>();
        return Dialog(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(children: exampleGroups),
            ),
          ),
        );
      },
    );
  }
}
