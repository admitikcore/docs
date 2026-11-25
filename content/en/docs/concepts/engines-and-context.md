---
title: Engines and context
linkTitle: Engines and context
weight: 20
description: What renders a template, which engines exist, and what they receive.
---

## Engines

Admitik ships several engines because not every rule reads well in the same form. The goal of the
project is that you spend your time on the rule and not on the syntax. There are several ones
supported.

An engine is the piece that turns the text of a condition, a message or a patch into a value. Every
field with a template names the one it wants, and one policy can mix them.

### CEL

An expression language: one expression, no statements. It is the engine for rules that fit on one
line, or a few of them.

```yaml
key: has(object.metadata.labels) && "team" in object.metadata.labels

key: object.spec.replicas <= 10
```

### Starlark

A Python-like language: functions, loops, comprehensions and modules. It is where the rules that are a
program live, and the one to reach for when a rule needs to build something before deciding.

These are the modules Admitik loads for it, from regular expressions to YAML, DNS and HTTP:

| Module | What it gives you |
| --- | --- |
| [`yaml`](/docs/concepts/starlark/#yaml) | Decode and encode YAML |
| [`json`](/docs/concepts/starlark/#json) | Decode and encode JSON |
| [`re`](/docs/concepts/starlark/#re) | Regular expressions: match, search, find, split, replace |
| [`string`](/docs/concepts/starlark/#string) | Character sets, search, quoting and escaping |
| [`hashlib`](/docs/concepts/starlark/#hashlib) | md5, sha1, sha256 and sha512 |
| [`base64`](/docs/concepts/starlark/#base64) | Standard and URL-safe encoding and decoding |
| [`csv`](/docs/concepts/starlark/#csv) | Read and write delimited text |
| [`math`](/docs/concepts/starlark/#math) | Functions and constants |
| [`time`](/docs/concepts/starlark/#time) | Durations, parsing and formatting |
| [`random`](/docs/concepts/starlark/#random) | Numbers, strings and UUIDs |
| [`log`](/docs/concepts/starlark/#log) | Write a line with fields, at a level |
| [`http`](/docs/concepts/starlark/#http) | HTTP requests with headers, body and status |
| [`net`](/docs/concepts/starlark/#net) | DNS lookups, TCP checks and statistics |

The full list, with the functions of each one, is in [Starlark](/docs/concepts/starlark/).

```yaml
engine: starlark
key: |
  for existing in sources[0]:
      if existing["metadata"]["name"] == object["metadata"]["name"]:
          continue
      if existing["spec"]["hostnames"] == object["spec"]["hostnames"]:
          vars["collision"] = existing["metadata"]["name"]
          print("collision")
          break
  else:
      print("clear")
```

### Go templates

Go templates with the Sprig functions. When the output is a document, the template is the document,
which is why it is the usual choice for a manifest. It reads everything and leaves values with
`setVar`.

```yaml
engine: gotmpl
template: |
  apiVersion: v1
  kind: ConfigMap
  metadata:
    name: platform
    namespace: {{ .object.metadata.name }}
```

### Plain

Nothing to evaluate. The text is the value.

```yaml
engine: plain
template: "configmaps are not allowed here"
```

### Plain + CEL

Plain text with holes. A YAML patch that needs one or two values from the object stays readable, and
the holes are CEL expressions, with the same limits as CEL.

```yaml
engine: plain+cel
template: |
  metadata:
    labels:
      namespace: "{{cel: object.metadata.name }}"
```

## At a glance

| Engine | Where it wins | What it cannot do |
| --- | --- | --- |
| `cel` | Short rules over the object or a list, with `all` and `exists` | No loops, no access to `vars` |
| `starlark` | Rules that are a program: loops, helper functions, building a patch | More lines to read for a rule that fits in one |
| `gotmpl` | Documents: a manifest, or a message built from many fields | Logic turns into string juggling |
| `plain` | Text that never changes | No access to the context |
| `plain+cel` | A readable patch that needs one or two values from the object | Only expressions inside the holes |

## The context

Before an engine runs, Admitik builds one object with everything the template may need and hands it
over as top level names. It is the same for all of them; what changes is how each engine reads it.

| Name | Content |
| --- | --- |
| `operation` | `CREATE`, `UPDATE` or `DELETE`, normalized |
| `object` | The object being admitted, or the one that triggered the event |
| `oldObject` | The previous state, on updates. Empty otherwise |
| `sources` | The objects each source returned, by position |
| `vars` | Values a policy writes for its own later conditions and templates |

## Who sees what

| Engine | Sees the context | Sees `vars` | Writes `vars` |
| --- | --- | --- | --- |
| CEL | yes | no | no |
| Starlark | yes | yes | yes |
| Go templates | yes | yes | yes, with `setVar` |
| Plain | no | no | no |
| Plain + CEL | through its holes | no | no |

A CEL expression never sees `vars`, on purpose: what it produces cannot depend on what another
template wrote. When a rule needs a value from an earlier step, write it in Starlark or in a Go
template.

`vars` is the only part of the context that changes during an evaluation. It starts empty on every
object.

## Writing and reading values

### With Starlark

`vars` is a dictionary. Write it with a key, read it with the same key:

```yaml
conditions:
  - name: compute-the-ceiling
    engine: starlark
    key: |
      vars["ceiling"] = 10
      print("computed")
    value: computed

  - name: is-it-over
    engine: starlark
    key: |
      if object["spec"]["replicas"] > vars["ceiling"]:
          print("over")
      else:
          print("under")
    value: over
```

The first condition leaves `10` in `vars`, and the second one reads it. If the key may not be there,
ask first:

```python
if "ceiling" in vars:
    print(vars["ceiling"])
```

### With Go templates

`setVar` takes a key and a value, writes it and returns an empty string, so it goes wherever the
template starts. The value is read with `.vars.<key>`:

```yaml
conditions:
  - name: remember-the-team
    engine: gotmpl
    key: '{{ setVar "team" .object.metadata.labels.team }}computed'
    value: computed

patch:
  type: jsonmerge
  engine: gotmpl
  template: |
    metadata:
      labels:
        team: {{ .vars.team }}
```

The condition produces the text `computed`, because `setVar` returns nothing, and leaves the team in
`vars`. The patch reads it later and writes it into a label.

### Mixing them

Both engines read what the other wrote. A value computed in Starlark is `.vars.ceiling` in a Go
template, and a value set with `setVar` is `vars["team"]` in Starlark:

```yaml
conditions:
  - name: compute
    engine: starlark
    key: |
      vars["ceiling"] = int(object["metadata"]["labels"]["max-replicas"])
      print("computed")
    value: computed

patch:
  type: jsonmerge
  engine: gotmpl
  template: |
    spec:
      replicas: {{ .vars.ceiling }}
```
