---
title: Cleanup
linkTitle: Cleanup
weight: 50
description: Delete objects that should no longer exist. In progress.
---

{{% alert title="In progress" color="warning" %}}
There is no `ClusterCleanupPolicy` yet. What exists today is `deletionPolicy: Delete` on a generation
policy, which removes what that policy wrote when the policy is deleted.
{{% /alert %}}

A cleanup policy will delete objects under its own rules: what a policy wrote when the source
disappears, what has been idle for too long, what nobody claimed.

Until then, the only thing that goes away on its own is a generated object whose policy is removed,
which is what `deletionPolicy: Delete` in [Generation](/docs/policies/generation/) does.
