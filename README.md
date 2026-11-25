# Admitik docs

The documentation site for [Admitik](https://github.com/admitikcore/admitik), served at
[admitik.dev](https://admitik.dev).

Hugo and Docsy. The theme is vendored in `themes/docsy`, and the Admitik look lives in `assets/scss`.

## Run it

Needs Node, and Hugo extended. Dart Sass comes with the npm dependencies:

```console
make deps    # first time
make serve   # http://localhost:1313
```

`make build` writes the site to `public/`.

## Before opening a pull request

```console
make check
```

It builds the site and fails if an internal link points to a page that does not exist. The same thing
runs on every pull request.

## Where things live

```text
content/en/docs/        the reference: installation, configuration, concepts, policies, observability
content/en/use-cases/   the marketplace of working policies
assets/scss/            palette, typography, cards, navbar
layouts/use-cases/      the marketplace list and its pages
hack/                   freeze a version, generate the flags table
```

## Editing a page

One markdown file per page, with front matter on top:

```yaml
---
title: Trigger
weight: 20
description: One line, used by the list and the search index.
---
```

`weight` is the position among the pages of the same directory. The sidebar is the directory tree.

## Adding a use case

A file in `content/en/use-cases/`. This is the front matter the marketplace reads:

```yaml
---
title: Require an owner label on every namespace
description: Every namespace has to carry a team label, so cost and on-call have a name.
policy: validation
labels:
  - topic:namespaces
  - topic:labels
  - resource:namespaces
  - engine:cel
  - level:starter
---
```

The body is the prose plus the whole manifest.

`policy` is the facet above the labels, and takes `validation`, `mutation`, `generation` or
`solution` (more than one policy working together).

Every label is `dimension:value`. These are the dimensions in use:

| Dimension | What it says | Examples |
| --- | --- | --- |
| `topic` | The problem or the area | `security`, `cost`, `routing` |
| `resource` | The resource it intercepts or watches | `pods`, `namespaces` |
| `engine` | The template engine of the manifest | `cel`, `gotmpl`, `starlark` |
| `feature` | The Admitik feature it exercises | `sources`, `vars`, `jsonmerge` |
| `level` | How much there is to read | `starter`, `intermediate`, `advanced` |

A new dimension appears in the filter panel as soon as one file uses it.

## Changing the flags table

The table in `content/en/docs/configuration.md` is generated from the controller:

```console
make flags
```

It builds the controller from `../admitik` (or `ADMITIK_REPO`) and rewrites the block between the two
markers.

## Publishing a version

The newest content lives at the root and every older one under `/<version>/`. Editing the root is
publishing: merging to `main` deploys it, with no version step.

When the pages change enough to deserve their own version, archive what is live before editing it:

```console
make version VERSION=2.1.0 NEXT=2.1.1
```

That copies the root into `content/en/2.1.0/`, adds the entry to `params.versions`, and moves the root
to `v2.1.1`.

It has to run **before** the pages are edited for the next release, because it archives what is at the
root at that moment. If the root was already edited, take the old pages from git first:
`git checkout HEAD~1 -- content/en/docs content/en/use-cases`, archive them, and put the new ones back.

What ends up under `/<version>/` is frozen: no edits there.

## Opening a pull request

Work on a branch and open a pull request. `main` deploys on merge.

## Deploy

`.github/workflows/pages.yaml` builds the site and publishes it to GitHub Pages on every push to
`main`. `static/CNAME` says `admitik.dev`, and it has to match the custom domain of the repository.
