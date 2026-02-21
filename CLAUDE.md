# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Kibana is an open-source analytics and visualization platform for Elasticsearch. It's a large TypeScript monorepo using Yarn workspaces and Bazel, containing 200+ plugins and packages.

## Essential Commands

```bash
# Setup
yarn kbn bootstrap          # Install dependencies (requires Yarn 1.22.19+, Node 20.15.1)

# Development
yarn es snapshot             # Start Elasticsearch locally
yarn start                   # Start Kibana dev server
yarn start --run-examples    # Start with example plugins

# Testing
yarn test:jest               # Unit tests (Jest)
yarn test:jest <path>        # Single test file or directory
yarn test:jest_integration   # Integration tests
yarn test:ftr                # Functional tests (full)
yarn test:ftr:server         # Start FTR server only
yarn test:ftr:runner         # Run FTR tests only

# Linting & Type Checking
yarn lint                    # ESLint + Stylelint
yarn lint:es                 # ESLint only
yarn lint --fix              # Auto-fix lint issues
yarn test:type_check         # TypeScript type checking

# Build
yarn build                   # Production build for all platforms
```

## Architecture

### Directory Layout

- `src/core/` — Core platform (browser `public/`, server `server/`, `test_helpers/`)
- `src/plugins/` — Open-source plugins (dashboard, discover, console, data, etc.)
- `x-pack/plugins/` — Licensed plugins (alerting, actions, cases, canvas, security, etc.)
- `x-pack/packages/` — Licensed internal packages
- `packages/` — Shared internal packages (prefixed `@kbn/`)
- `examples/` — Example plugins for developer reference
- `test/` — Test utilities, test plugins, and functional test suites
- `dev_docs/` — Developer documentation (MDX format)

### Plugin System

Each plugin lives in `src/plugins/` or `x-pack/plugins/` and follows this structure:

```
plugin-name/
├── kibana.jsonc         # Plugin manifest (id, owner, dependencies)
├── tsconfig.json
├── public/              # Browser-side code
│   ├── index.ts         # Public API entry point
│   └── plugin.ts        # Plugin class
├── server/              # Server-side code
│   ├── index.ts
│   └── plugin.ts
└── common/              # Shared types/constants
```

The `kibana.jsonc` manifest declares `requiredPlugins` (hard deps) and `optionalPlugins` (soft deps). Plugins communicate through API contracts, not direct imports.

### Package System

Internal packages use `@kbn/` prefix with Yarn `link:` dependencies. Path aliases are configured in `tsconfig.base.json` for ergonomic imports (e.g., `@kbn/config-schema`).

## Code Conventions

- **Filenames**: snake_case
- **HTML IDs / data-test-subj**: camelCase
- **API endpoints**: `/api/{plugin-id}/...` with snake_case parameters
- **Formatting**: Prettier (single quotes, trailing commas es5, 100 char width)
- **Exports**: Use `export type` for types; avoid `export *` in top-level index files; minimize public API surface
- **License headers**: Required in all source files (Apache 2.0 for `src/`, Elastic License for `x-pack/`)

## Testing Patterns

- **Jest config**: Each plugin uses `jest.config.js` with `preset: '@kbn/test'`
- **Core mocks**: Available at `src/core/{server,public}/mocks`
- **FTR tests**: Never use `sleep()` — use `retry.waitFor()` or `testSubjects.existsOrFail()`
- **Test data setup**: Prefer API-based setup over UI automation in functional tests

## Docker Build (Custom)

This repo includes a custom `Dockerfile.build` that builds Kibana from source inside Docker and produces a Wolfi-based production image. No host Node.js installation is needed.

### Build this branch (8.19 / version 8.19.11)

```bash
docker build -f Dockerfile.build -t kibana-custom:8.19 .
```

### Build all branches (main, 8.19, 9.3)

```bash
./build_all_branches.sh
```

### Run

```bash
docker run -p 5601:5601 kibana-custom:8.19
```

### Build details

- **Dockerfile**: `Dockerfile.build` (multi-stage: node:22-bookworm builder + chainguard/wolfi-base production)
- **Script**: `build_all_branches.sh` (loops over branches, reads `.node-version` and `package.json`)
- **Output**: Wolfi x86_64 production image with tini init, CJK fonts, kibana user (UID 1000)
- **Skipped variants**: UBI, cloud, cloud-FIPS, serverless, FIPS, Docker contexts, CDN assets
- **This branch version**: 8.19.11

## Key Developer Docs

- Setup: `dev_docs/getting_started/setting_up_a_development_env.mdx`
- Plugin anatomy: `dev_docs/key_concepts/anatomy_of_a_plugin.mdx`
- Testing: `dev_docs/tutorials/testing_plugins.mdx`
- Stable FTR tests: `dev_docs/operations/writing_stable_functional_tests.mdx`
