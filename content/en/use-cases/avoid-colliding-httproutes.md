---
title: Reject HTTPRoutes that collide with an existing one
linkTitle: Colliding HTTPRoutes
weight: 50
description: Two routes with the same hostname and path are a bug that only shows up in production traffic.
policy: validation
labels:
  - topic:routing
  - topic:gateway-api
  - resource:httproutes
  - engine:starlark
  - feature:sources
  - feature:vars
  - level:advanced
---

Two `HTTPRoute` objects can declare the same hostname and path. The API accepts both, the gateway
serves one, and the other stops receiving traffic without saying so.

Comparing the incoming route with the existing ones needs a loop, so the condition is Starlark and
the whole list of routes is a source.

```yaml
apiVersion: admitik.dev/v1alpha1
kind: ClusterValidationPolicy
metadata:
  name: avoid-colliding-routes
spec:
  failureAction: Permissive

  interceptedResources:
    - group: gateway.networking.k8s.io
      version: v1
      resource: httproutes
      operations:
        - CREATE
        - UPDATE

  sources:
    - group: gateway.networking.k8s.io
      version: v1
      resource: httproutes

  conditions:
    - name: compute-raw-match
      engine: starlark

      key: |
        def compute_raw_match():
            incoming_route = object
            existing_routes = sources[0]

            incoming_name = incoming_route["metadata"]["name"]
            incoming_namespace = incoming_route["metadata"]["namespace"]
            incoming_parent_refs = incoming_route["spec"]["parentRefs"]
            incoming_hostnames = incoming_route["spec"]["hostnames"]

            for existing_route in existing_routes:
                if (incoming_name == existing_route["metadata"]["name"] and
                    incoming_namespace == existing_route["metadata"]["namespace"]):
                    continue

                if not has_matching_parent_ref(incoming_parent_refs, existing_route["spec"]["parentRefs"]):
                    continue

                matching_hostnames = [h for h in incoming_hostnames if h in existing_route["spec"]["hostnames"]]
                if not matching_hostnames:
                    continue

                if path_conflict_exists(incoming_route, existing_route):
                    vars["existing_route"] = {
                        "name": existing_route["metadata"]["name"],
                        "namespace": existing_route["metadata"]["namespace"]
                    }
                    break

            return "ignore-condition"

        def has_matching_parent_ref(incoming_refs, existing_refs):
            """Check if any parent references match between routes"""
            for inc_ref in incoming_refs:
              inc_name = inc_ref["name"]
              inc_namespace = inc_ref.get("namespace")

              for ex_ref in existing_refs:
                if (inc_name == ex_ref["name"] and inc_namespace == ex_ref.get("namespace")):
                  return True
            return False

        def path_conflict_exists(incoming_route, existing_route):
            """Check if there's a path conflict between routes"""
            for inc_rule in incoming_route["spec"]["rules"]:
              for inc_match in inc_rule["matches"]:
                inc_path_type = inc_match["path"]["type"]
                if inc_path_type not in ["Exact", "PathPrefix"]:
                  continue

                inc_path = inc_match["path"]["value"].rstrip("/")
                inc_headers = inc_match.get("headers", [])

                for ex_rule in existing_route["spec"]["rules"]:
                  for ex_match in ex_rule["matches"]:
                    ex_path_type = ex_match["path"]["type"]
                    if ex_path_type != inc_path_type:
                      continue

                    ex_path = ex_match["path"]["value"].rstrip("/")
                    if inc_path == ex_path:
                      vars["headers_to_check"] = {
                        "incoming": inc_headers,
                        "existing": ex_match.get("headers", [])
                      }
                      return True
            return False

        compute_raw_match()

        print("ignore-condition")
      value: ignore-condition

    - name: check-headers-not-matching
      engine: starlark
      key: |
        log.debug("Debug purposes: vars content: ", variables=vars)

        def check_headers_not_matching():
          headers_to_check = vars.get("headers_to_check", {})

          if not headers_to_check:
              return "path-headers-unique"

          incoming_headers = headers_to_check.get("incoming", [])
          existing_headers = headers_to_check.get("existing", [])

          if len(incoming_headers) == 0 and len(existing_headers) == 0:
              return "path-headers-duplicated"

          if len(incoming_headers) != len(existing_headers):
              return "path-headers-unique"

          for inc_header in incoming_headers:
              match_found = False

              inc_name = inc_header["name"]
              inc_type = inc_header.get("type", "Exact")
              inc_value = inc_header["value"]

              for ex_header in existing_headers:
                  ex_type = ex_header.get("type", "Exact")

                  if (inc_name == ex_header["name"] and
                      inc_type == ex_type and
                      inc_value == ex_header["value"]):
                      match_found = True
                      break

              if not match_found:
                  return "path-headers-unique"

          return "path-headers-duplicated"

        evaluation_result = check_headers_not_matching()
        print(evaluation_result)

      value: path-headers-unique

  message:
    engine: starlark
    template: |
      def format_message():
          existing_route = vars.get("existing_route", {})
          return "Resource '{}' has some declared routes already existing in object '{}/{}'".format(
              object["metadata"]["name"],
              existing_route.get("namespace", ""),
              existing_route.get("name", "")
          )

      print(format_message())
```

## Notes

- `same_object`, `shares_parent`, `shares_hostname` and `shared_paths` are defined inside the
  template, so the policy is the whole file.
- It ships as `Permissive`. Run it that way first, read the warnings, and switch to `Enforce` once
  the routes that already collide are fixed.
