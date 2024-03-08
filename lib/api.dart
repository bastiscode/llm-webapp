import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webapp/colors.dart';
import 'dart:convert';

import 'package:webapp/components/message.dart';
import 'package:webapp/config.dart';
import 'package:window_location_href/window_location_href.dart' as whref;

class ApiResult<T> {
  int statusCode;
  String? message;
  T? value;

  ApiResult(this.statusCode, {this.message, this.value}) {
    assert(this.message != null || this.value != null);
    assert(!(this.message == null && this.value == null));
  }
}

class ModelInfo {
  String name;
  String description;
  List<String> tags;

  ModelInfo(this.name, this.description, this.tags);
}

class BackendInfo {
  List<String> gpuInfos;
  String cpuInfo;
  double timeout;

  BackendInfo(this.gpuInfos, this.cpuInfo, this.timeout);
}

class Runtime {
  int b;
  double backendS;
  double clientS;

  Runtime(this.b, this.backendS, this.clientS);

  static Runtime fromJson(
    dynamic json,
    double clientS,
  ) {
    return Runtime(
      json["b"],
      json["s"],
      clientS,
    );
  }
}

class ModelOutput {
  List<String> input;
  List<String> output;
  Runtime runtime;

  ModelOutput(
    this.input,
    this.output,
    this.runtime,
  );
}

class Record {
  String type;
  String value;
  String? label;

  Record(this.type, this.value, {this.label});

  Widget toWidget() {
    switch (type) {
      case "uri":
        {
          String val = value.split("/").last;
          if (label != null) {
            val = "$label ($val)";
          }
          return Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  child: Text(
                    val,
                    style: const TextStyle(color: uniBlue),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    final _ = await launchUrl(Uri.parse(value));
                  },
                ),
              ),
            ],
          );
        }
      default:
        // default case, includes literal
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            label ?? value,
          ),
        );
    }
  }
}

class ExecutionResult {
  List<String> vars;
  List<Map<String, Record?>> results;

  ExecutionResult(
    this.vars,
    this.results,
  );

  int get length => results.length;
}

enum Feedback { helpful, unhelpful }

String feedbackToString(Feedback feedback) {
  switch (feedback) {
    case Feedback.helpful:
      return "helpful";
    case Feedback.unhelpful:
      return "unhelpful";
  }
}

class Api {
  late final String _baseURL;
  late final String _webBaseURL;

  String get webBaseURL => _webBaseURL;

  Api._privateConstructor() {
    String? href = whref.href;
    if (href != null) {
      if (href.endsWith("/")) {
        href = href.substring(0, href.length - 1);
      }
      String rel = baseURL;
      if (rel.startsWith("/")) {
        rel = rel.substring(1);
      }
      if (kReleaseMode) {
        // for release mode use href
        _baseURL = "$href/$rel";
      } else {
        // for local development use localhost
        _baseURL = "http://localhost:40000/$rel";
      }
      _webBaseURL = href;
    } else {
      throw UnsupportedError("unknown platform");
    }
  }

  static final Api _instance = Api._privateConstructor();

  static Api get instance {
    return _instance;
  }

  Future<ApiResult<List<ModelInfo>>> models() async {
    try {
      final res = await http.get(Uri.parse("$_baseURL/models"));
      if (res.statusCode != 200) {
        return ApiResult(
          res.statusCode,
          message: "error getting models: ${res.body}",
        );
      }
      final json = jsonDecode(res.body);
      List<ModelInfo> modelInfos = [];
      for (final modelInfo in json["models"]) {
        modelInfos.add(
          ModelInfo(
            modelInfo["name"],
            modelInfo["description"],
            modelInfo["tags"].cast<String>(),
          ),
        );
      }
      return ApiResult(res.statusCode, value: modelInfos);
    } catch (e) {
      return ApiResult(500, message: "internal error: $e");
    }
  }

  Future<ApiResult<BackendInfo>> info() async {
    try {
      final res = await http.get(Uri.parse("$_baseURL/info"));
      if (res.statusCode != 200) {
        return ApiResult(
          res.statusCode,
          message: "error getting backend info: ${res.body}",
        );
      }
      final json = jsonDecode(res.body);
      return ApiResult(
        res.statusCode,
        value: BackendInfo(
          json["gpu"].cast<String>(),
          json["cpu"],
          json["timeout"] as double,
        ),
      );
    } catch (e) {
      return ApiResult(500, message: "internal error: $e");
    }
  }

  Future<ApiResult<dynamic>> _post(
    String url,
    dynamic data,
  ) async {
    final res = await http.post(
      Uri.parse(url),
      body: jsonEncode(data),
      headers: {"Content-Type": "application/json"},
    );
    return ApiResult(
      res.statusCode,
      message: res.body,
      value: res.statusCode == 200 ? jsonDecode(res.body) : null,
    );
  }

  Future<ApiResult<ModelOutput>> generateText(
    List<String> text,
    String model,
    bool highQuality,
  ) async {
    try {
      final stop = Stopwatch()..start();
      var data = {
        "text": text,
        "model": model,
        "search_strategy": highQuality ? "beam" : "greedy",
        "beam_width": 5,
      };
      final res = await _post(
        "$_baseURL/generate",
        data,
      );
      if (res.statusCode != 200) {
        return ApiResult(
          res.statusCode,
          message: "text generation failed: ${res.message}",
        );
      }
      final output = ModelOutput(
        text,
        res.value["text"].cast<String>(),
        Runtime.fromJson(
          res.value["runtime"],
          stop.elapsedMicroseconds / 1e6,
        ),
      );
      return ApiResult(200, value: output);
    } catch (e) {
      return ApiResult(500, message: "internal error: $e");
    }
  }
}

final api = Api.instance;

Message errorMessageFromApiResult(ApiResult result) {
  return Message("${result.statusCode}: ${result.message}", Status.error);
}
