# Gitflow scripts: developer guide (Windows)

You develop the project stage by stage (stage 1 → 3) in your own branches and
share each result with the team. These scripts initiate the project and do the git work for you.
They sit in the project's `win\` folder next to this guide (Linux and macOS
have their own copies in `linux/` and `macos/`). Run them from the project
root as `win\<script>.cmd`; they find the project from their own
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

- **Git for Windows** (<https://git-scm.com/download/win>) — git itself, and the bash the `.cmd` scripts run on. Keep its default options.
- **`gh`** (GitHub CLI) — `winget install --id GitHub.cli`, or the installer from <https://cli.github.com>. The joining script logs you in if needed.
- **Docker Desktop for Windows** — needed for the local test stack.
- **A GitHub account** — the tutor must invite you to the repository.

### Running the scripts

- **In Command Prompt**, from the project root: `win\new_stage.cmd …`. **In PowerShell**: `.\win\new_stage.cmd …`.
- **Or double-click** a `.cmd` file in Explorer: it runs from the project's own folder, asks for anything it needs, and waits for a key before the window closes.
- Each `.cmd` file finds Git for Windows' `bash.exe` and runs its own bash part with it — the same code as the Linux and macOS scripts. The repository's `.gitattributes` keeps these files with LF line endings; leave it that way.
- The command snippets below are for **PowerShell**. In Git Bash, the Linux guide's snippets work as they are.

## 1. First steps to join the course

Create a new folder for the project and put the `win` folder from your tutor
in it (it holds `gitflow_init.cmd` and this `README.md`). The folder that
holds `win` becomes the project root, and the repository is cloned right
into it. Pick a lowercase nickname; it becomes part of your branch names
(left out, the script asks for it).

```powershell
mkdir digit-recognition; cd digit-recognition
# put the win folder here, then:
.\win\gitflow_init.cmd --devname alice
```

Or double-click `win\gitflow_init.cmd` in Explorer: it asks for the nickname.

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
`win\gitflow_init.cmd --devname alice` to set that clone up.

## 2. Start a stage

```powershell
cd <project folder>
.\win\new_stage.cmd --number 1 --name binary-classification
```

- You're now on `stage-1/alice/binary-classification`.
- `VERSION` is `1.1.0`.
- The first commit, `1.1.0 start stage 1: binary-classification`, is made for you.
- If you had uncommitted changes, the script offers to stash them first.
- Only one open branch per stage number is allowed: finish it before starting it again.

## 3. Work and commit

Every commit raises P by one. Do it like this (PowerShell):

```powershell
$v = (Get-Content VERSION).Trim().Split('.'); $v[2] = [int]$v[2] + 1; $new = $v -join '.'   # 1.1.0 -> 1.1.1
Set-Content VERSION $new
git add -A
git commit -m "$new add the stage 1 neuron"
git push                                             # optional backup, any time
```

## 4. Test it locally in Docker

```powershell
.\win\dr_rebuild.cmd            # build, (image tests), restart, curl check
.\win\dr_rebuild.cmd --no-cache # full rebuild
.\win\dr_rebuild.cmd --check-only
```

- A successful run ends with `http://127.0.0.1:<port>/ -> 200`. Open that URL and try your stage by hand.
- The image starts `gunicorn app:app`, so nothing answers until `app/app.py` exists. Expect failures at the very start of stage 1.

## 5. Finish the stage

Commit everything first, then run:

```powershell
.\win\finish_stage.cmd
```

1. It runs the automated tests (if the repo has any).
2. It asks whether your manual Docker test passed.
3. It merges the stage into `dev/alice`, pushes it, and offers to delete the stage branch.

You end up on `dev/alice`.

**If it reports a conflict:** the merge is cancelled and you're back on the
stage branch. Resolve it there, then run `finish_stage.cmd` again:

```powershell
git merge dev/alice      # fix the files git lists, then:
git add -A; git commit -m "$((Get-Content VERSION).Trim()) merge: dev/alice → stage branch"
.\win\finish_stage.cmd
```

## 6. Share your work with the team

```powershell
.\win\promote_master.cmd
```

- It opens a pull request from `dev/alice` to `master`, or updates the one that's already open, and prints the link.
- The tutor reviews and merges it.
- Conflicts between your version and other developers' versions on `master` are expected, and they're the tutor's job, not yours.

## 7. Put your version on production (optional)

```powershell
.\win\promote_deploy.cmd
```

- `deploy` becomes your `dev/alice` (incoming dev wins). The production-only files, like the server's `docker-compose.yaml`, are kept.
- It runs in a temporary folder, so your checkout doesn't change branch.
- It shows what production will receive, then asks before pushing.
- This is **not** a release: the tutor pulls `deploy` on the server and rebuilds it there.

## Taking other people's work from `master` (optional, by hand)

```powershell
git checkout dev/alice
git pull --ff-only
git fetch origin
git merge --no-ff --no-commit origin/master
# VERSION conflict? keep the higher of the two values
git commit -m "$((Get-Content VERSION).Trim()) merge: master → dev/alice"
git push
```

## The rules, in short

- Never push to `master` and never force-push. No `git rebase` or `git reset --hard` on shared branches.
- Start a stage from your own `dev/<you>` (`new_stage.cmd` does this for you).
- Every commit message starts with `G.F.P`, and P goes up by one per commit.
- Commit or stash before running a script; the scripts stop on a dirty tree.

## When something goes wrong

| Message | What to do |
|---|---|
| `no developer name in this clone` | `win\gitflow_init.cmd --devname <you>` at the project root |
| `uncommitted changes` | commit them, or `git stash push -u -m "wip <branch>"` |
| `dev/<you> is behind origin` / `has diverged` | `git checkout dev/<you>; git pull --ff-only`; if that fails, merge `origin/dev/<you>` by hand |
| `you already have a stage-N branch` | finish it (`win\finish_stage.cmd`) or delete it |
| `gh is not logged in` | `gh auth login` |
| `cannot see <repo>` / `cannot push` | ask the tutor to invite you |
| `... is inside the git repository ...` / `the project root would be ...` | the project folder must be a new folder, not your home folder and not inside another repository |
| `... is not inside a clone of the course repository` | the scripts must sit in the `win` folder of your clone — join first with `win\gitflow_init.cmd` |
| `... did not answer 200 within 60 s` | read the log lines printed above it (`docker compose logs web_server`) |
