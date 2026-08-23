# Documentation website — how to publish (maintainer guide)

The docs site lives at **https://iqbaladr.github.io/aksara/**. It's built with
[MkDocs Material](https://squidfunk.github.io/mkdocs-material/) from the Markdown in
[`docs/`](docs/) and deployed to **GitHub Pages** by
[`.github/workflows/docs.yml`](.github/workflows/docs.yml).

- **Source:** `docs/*.md` (pages) + [`mkdocs.yml`](mkdocs.yml) (theme + nav).
- **Build output:** `site/` (git-ignored — never committed).
- **Deploy:** automatic on every push to `main` that touches `docs/**` or `mkdocs.yml`.

---

## One-time setup (required once)

GitHub Pages must be told to deploy from the Actions workflow. Do **either**:

**A. In the UI**
1. Repo **Settings → Pages**.
2. Under **Build and deployment → Source**, choose **GitHub Actions**.

**B. From the CLI**
```bash
gh api --method POST repos/iQbalADR/aksara/pages -f build_type=workflow
```

After that, the first deployment runs automatically (or trigger it — see below).
The live URL appears in **Settings → Pages** and on the workflow run's summary.

---

## Deploying

- **Automatic:** push a change to `docs/**` or `mkdocs.yml` on `main`.
- **Manual:** repo **Actions → Docs → Run workflow**, or:
  ```bash
  gh workflow run "Docs" --repo iQbalADR/aksara
  ```

The `Docs` workflow builds with `mkdocs build --strict` (fails on broken links) and
publishes via `actions/deploy-pages`.

---

## Editing the site

1. Edit or add Markdown files under [`docs/`](docs/).
2. If you add a **new page**, list it under `nav:` in [`mkdocs.yml`](mkdocs.yml).
3. Push to `main` — it redeploys.

### Preview locally

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install "mkdocs-material==9.7.7"
mkdocs serve            # http://127.0.0.1:8000  (live reload)
# one-off build:
mkdocs build --strict   # outputs to ./site
```

---

## Optional: custom domain

1. Add a file `docs/CNAME` containing your domain (e.g. `aksara.dev`).
2. Configure the DNS record with your provider.
3. Set the domain in **Settings → Pages → Custom domain**.

## Notes

- Keep links between pages **relative** (`installation.md`, not `/installation.md`) so
  `--strict` passes. Link to repo files (README, podspec) with absolute GitHub URLs.
- Pin the `mkdocs-material` version in both this guide and `docs.yml` so local and CI
  builds match.
