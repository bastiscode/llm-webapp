import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:webapp/components/links.dart';
import 'package:webapp/components/presets.dart';

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

// examples
const Map<String, List<String>> examples = {
  "JSON": [
    "Generate a simple JSON example document: ",
  ],
  "SPARQL": [
    "Generate a simple SPARQL example query over Wikidata: "
  ]
};

// display clickable choice chips inside pipeline selection
// that set a specific model for each task on click,
// default preset is always assumed to be the first in
// the following list
const List<Preset> presets = [];
