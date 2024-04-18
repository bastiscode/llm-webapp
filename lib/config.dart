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

const formatLanguages = [
  "JSON",
  "SPARQL"
];

class Constraint {
  String? regex;
  String? lr1Grammar;
  String? lr1Lexer;
  bool lr1Exact = false;

  Constraint({
    this.regex,
    this.lr1Grammar,
    this.lr1Lexer,
    this.lr1Exact = false,
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
      lr1Grammar: grammar,
      lr1Lexer: lexer,
      lr1Exact: exact,
    );
  }
}

// constraints
const String customRegexConstraint = "Custom regex";
const String customCfgConstraint = "Custom cfg";

Future<Map<String, Constraint>> loadConstraints() async {
  return {
    "Boolean": Constraint.withRegex(r"\s?(true|false)"),
    "Number": Constraint.withRegex(r"\s?\d{1,3}(,\d{3})*(\.\d{1, 2})?"),
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
    """WW2 started in 1934
false

Eiffel tower is 300m tall
true
    
Berlin is larger than Germany""",
  ],
  "Number": [
    """How tall is Mont Blanc in meters? 
4,809

How tall is K2 in meters?
8,611
    
How tall is Mount Everest in meters?""",
  ],
  "CoT": [
    """For each of the following questions, perform at most 5 reasoning steps and stay within a 128 character limit for your final answer.

Does 45 * 3 equal 130?
Reasoning:
1. 45 * 3 = 135
2. 135 != 130

Answer: 45 * 3 does not equal 135.
    
Is Berlin larger than Germany?""",
    """For each of the following questions, perform at most 5 reasoning steps and stay within a 128 character limit for your final answer.

Does 45 * 3 equal 130?
Reasoning:
1. 45 * 3 = 135
2. 135 != 130

Answer: 45 * 3 does not equal 135.
    
What is the next number in the sequence 2, 4, 8, 16, ...?""",
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
