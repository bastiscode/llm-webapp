import 'dart:math';

import 'package:collection/collection.dart';

import 'package:flutter/material.dart';
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
  final FocusNode inputFocus = FocusNode();

  bool showModelSelection = false;

  @override
  void initState() {
    super.initState();

    inputController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    inputController.dispose();
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
        await model.init(inputController);
        showModelSelection = !model.validModel;
        model.notifyListeners();
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
                      await model.init(inputController);
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
    final canRun =
        model.validModel && !model.waiting && inputController.text.isNotEmpty;
    return Column(
      children: [
        const SizedBox(height: 8),
        TextField(
          controller: model.inputController,
          readOnly: model.waiting,
          onSubmitted: canRun
              ? (text) async {
                  await model.run(text);
                }
              : null,
          keyboardType: TextInputType.multiline,
          minLines: 1,
          maxLines: 10,
          focusNode: inputFocus,
          autofocus: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: "Enter your prompt",
            helperText: model.hasResults
                ? formatRuntime(model.outputs.last.runtime)
                : null,
            helperMaxLines: 2,
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: canRun
                      ? () async {
                          final numOutputs = model.outputs.length;
                          await model.run(
                            model.inputController.text,
                          );
                          if (model.outputs.length > numOutputs) {
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget buildInput(HomeModel model) {
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
    final validPresets =
        presets.where((preset) => model.isValidPreset(preset)).toList();
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  showModelSelection = !showModelSelection;
                });
              },
              icon: Transform.rotate(
                angle: -pi / 2,
                child: Icon(
                  showModelSelection ? Icons.chevron_left : Icons.chevron_right,
                ),
              ),
            ),
            if (showModelSelection) ...[
              const SizedBox(height: 8),
              if (validPresets.isNotEmpty) ...[
                Presets(
                  presets: validPresets,
                  model: model.model,
                  onSelected: (preset) {
                    setState(
                      () {
                        if (preset == null) {
                          model.model = null;
                        } else {
                          model.model = preset.model;
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 8)
              ],
              DropdownButtonFormField<String>(
                value: model.model,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.question_answer_outlined),
                  suffixIcon: IconButton(
                    splashRadius: 16,
                    tooltip: "Clear model",
                    color: uniRed,
                    icon: const Icon(Icons.clear),
                    onPressed: model.validModel
                        ? () {
                            setState(() {
                              model.model = null;
                            });
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
                onChanged: (String? modelName) {
                  if (modelName == null) return;
                  setState(() {
                    model.model = modelName;
                  });
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: model.validModel
                        ? () async {
                            await model.saveModel();
                            setState(() {
                              showMessage(
                                context,
                                Message("Saved model settings", Status.info),
                              );
                            });
                          }
                        : null,
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text("Save model settings"),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            inputTextField(model),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
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
                  }).toList(),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    IconButton(
                      icon: Icon(
                        model.chatMode ? Icons.chat : Icons.chat_outlined,
                      ),
                      tooltip:
                          "${model.chatMode ? "Disable" : "Enable"} chat mode",
                      splashRadius: 16,
                      onPressed: () {
                        setState(
                          () {
                            model.chatMode = !model.chatMode;
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        model.hq
                            ? Icons.high_quality
                            : Icons.high_quality_outlined,
                      ),
                      tooltip:
                          "${model.hq ? "Disable" : "Enable"} high quality",
                      splashRadius: 16,
                      onPressed: () {
                        setState(
                          () {
                            model.hq = !model.hq;
                          },
                        );
                      },
                    ),
                    if (examples.isNotEmpty)
                      IconButton(
                        onPressed: !model.waiting
                            ? () async {
                                final example = await showExamplesDialog(
                                  examples,
                                );
                                if (example == null) {
                                  return;
                                }
                                if (model.constraints.containsKey(example[0])) {
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget outputCard(String text, bool user) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(user ? Icons.person : Icons.computer),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: wrapPadding(SelectableText(text.trim())),
          ),
        ),
      ],
    );
  }

  Widget buildOutputs(HomeModel model) {
    List<Widget> children = [];
    if (model.waiting) {
      children.add(const SizedBox(height: 8));
      children.add(
        const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    }
    children.addAll(
      model.outputs.reversed
          .map(
            (output) => [
              const SizedBox(height: 8),
              outputCard(output.output, false),
              const SizedBox(height: 8),
              outputCard(output.input, true),
            ],
          )
          .flattened,
    );
    return ListView(
      reverse: true,
      children: children.sublist(min(1, children.length)),
    );
  }

  showInfoDialog(A.BackendInfo info) async {
    const optionPadding = EdgeInsets.symmetric(vertical: 8, horizontal: 8);
    await showDialog(
      context: context,
      builder: (infoContext) {
        return SimpleDialog(
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
            ListView.builder(
              itemCount: items.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (listContext, idx) {
                return ListTile(
                  visualDensity: VisualDensity.compact,
                  title: Text(items[idx]),
                  subtitle: Text("Example ${idx + 1}"),
                  onTap: () => onSelected([groupName, items[idx]]),
                  // leading: const Icon(Icons.notes),
                );
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
