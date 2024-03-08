# LLM text generation webapp

Web application for LLM text generation backends.
Supports the following tasks:
- text generation

## Build

Configure your website using [lib/config.dart](lib/config.dart).
After that build it using `flutter build web --release`, or
if you do not have flutter installed use `docker build -t <image-name> .` which
creates a nginx docker image hosting the website. Run it using
`docker run -p <port>:80 <image-name>`.

## Endpoints

Endpoints required for all question answering backends:
- [GET] /models
```
  returns:
    {
      "task": "text generation", 
      "models": [
        {
          "name": "best_model_v1", 
          "description": "this model is so good", 
          "tags": ["arch::transformer", "speed::fast", "lang::en", ...]
        }, 
        ...
      ]
    }
```
- [GET] /info
```
  returns:
    {
      "gpu": ["GTX 1080Ti", "RTX 2080Ti", ...],
      "cpu": "Intel i7 9700K",
      "timeout": 10.0
    }
```

Also all endpoints should support arbitrary leading base URLs,
e.g. /api/v1/llm/info

In particular, for this webapp, the tasks should be run with the
following base URLs:
- Text generation: /api

Endpoints required for text generation:
- [POST] /generation
```
  requires:
    {
      "model": "best_model_v1", 
      "texts": ["who is albert einstein?", "how old is angela merkel?"]
    }
  optional:
    {
      "search_strategy": "greedy",
      "beam_width": 5,
      "labels": false,
      "regex": "[0-9]+",
      "cfg": {
        "grammar": "...",
        "lexer": "...",
        "exact": false
      }
    }
  returns:
    {
      "text": ["Albert Einstein is a physicist", "Angela Merkel is 65 years old"], 
      "runtime": {"s": 10, "b": 20}
    } 
```