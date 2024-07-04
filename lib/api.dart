import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:convert';

import 'package:webapp/components/message.dart';
import 'package:webapp/config.dart';
import 'package:window_location_href/window_location_href.dart' as whref;

class SocketStream {
  final _socketResponse = StreamController<String>();

  void add(String data) => _socketResponse.sink.add(data);

  Stream<String> get stream => _socketResponse.stream;

  void dispose() {
    _socketResponse.close();
  }
}

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
  String input;
  String output;
  Runtime runtime;

  ModelOutput(
    this.input,
    this.output,
    this.runtime,
  );
}

class Api {
  late final String _apiURL;
  late final String _socketURL;
  late final String _socketPath;

  late final String _webBaseURL;

  String get webBaseURL => _webBaseURL;

  Api._privateConstructor() {
    String? href = whref.href;
    if (href == null) {
      throw UnsupportedError("unknown platform");
    }
    if (href.endsWith("/")) {
      href = href.substring(0, href.length - 1);
    }
    if (kReleaseMode) {
      // for release mode use href
      _apiURL = "$href$apiURL";
      _socketURL = href;
      _socketPath = "$apiURL/live";
    } else {
      // for local development use localhost
      _apiURL = "http://localhost:40000";
      _socketURL = _apiURL;
      _socketPath = "/live";
    }
    _webBaseURL = href;
  }

  static final Api _instance = Api._privateConstructor();

  static Api get instance {
    return _instance;
  }

  Future<ApiResult<List<ModelInfo>>> models() async {
    try {
      final res = await http.get(Uri.parse("$_apiURL/models"));
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
      final res = await http.get(Uri.parse("$_apiURL/info"));
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

  (SocketStream, IO.Socket)? generate(
    String text,
    List<Map<String, String>>? chat,
    String model,
    bool sampling,
    Constraint? constraint,
  ) {
    var data = {
      "model": model,
      "beam_width": 1,
      "sampling_strategy": sampling ? "top_p" : "greedy",
      "top_p": 0.95
    };
    if (chat == null) {
      data["text"] = text;
    } else {
      data["chat"] = chat;
    }
    if (constraint != null) {
      if (constraint.isRegex) {
        data["constraint"] = {
          "type": "regex",
          "regex": constraint.regex!,
        };
      } else {
        data["constraint"] = {
          "type": "lr1",
          "grammar": constraint.lr1Grammar!,
          "lexer": constraint.lr1Lexer!,
          "exact": constraint.lr1Exact
        };
      }
    }
    try {
      final socket = IO.io(
        _socketURL,
        IO.OptionBuilder()
            .disableAutoConnect()
            .setPath(_socketPath)
            .setReconnectionAttempts(0)
            .setTransports(["websocket"]).build(),
      );
      final stream = SocketStream();
      socket.onConnect((_) {
        socket.emit("message", jsonEncode(data));
      });
      socket.on("message", (data) {
        stream.add(data);
      });
      socket.onDisconnect((_) {
        stream.dispose();
      });
      socket.connect();
      return (stream, socket);
    } catch (e) {
      return null;
    }
  }
}

final api = Api.instance;

Message errorMessageFromApiResult(ApiResult result) {
  return Message("${result.statusCode}: ${result.message}", Status.error);
}
