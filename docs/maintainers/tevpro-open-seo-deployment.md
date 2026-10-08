# Tevpro OpenSEO Cloudflare updates

This public fork tracks [every-app/open-seo](https://github.com/every-app/open-seo). It is **not yet connected to Tevpro's existing Cloudflare installation**. Do not dispatch the production workflow until the checks below are complete. Never commit `.env.selfhost`, tokens, or a dump of live Worker secrets.

## Upstream intake

`.github/workflows/tevpro-upstream-update.yml` checks the latest published upstream release each Monday or on manual dispatch. It merges the release tag into a PR branch, opens a PR against this fork's `main`, and leaves conflicts for manual resolution. The updater explicitly dispatches the repo's `CI` workflow on the branch because PRs created by GitHub's built-in token do not trigger `pull_request` workflows. The CI workflow has read-only contents permission and no production credentials. Review D1 migrations, Alchemy resource changes, Cloudflare Access/MCP changes, dependencies, and upstream changes to `.github/**` (they can alter this fork's controls). Do not auto-merge. Merging does **not** deploy production.

If the update job reports a conflict or a closed release branch already exists, resolve it in a fresh branch and PR; never force-push an already reviewed release branch just to clear the error. If GitHub Actions says it cannot create a PR, an org admin must permit Actions to create pull requests or the reviewer can open it manually from the pushed branch.

## One-time production onboarding (operator)

1. Inventory the **existing** `.env.selfhost` on Justin's deployment machine and the current Worker bindings/Access setup. Compare names and presence, not values, in logs. Preserve every production integration secret and variable; Alchemy reconciles the complete binding set. Confirm the current install also uses the `selfhost` Alchemy stage and this Cloudflare account's state store. This fork must point at those **same** resources, not provision a parallel install. Back up the production D1 database and document the currently deployed commit before first CI deploy. A code rollback does not undo D1 migrations.
2. Create a GitHub Environment named `openseo-production` with **required reviewers** and restrict deployment to `main`. The environment is the approval boundary; do not rely on the workflow name to supply approval.
3. Put `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, and the **complete** `.env.selfhost` file content as `ENV_SELFHOST` in that environment's secrets. A dedicated Cloudflare token must have the rights Alchemy needs for Workers, KV, D1, R2, Workflows, Secrets Store read, Account Settings read and, if Alchemy manages the Access app, Access write. Verify against the current [upstream Cloudflare guide](https://github.com/every-app/open-seo/blob/main/docs/SELF_HOSTING_CLOUDFLARE.md) and [Alchemy deployment notes](https://github.com/every-app/open-seo/blob/main/docs/maintainers/preview-deployments.md). Do not copy an interactive local Alchemy profile into GitHub.
4. Set environment variables `OPENSEO_HEALTH_URL=https://openseo.tevpro.com/api/health`, `OPENSEO_CONFIG_VERIFIED=true`, and `OPENSEO_DEPLOY_ENABLED=true` **only after** the inventory, backup, permissions test, required-reviewer rule, and current config comparison are complete. Both switches default to disabled when absent. If a test run is needed before this, use a separate, isolated Cloudflare account/stage, never the existing `selfhost` stage.
5. Confirm fork Actions are allowed to create pull requests (for upstream intake), and require the `CI` jobs on `main` before dispatching a deploy. Keep the repo's `main` branch protected against unreviewed upstream merges.

## Production release

After a reviewed update PR merges and `CI` passes on its `main` commit, manually dispatch **Tevpro OpenSEO production deploy** against `main`. The job verifies that it is deploying the current `main` SHA with a successful push CI run, restores the full reviewed env file with owner-only permissions, and runs `pnpm deploy:selfhost --yes`. It records the SHA and checks only edge reachability of `/api/health`. Cloudflare Access can return 401 or redirect, so this check does **not** establish database or MCP health.

An authorized operator must then check authenticated `/api/health` including database status, browser login, and OAuth MCP `whoami`/tool discovery. Confirm existing projects and integrations survived the release. Record that result and the previous working commit in the release run/PR. If validation fails, stop further deploys and investigate migrations and bindings before attempting a code rollback.

Do not put a service token in the workflow merely to imitate the human OAuth MCP check; those are different authentication paths. Keep the existing Cloudflare Access policy and Managed OAuth settings intact.
