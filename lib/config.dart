import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:webapp/components/links.dart';
import 'package:webapp/components/presets.dart';
import 'package:webapp/utils.dart';

// some general configuration options
const String title = "LLM text generation";
const String description =
    "Run large language models with arbitrary output constraints.";
const String lastUpdated = "March 8, 2024";

const String baseURL = "/api";

// display links to additional resources on the website,
// will be shown as action chips below the title bar
const List<Link> links = [
  Link(
    "Code",
    "https://github.com/bastiscode/llm-text-generation",
    icon: FontAwesomeIcons.github,
  ),
];

class Constraint {
  String? regex;
  String? cfgGrammar;
  String? cfgLexer;
  bool cfgExact = false;

  Constraint({
    this.regex,
    this.cfgGrammar,
    this.cfgLexer,
    this.cfgExact = false,
  });

  static Constraint withRegex(String regex) {
    return Constraint(regex: regex);
  }

  bool get isRegex => regex != null;

  bool get isGrammar => !isRegex;

  static Constraint withGrammar(
    String grammar,
    String lexer, {
    bool exact = false,
  }) {
    return Constraint(
      cfgGrammar: grammar,
      cfgLexer: lexer,
      cfgExact: exact,
    );
  }
}

// constraints

Future<Map<String, Constraint>> loadConstraints() async {
  return {
    "Boolean": Constraint.withRegex(r"\s?(true|false)"),
    "Integer": Constraint.withRegex(r"\s?(0|[1-9]+[0-9])"),
    "CoT": Constraint.withRegex(
      r"""Reasoning:
([1-5]\. [\w ]+\n){1,5}
Answer: [\w ]{1,128}""",
    ),
    "SPARQL": Constraint.withGrammar(
      await loadTextAsset("grammars/sparql/sparql.y"),
      await loadTextAsset("grammars/sparql/sparql.l"),
    ),
    "JSON": Constraint.withGrammar(
      await loadTextAsset("grammars/json/json.y"),
      await loadTextAsset("grammars/json/json.l"),
    ),
  };
}

// examples
const Map<String, List<String>> examples = {
  "Boolean": [
    "Is Berlin larger than Germany?",
  ],
  "Integer": [
    "How tall is Mount Everest in meters?",
  ],
  "CoT": [
    "Is Berlin larger than Germany? Perform at most 5 reasoning steps and "
        "stay within a 128 character limit for your final answer.",
    "What is the next number in the sequence 2, 4, 8, 16, ...? Perform at most 5 reasoning steps and "
        "stay within a 128 character limit for your final answer.",
  ],
  "JSON": [
    "Generate a simple JSON example document:",
  ],
  "SPARQL": [
    "Generate a simple SPARQL example query over Wikidata:",
  ]
};

// display clickable choice chips inside pipeline selection
// that set a specific model for each task on click,
// default preset is always assumed to be the first in
// the following list
const List<Preset> presets = [];
