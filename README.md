# PC Remote (1405/08/19)

Full remote access to the owner's Windows computers (any project: NMarketing node, InstAI A/B, ...), like a VPS.
Independent of NMarketing (NMarketing's own panel «دستورها» go through its agent instead).

- `pc invite [HOURS]` -> `out/PC-Remote-Setup-<id>.bat`; run it once on each computer (asks for Administrator).
- `pc` lists the computers; `pc NAME` = PowerShell as Administrator; `pc NAME run '...'`; `pc NAME put|get`.
- `pc remove NAME`; on the computer: `PC-Remote-Setup.bat remove`.
- Server side: `install.sh` (users pcremote / pcenroll, sshd `61-pc-remote.conf`, sudo rule, `/root/.ssh/pc_admin`).
- Safety: the computer's sshd listens on its own 127.0.0.1 only, keys only; the tunnel key may only open its own port
  on this server's 127.0.0.1; the invitation key may only run `bin/pc-enroll`; the computers' host keys are pinned.
- `selftest.sh`: end-to-end test with a stand-in computer.
