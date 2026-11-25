---
title: Starlark
linkTitle: Starlark
weight: 40
description: A Python-like language, plus the modules Admitik loads for it.
---

Starlark is a small, deterministic dialect of Python. It has functions, loops, comprehensions and a
standard set of builtins, and it runs with the same result every time it is given the same input.

Admitik loads a set of extra modules on top of it. They are available at the top of every template,
either by name or through `load`:

```python
def ceiling():
    labels = object["metadata"].get("labels", {})
    total = int(labels.get("max-replicas", "0"))

    if re.match("^[0-9]+$", labels.get("max-replicas", "")) == None:
        log.warn("max-replicas is not a number")
        total = 0

    return total

print(ceiling())
```

## Modules

| Module | What it gives you |
| --- | --- |
| [`yaml`](#yaml) | Decode and encode YAML |
| [`json`](#json) | Decode and encode JSON |
| [`re`](#re) | Regular expressions: match, search, find, split, replace |
| [`string`](#string) | Character sets, search, quoting and escaping |
| [`hashlib`](#hashlib) | md5, sha1, sha256 and sha512 |
| [`base64`](#base64) | Standard and URL-safe encoding and decoding |
| [`csv`](#csv) | Read and write delimited text |
| [`math`](#math) | Functions and constants |
| [`time`](#time) | Durations, parsing and formatting |
| [`random`](#random) | Numbers, strings and UUIDs |
| [`log`](#log) | Write a line with fields, at a level |
| [`http`](#http) | HTTP requests with headers, body and status |
| [`net`](#net) | DNS lookups, TCP checks and statistics |

`http` and `net` reach the network. The rest work on values only.

## yaml

`yaml.decode` turns text into values, `yaml.encode` goes the other way. This is how a policy reads the
YAML that a team wrote into an annotation.

```python
config = yaml.decode(object["metadata"]["annotations"]["admitik.dev/loggingConfig"])
for entry in config:
    print(entry.get("container"))
```

## json

`json.encode` and `json.decode`. A JSON patch is a list of operations, so `json.encode` is what a
Starlark patch prints:

```python
print(json.encode([{"op": "add", "path": "/metadata/labels/team", "value": "payments"}]))
```

## re

`re.compile`, `re.match`, `re.fullmatch`, `re.search`, `re.findall`, `re.finditer`, `re.split`,
`re.sub`, `re.subn` and `re.escape`. A compiled pattern is reusable inside the same template.

```python
pattern = re.compile("^([a-z]+)-([0-9]+)$")
found = pattern.match(object["metadata"]["name"])
if found != None:
    print(found.group(1))
```

## string

`string.ascii_letters`, `digits`, `hexdigits`, `octdigits`, `punctuation`, `whitespace` and
`printable` for the character sets, plus `find`, `rfind`, `index`, `rindex`, `substring`, `length`,
`reverse`, `quote`, `unquote`, `escape` and `unescape`.

```python
if string.length(object["metadata"]["name"]) > 63:
    print("too long")
```

## hashlib

`hashlib.md5`, `sha1`, `sha256` and `sha512`, over a string.

```python
digest = hashlib.sha256(object["metadata"]["name"])
```

## base64

`base64.encode` and `base64.decode`, with the `standard`, `standard_raw`, `url` and `url_raw`
variants.

## csv

`csv.read_all` parses text into rows, `csv.write_all` writes rows, `csv.write_dict` writes a dict per
row with a header.

## math

`ceil`, `floor`, `round`, `fabs`, `mod`, `pow`, `remainder`, `exp`, `sqrt`, the trigonometric family
(`sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `atan2`, `hypot`, `degrees`, `radians`) and the
hyperbolic one.

## time

`time.now`, `time.time`, `time.from_timestamp`, `time.parse_time`, `time.parse_duration` and
`time.is_valid_timezone`, plus the durations `nanosecond`, `microsecond`, `millisecond`, `second`,
`minute` and `hour`. Useful to compare a timestamp from an annotation with the current one.

```python
created = time.parse_time(object["metadata"]["creationTimestamp"])
if time.now() - created > time.parse_duration("720h"):
    print("older than a month")
```

## random

`random.random`, `randint`, `choice`, `choices`, `shuffle`, `uniform`, `randstr`, `randbytes` and
`uuid`. Note that a policy that uses them stops being deterministic, which is the one thing Starlark
promises.

## log

`log.debug`, `log.info`, `log.warn` and `log.error`. The message is followed by fields, which is what
ends up in the line of the controller:

```python
log.debug("evaluating namespace", name=object["metadata"]["name"], replicas=total)
```

## http

`http.call` for any method, plus the helpers per method. It takes headers, query parameters, a body,
form data, basic auth and a timeout, and it returns the status, the headers and the body, with `json`
and `text` accessors.

```python
response = http.get("https://inventory.internal/hosts/" + object["metadata"]["name"], timeout=5)
if response.status_code == 404:
    print("unknown")
```

## net

`net.nslookup` for DNS, `net.tcping` and `net.httping` for reachability, and `min`, `max`, `total`,
`avg`, `stddev`, `loss` and `success` to summarise the results of several attempts.

## What it cannot do

- There is no filesystem module loaded, so a template cannot read or write files.
- Nothing is shared between evaluations: each one starts with the same context and an empty `vars`, so
  a value cannot be cached for the next object.
- In the admission path, an evaluation has to finish before Kubernetes gives up waiting for the
  answer. A loop over a large source can make a request slow: filter the source instead.
