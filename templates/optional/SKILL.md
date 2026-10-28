---
name: rasuvaeff-{{PACKAGE_KEBAB}}
description: >-
  {{DESCRIPTION}} — name the public types here (the facade, the value objects,
  the exceptions, the test doubles) and say when the skill applies: "Use when
  writing, reviewing or debugging <the thing this package does> in a project
  that has this package installed." The description is the only text an agent
  reads before deciding whether to load the file, so it carries the nouns a
  prompt would use, not marketing.
---

# rasuvaeff/{{PACKAGE_KEBAB}}

One or two sentences: what the package does and the namespace its types live
in (`Rasuvaeff\{{PACKAGE_PASCAL}}\`).

## Safety rules — verify these on every change

The rules a consumer cannot infer from the signatures, each one a sentence an
agent can act on. The bar: if getting it wrong produces working-looking code
that is wrong at runtime, it belongs here. Examples of the shape:

- What must never be passed from untrusted input, and what validates it.
- Which call is not idempotent, and what the caller owes it.
- What the package does NOT do (no retries, no locking, no transaction).

## Canonical usage

The shortest complete example that a consumer would copy: construction,
the one call that matters, and the error path. Runnable, not illustrative.

```php
<?php

declare(strict_types=1);

use Rasuvaeff\{{PACKAGE_PASCAL}}\...;
```

## Full API

A table or list of every `@api` type with one line each — the same set
`README.md` and `llms.txt` document. A type missing here is a type an agent
will not use.
