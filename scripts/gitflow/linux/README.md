# Gitflow scripts: developer guide (Linux)

You develop the project stage by stage (stage 1 → 3) in your own branches and
share each result with the team. These bash scripts initiate the project and do the git work for you.
They sit in the project's `linux/` folder next to this guide (macOS and
Windows have their own copies in `macos/` and `win/`). Run them from the
project root as `linux/<script>.sh`; they find the project from their own
folder, so any directory inside the project works too. Each script prints its
own help with `--help`, asks for a missing argument, and asks before every
push.

## How the branches work

| Branch | Whose | What it's for |
|---|---|---|
| `master` | the tutor's | The team's shared display. You **never push to it**: you open a pull request and the tutor merges it. |
| `dev/<you>` | yours | Your finished stages, one after another. |
| `stage-<N>/<you>/<name>` | yours | The stage you're building right now. |
| `deploy` | everyone | What the production server runs. Whoever promotes last is what goes live. |

Versions use the format `G.F.P`, kept in the `VERSION` file at the root:
- `G` changes only when the tutor says so;
- `F` is the **stage number**;
- `P` goes up by one on every commit.

Every commit message starts with the version: `1.2.3 <subject>`.

## 0. What you need

- **`git`, `curl`, `bash`** — the joining script won't run without them (any distribution's packages will do).
- **`gh`** (GitHub CLI, <https://cli.github.com>) — the joining script logs you in if needed.
- **Docker with Compose** — needed for the local test stack.
- **A GitHub account** — the tutor must invite you to the repository.

## 1. First steps to join the course

Create a new folder for the project and put the `linux/` folder from your
tutor in it (it holds `gitflow_init.sh` and this `README.md`). The folder
that holds `linux/` becomes the project root, and the repository is cloned
right into it. Pick a lowercase nickname; it becomes part of your branch
names (left out, the script asks for it).

```bash
mkdir digit-recognition && cd digit-recognition
# put the linux/ folder here, then:
bash linux/gitflow_init.sh --devname alice
```

The script asks for:
- GitHub login (if `gh` isn't logged in yet);
- `https` or `ssh`;
- the repository (`owner/name`, from the tutor). It accepts your pending invitation if you have one;
- your name and email for commits.

When it finishes, the folder holds the whole project with `dev/alice`
checked out and pushed:
- **Files you placed there that the repository also has:** identical ones are just taken over. If yours differ, the script asks before replacing them with the repository's version, and keeps your copies in `.git/gitflow-replaced/`.
- **Any other files:** stay as they are, untracked.
- **If the folder sits inside another git repository, or is your home folder:** the script stops. Use a new folder outside any repository.

On a **new machine**, do the same again: it resumes your existing
`dev/alice` instead of creating a new one. Inside an existing clone, run
`linux/gitflow_init.sh --devname alice` to set that clone up.

## 2. Start a stage

```bash
cd <project folder>
linux/new_stage.sh --number 1 --name binary-classification
```

- You're now on `stage-1/alice/binary-classification`.
- `VERSION` is `1.1.0`.
- The first commit, `1.1.0 start stage 1: binary-classification`, is made for you.
- If you had uncommitted changes, the script offers to stash them first.
- Only one open branch per stage number is allowed: finish it before starting it again.

## 3. Work and commit

Every commit raises P by one. Do it like this:

```bash
V=$(cat VERSION); NEW="${V%.*}.$(( ${V##*.} + 1 ))"   # 1.1.0 -> 1.1.1
echo "$NEW" > VERSION
git add -A
git commit -m "$NEW add the stage 1 neuron"
git push                                             # optional backup, any time
```

## 4. Test it locally in Docker

```bash
linux/dr_rebuild.sh            # build, (image tests), restart, curl check
linux/dr_rebuild.sh --no-cache # full rebuild
linux/dr_rebuild.sh --check-only
```

- A successful run ends with `http://127.0.0.1:<port>/ -> 200`. Open that URL and try your stage by hand.
- The image starts `gunicorn app:app`, so nothing answers until `app/app.py` exists. Expect failures at the very start of stage 1.

## 5. Finish the stage

Commit everything first, then run:

```bash
linux/finish_stage.sh
```

1. It runs the automated tests (if the repo has any).
2. It asks whether your manual Docker test passed.
3. It merges the stage into `dev/alice`, pushes it, and offers to delete the stage branch.

You end up on `dev/alice`.

**If it reports a conflict:** the merge is cancelled and you're back on the
stage branch. Resolve it there, then run `finish_stage.sh` again:

```bash
git merge dev/alice      # fix the files git lists, then:
git add -A && git commit -m "$(cat VERSION) merge: dev/alice → stage branch"
linux/finish_stage.sh
```

## 6. Share your work with the team

```bash
linux/promote_master.sh
```

- It opens a pull request from `dev/alice` to `master`, or updates the one that's already open, and prints the link.
- The tutor reviews and merges it.
- Conflicts between your version and other developers' versions on `master` are expected, and they're the tutor's job, not yours.

## 7. Put your version on production (optional)

```bash
linux/promote_deploy.sh
```

- `deploy` becomes your `dev/alice` (incoming dev wins). The production-only files, like the server's `docker-compose.yaml`, are kept.
- It runs in a temporary folder, so your checkout doesn't change branch.
- It shows what production will receive, then asks before pushing.
- This is **not** a release: the tutor pulls `deploy` on the server and rebuilds it there.

## Taking other people's work from `master` (optional, by hand)

```bash
git checkout dev/alice
git pull --ff-only
git fetch origin
git merge --no-ff --no-commit origin/master
# VERSION conflict? keep the higher of the two values
git commit -m "$(cat VERSION) merge: master → dev/alice"
git push
```

## The rules, in short

- Never push to `master` and never force-push. No `git rebase` or `git reset --hard` on shared branches.
- Start a stage from your own `dev/<you>` (`new_stage.sh` does this for you).
- Every commit message starts with `G.F.P`, and P goes up by one per commit.
- Commit or stash before running a script; the scripts stop on a dirty tree.

## When something goes wrong

| Message | What to do |
|---|---|
| `no developer name in this clone` | `linux/gitflow_init.sh --devname <you>` at the project root |
| `uncommitted changes` | commit them, or `git stash push -u -m "wip <branch>"` |
| `dev/<you> is behind origin` / `has diverged` | `git checkout dev/<you> && git pull --ff-only`; if that fails, merge `origin/dev/<you>` by hand |
| `you already have a stage-N branch` | finish it (`linux/finish_stage.sh`) or delete it |
| `gh is not logged in` | `gh auth login` |
| `cannot see <repo>` / `cannot push` | ask the tutor to invite you |
| `... is inside the git repository ...` / `the project root would be ...` | the project folder must be a new folder, not your home folder and not inside another repository |
| `... is not inside a clone of the course repository` | the scripts must sit in the `linux/` folder of your clone — join first with `linux/gitflow_init.sh` |
| `... did not answer 200 within 60 s` | read the log lines printed above it (`docker compose logs web_server`) |
