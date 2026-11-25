---
title: Admitik
linkTitle: Home
---

{{< blocks/cover title="Admitik" image_anchor="center" height="med" color="primary" >}}
<p class="lead">A next generation policy engine for Kubernetes.</p>
<p class="hero-sub">Write your policies with CEL, Starlark or Go templates, so you can focus on the
rules and not on fighting with the syntax.</p>
<p class="lead p-initial mt-5">
  <a class="btn btn-lg btn-light me-2 mb-3" href="/docs/installation/"><i class="fa-solid fa-rocket me-2"></i>Get started</a>
  <a class="btn btn-lg btn-outline-light mb-3" href="/use-cases/"><i class="fa-solid fa-compass me-2"></i>Browse use cases</a>
</p>
{{< /blocks/cover >}}

{{% blocks/section color="white" %}}
<h2 class="mb-2">What you can do with it</h2>
<p class="mb-5">The same shape of policy for every step of the lifecycle of an object.</p>

<div class="cap-grid">
  <a class="cap-card" href="/docs/policies/validation/">
    <span class="cap-card__icon"><i class="fa-solid fa-shield-halved"></i></span>
    <h3>Validate</h3>
    <p>Reject an object before it is stored, or let it through with a warning.</p>
  </a>

  <a class="cap-card" href="/docs/policies/mutation/">
    <span class="cap-card__icon"><i class="fa-solid fa-wand-magic-sparkles"></i></span>
    <h3>Mutate</h3>
    <p>Fill in what nobody should have to remember: default labels, resource limits, annotations,
    pull secrets.</p>
  </a>

  <a class="cap-card" href="/docs/policies/generation/">
    <span class="cap-card__icon"><i class="fa-solid fa-clone"></i></span>
    <h3>Generate</h3>
    <p>Create what has to exist because something else exists: the quota of a new namespace, its
    default ConfigMap, a Secret derived from another one.</p>
  </a>

  <div class="cap-card cap-card--soon">
    <span class="cap-card__icon"><i class="fa-solid fa-broom"></i></span>
    <h3>Cleanup <span class="cap-chip">Soon</span></h3>
    <p>Delete what a policy wrote. The objects that outlive their source are next.</p>
  </div>

  <div class="cap-card cap-card--soon">
    <span class="cap-card__icon"><i class="fa-solid fa-copy"></i></span>
    <h3>Clone <span class="cap-chip">Soon</span></h3>
    <p>Copy an object into another namespace, or into another resource.</p>
  </div>
</div>
{{% /blocks/section %}}

{{% blocks/section color="secondary" %}}
<h2 class="mb-3">Reasons to love it</h2>

<p class="lead mb-5">Most policy engines give you one way to write a rule, and a fixed idea of what a
rule can see. Neither fits a cluster that changes shape every day.</p>

<div class="split mb-5">
  <div>
    <h3 class="h5">The rule decides the syntax</h3>
    <p>Some rules read better as a program, some as a single expression, and many need another object
    in the cluster to decide. Admitik ships five engines in the core, so each rule is written the way it
    fits and one policy can use a different engine for every condition, patch and message.</p>
  </div>
  <div>
    <h3 class="h5">The context comes with it</h3>
    <p>All of them receive the same thing: the object, its previous state, the resources the policy
    asked for and the values left by earlier conditions.</p>
  </div>
</div>

<div class="eng-grid">
  <div class="eng-item">
    <h3>CEL <span class="eng-tag">expressions</span></h3>
    <p>A field, a comparison, a set of labels. The rule that fits in one line.</p>
    <code>object.spec.replicas &lt;= 10</code>
  </div>

  <div class="eng-item">
    <h3>Starlark <span class="eng-tag">code</span></h3>
    <p>Loops and helper functions, for the rules that are a program.</p>
    <code>for c in object.spec.containers:</code>
  </div>

  <div class="eng-item">
    <h3>Go templates <span class="eng-tag">templates</span></h3>
    <p>Manifests and messages built from the fields of an object.</p>
    <code>{{ .object.metadata.name }}</code>
  </div>

  <div class="eng-item">
    <h3>Plain <span class="eng-tag">text</span></h3>
    <p>Text that never changes.</p>
    <code>configmaps are not allowed here</code>
  </div>

  <div class="eng-item">
    <h3>Plain + CEL <span class="eng-tag">text and values</span></h3>
    <p>Text with holes, filled from the object.</p>
    <code>namespace: {{cel: object.metadata.name }}</code>
  </div>
</div>
{{% /blocks/section %}}
