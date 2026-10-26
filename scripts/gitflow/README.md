# Course repository

You build this project stage by stage (stage 1 → 3) in your own branches and
share each result with the team. The gitflow scripts that do the git work come
in three copies, one per operating system. Pick yours:

| Your OS | Scripts | Guide |
|---|---|---|
| Linux | `linux/*.sh` | [linux/README.md](linux/README.md) |
| macOS | `macos/*.tool` | [macos/README.md](macos/README.md) |
| Windows | `win\*.cmd` (run on Git for Windows) | [win/README.md](win/README.md) |

## Joining, in short

1. Get your OS folder (`linux/`, `macos/` or `win/`) from your tutor.
2. Make a new, empty project folder and put that folder in it.
3. From the project folder, run its `gitflow_init` with your nickname:

   | OS | Command |
   |---|---|
   | Linux | `bash linux/gitflow_init.sh --devname alice` |
   | macOS | `bash macos/gitflow_init.tool --devname alice` (or double-click it) |
   | Windows | `win\gitflow_init.cmd --devname alice` (or double-click it) |

The repository is cloned right into the project folder; your guide takes it
from there.

## What's in the repository

| Path | What it is |
|---|---|
| `app/` | The application you build, with the stage material (`stage1/`, `stage2/`, `stage3/`) |
| `docker-compose.yaml`, `nginx/` | The local stack; `deploy` has its own production compose |
| `VERSION` | The project version, `G.F.P` (F = stage number) |
| `gitflow.conf` | Settings shared by all three script sets |
| `linux/`, `macos/`, `win/` | The gitflow scripts and their guide, one folder per OS |
