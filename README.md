# PC Remote

**فارسی** | [English](#english)

<div dir="rtl" align="right">

## این چیست؟

PC Remote یک ابزارِ **مستقل** است (جدا از NMarketing، InstAI و هر پروژهٔ دیگر): کامپیوترهای ویندوزیِ مالک را مثلِ یک سرور (VPS) در دسترسِ مدیرِ سرور می‌گذارد؛ PowerShell با دسترسیِ Administrator، اجرای یک فرمان، و کپیِ فایل در دو جهت.

هیچ پورتی روی اینترنت یا شبکهٔ محلیِ کامپیوتر باز نمی‌شود. خودِ کامپیوتر یک **تونلِ رمزنگاری‌شده (SSH معکوس)** به سرور نگه می‌دارد و سرورِ SSH ِ ویندوز فقط روی `127.0.0.1` ِ خودِ همان کامپیوتر گوش می‌دهد، آن هم فقط با کلید (نه رمز).

```
 کامپیوتر ویندوزی  ──(تونل رمزنگاری‌شده، از خودِ کامپیوتر شروع می‌شود)──▶  سرور (VPS)
   sshd روی 127.0.0.1                                                    دستورِ  pc NAME
```

## نصب روی سرور

پیش‌نیاز: اوبونتو ۲۲٫۰۴ یا بالاتر، دسترسیِ root، و بسته‌های `openssh-server`، `python3`، `sudo`، `curl`.

```bash
git clone https://github.com/maniUZqqz/Remote-d.git /opt/pc-remote
cd /opt/pc-remote && sudo bash install.sh
```

`install.sh` تکرارپذیر است (هر بار اجرا کنید چیزِ خراب نمی‌کند) و این‌ها را آماده می‌کند:

- کاربرِ `pcremote`: فقط برای تونل؛ بی‌شِل، و هر کلیدش فقط مجاز است **پورتِ خودش** را روی `127.0.0.1` ِ سرور باز کند.
- کاربرِ `pcenroll`: کلیدِ دعوتِ داخلِ فایلِ راه‌اندازی با آن وارد می‌شود و فقط می‌تواند `bin/pc-enroll` را اجرا کند (از راهِ یک قاعدهٔ باریکِ sudo).
- فایلِ تنظیمِ sshd به نامِ `/etc/ssh/sshd_config.d/61-pc-remote.conf` و قاعدهٔ `/etc/sudoers.d/pc-remote`.
- کلیدِ مدیر `/root/.ssh/pc_admin` (که `pc` با آن به کامپیوترها وارد می‌شود) و فایلِ `/root/.ssh/pc_known_hosts` برای سنجاق کردنِ کلیدِ هر کامپیوتر.
- دستورِ `pc` در `/usr/local/bin`، و بستهٔ OpenSSH ِ ویندوز در `windows/` (برای کامپیوترهایی که ویندوزشان خودش نمی‌تواند «OpenSSH Server» را اضافه کند). این بسته در گیت نیست؛ `install.sh` آن را یک بار از انتشارِ رسمیِ Win32-OpenSSH می‌گیرد و با SHA-256 ِ ثبت‌شده در `bin/pc` می‌سنجد.
- یک قلابِ pre-commit که اجازه نمی‌دهد کلید یا فایلِ دعوت وارد گیت شود (`bin/check-public.sh`).

نشانیِ سرور (`PUBLIC_HOST`) در `bin/pc` و `bin/pc-enroll` است؛ برای سرورِ دیگر آن‌جا عوضش کنید.

## گرفتنِ فایلِ راه‌اندازی (`pc invite`)

```bash
pc invite 72        # ۷۲ ساعت اعتبار؛ بی عدد = ۷۲
# → /opt/pc-remote/out/PC-Remote-Setup-<شناسه>.bat
```

این فایل را **یک بار** روی هر کامپیوتر اجرا می‌کنید. یک فایل برای هر تعداد کامپیوتر کار می‌کند تا وقتی اعتبارش تمام نشده.

> ### ⚠ این فایل محرمانه است
> داخلِ فایلِ راه‌اندازی **کلیدِ خصوصیِ دعوت** هست؛ هر کس آن را داشته باشد تا پایانِ اعتبار می‌تواند یک کامپیوتر را در سرور ثبت کند. پس:
> - **هرگز در گیت‌هاب (یا هر مخزنِ عمومی)، کانالِ عمومی، یا هر پوشهٔ همگانی نگذاریدش.** پوشهٔ `out/` در `.gitignore` است و دسترسیِ آن فقط root است؛ قلابِ pre-commit هم جلوی افزودنش را می‌گیرد.
> - **خصوصی تحویل بدهید:** از کامپیوترِ خودتان با `scp root@<سرور>:/opt/pc-remote/out/PC-Remote-Setup-<شناسه>.bat .` بردارید، یا (برای کامپیوتری که قبلاً ثبت شده) `pc NAME put /opt/pc-remote/out/PC-Remote-Setup-<شناسه>.bat C:/Users/<کاربر>/Desktop/PC-Remote-Setup.bat`.
> - اعتبارش را کوتاه بگیرید (مثلاً `pc invite 2`) و وقتی کامپیوترها ثبت شدند، دعوت را باطل کنید: `pc revoke <شناسه>`.

## روی ویندوز

۱. فایلِ `PC-Remote-Setup.bat` را دو بار کلیک کنید و در پنجرهٔ ویندوز «Yes» بزنید (دسترسیِ Administrator لازم است). ویندوز باید `ssh.exe` داشته باشد (ویندوز ۱۰/۱۱ معمولاً دارد؛ اگر نه: تنظیمات ▸ برنامه‌ها ▸ ویژگی‌های اختیاری ▸ «OpenSSH Client»).

۲. فایل شش گام را خودش می‌رود و روی صفحه می‌نویسد: [۱] سرورِ OpenSSH (اضافه کردنِ ویژگیِ ویندوز، یا گرفتنِ بسته از سرور) ـ [۲] فقط روی `127.0.0.1` و فقط با کلید ـ [۳] کلیدِ تونل ـ [۴] ثبت در سرور ـ [۵] کلیدِ مدیر ـ [۶] تونل، به‌صورت یک کارِ زمان‌بندی‌شده (`\PCRemote\PC Remote tunnel`، با SYSTEM، از روشن شدنِ ویندوز، و اگر قطع شود دوباره وصل می‌شود).

۳. بعد از نصب، روی Public Desktop پوشه‌ای به نامِ **PC Remote** و راهنمای فارسیِ «PC Remote - Guide.html» ساخته می‌شود. در آن پوشه یک رونوشت از فایلِ راه‌اندازی و `PC Remote.bat` هست که پنجرهٔ کنترل را باز می‌کند: وضعیت، وصل/قطعِ تونل، شروعِ خودکار با ویندوز، نمایشِ راهنما، راه‌اندازی/تعمیر، و حذف. اجرای دوبارهٔ خودِ فایل هم همین پنجره را باز می‌کند؛ `PC-Remote-Setup.bat setup` راه‌اندازی/تعمیرِ دوباره است.

   توجه: آن رونوشت هم کلیدِ دعوت را دارد و برای همهٔ کاربرانِ همان کامپیوتر خواندنی است. وقتی کار تمام شد دعوت را با `pc revoke` باطل کنید (تونلِ نصب‌شده با کلیدِ خودش کار می‌کند و تأثیری نمی‌بیند؛ فقط «راه‌اندازی/تعمیرِ دوباره» یک فایلِ تازه از `pc invite` می‌خواهد).

۴. فایل‌های ابزار در `C:\ProgramData\PCRemote` هستند (فقط برای Administrators و SYSTEM می‌خواندنی).

## کار با کامپیوترها (روی سرور)

| دستور | کار |
|---|---|
| `pc` | فهرستِ کامپیوترها (تونل بالا/پایین) و دعوت‌های فعال |
| `pc NAME` | PowerShell ِ تعاملی با دسترسیِ Administrator |
| `pc NAME run 'فرمان'` | اجرای یک فرمانِ PowerShell |
| `pc NAME put محلی راه‌دور` | فرستادنِ فایل (راه‌دور مثلِ `C:/Users/QQz/Desktop/x.txt`) |
| `pc NAME get راه‌دور محلی` | گرفتنِ فایل |
| `pc invite [ساعت]` | فایلِ راه‌اندازیِ تازه |
| `pc revoke شناسه` | باطل کردنِ یک دعوت (و پاک کردنِ فایلِ آن در `out/`) |
| `pc remove NAME` | فراموش کردنِ یک کامپیوتر (کلیدِ تونلش از کار می‌افتد) |

آزمونِ سرتاسریِ سمتِ سرور با یک «کامپیوترِ ساختگی»: `bash selftest.sh`.

## برداشتن

- **روی کامپیوتر:** `PC-Remote-Setup.bat remove` (یا دکمهٔ «برداشتن» در پنجرهٔ کنترل). کارِ تونل، پردازشِ ssh ِ تونل، خط‌های کلیدِ مدیر، و پوشهٔ `C:\ProgramData\PCRemote` را پاک می‌کند و سرورِ OpenSSH را متوقف و «دستی» می‌کند. پوشهٔ **PC Remote** روی Public Desktop را اگر نخواستید خودتان پاک کنید.
- **روی سرور:** `pc remove NAME`.
- **کلِ ابزار از سرور:** `rm /etc/ssh/sshd_config.d/61-pc-remote.conf /etc/sudoers.d/pc-remote /usr/local/bin/pc; systemctl reload ssh; userdel -r pcremote; userdel -r pcenroll`.

## امنیت، خلاصه

- کامپیوتر هیچ پورتی باز نمی‌کند؛ تونل از خودِ کامپیوتر شروع می‌شود و sshd فقط روی `127.0.0.1` است، فقط با کلید.
- کلیدِ تونلِ هر کامپیوتر فقط پورتِ خودش را روی `127.0.0.1` ِ سرور می‌تواند باز کند و شِل ندارد.
- کلیدِ دعوت فقط سه کار می‌تواند: ثبتِ یک کامپیوتر، بررسیِ تونلِ یک کامپیوترِ ثبت‌شده، و گرفتنِ بستهٔ OpenSSH. کامپیوترِ ثبت‌شده را فقط خودش (همان کلیدِ میزبان) می‌تواند دوباره ثبت کند؛ فایلِ کپی‌شده جایش را نمی‌گیرد.
- کلیدِ میزبانِ هر کامپیوتر در `/root/.ssh/pc_known_hosts` سنجاق می‌شود (هرگز `accept-new`).
- پوشه‌های `nodes/`، `invites/`، `out/` و فایلِ `invites.json` (وضعیتِ زنده و کلیدها) فقط روی سرور می‌مانند و در `.gitignore` هستند.

### اگر فایلِ راه‌اندازی لو رفت یا جایی عمومی گذاشته شد

۱. `pc` را بزنید و ببینید کامپیوترِ ناشناسی ثبت نشده باشد (اگر بود: `pc remove NAME`).
۲. `pc revoke <شناسه>` ← کلیدِ دعوت و فایلِ آن همان لحظه از کار می‌افتد. کامپیوترهایی که پیش‌تر ثبت شده‌اند ادامه می‌دهند (آن‌ها کلیدِ تونلِ خودشان را دارند، نه کلیدِ دعوت).
۳. با `pc invite` یک فایلِ تازه بسازید. توجه: پاک کردنِ فایل از آخرینِ نسخهٔ یک مخزن آن را از **تاریخچهٔ** مخزن پاک نمی‌کند؛ کلیدی که یک بار عمومی شده را همیشه لو‌رفته بدانید.

### یادداشتِ جدا شدن از NMarketing

تا ۱۴۰۵/۰۸/۲۶ یک نسخه از فایلِ راه‌اندازی همراهِ بستهٔ به‌روزرسانیِ NMarketing و مخزنِ عمومیِ آن هم می‌رفت. حالا از NMarketing جدا شده و فقط از همین مخزن + دستِ مدیر می‌آید؛ آن نسخه‌های قدیمی در تاریخچهٔ آن مخزن می‌مانند، پس کلیدِ دعوتِ آن‌ها را لو‌رفته بدانید و باطل کنید.

</div>

---

<a id="english"></a>

## English

### What it is

PC Remote is a **standalone** tool (independent of NMarketing, InstAI or any other project) that puts the owner's Windows computers within reach of the server administrator as if they were servers: an interactive PowerShell as Administrator, one-off commands, and file copy both ways.

Nothing is opened to the internet or to the computer's LAN. The computer keeps an encrypted **reverse SSH tunnel** to the server, and its Windows OpenSSH server listens on that computer's own `127.0.0.1` only, with keys only (no passwords).

### Server install

Needs Ubuntu 22.04+, root, and `openssh-server`, `python3`, `sudo`, `curl`.

```bash
git clone https://github.com/maniUZqqz/Remote-d.git /opt/pc-remote
cd /opt/pc-remote && sudo bash install.sh
```

`install.sh` is idempotent. It sets up: user `pcremote` (tunnel only, no shell; each computer's key may only open ITS port on the server's `127.0.0.1`); user `pcenroll` (the invitation key inside a setup file logs in as it and may only run `bin/pc-enroll`, through one narrow sudo rule); the sshd drop-in `/etc/ssh/sshd_config.d/61-pc-remote.conf` and `/etc/sudoers.d/pc-remote`; the admin key `/root/.ssh/pc_admin` that `pc` uses, and `/root/.ssh/pc_known_hosts` where each computer's host key is pinned; the `pc` command in `/usr/local/bin`; the Windows OpenSSH package in `windows/` (for computers whose Windows cannot add the OpenSSH Server feature by itself; it is not in git, `install.sh` downloads it once from the official Win32-OpenSSH release and checks the SHA-256 pinned in `bin/pc`); and a pre-commit hook (`bin/check-public.sh`) that refuses keys or invitation files.

The server address (`PUBLIC_HOST`) is set in `bin/pc` and `bin/pc-enroll`; change it there for another server.

### Making the setup file (`pc invite`)

```bash
pc invite 72        # valid for 72 hours (the default)
# -> /opt/pc-remote/out/PC-Remote-Setup-<id>.bat
```

Run that file once on each computer. One file serves any number of computers until it expires.

> **The setup file is a secret.** It embeds the *private invitation key*: whoever holds it can register a computer on your server until it expires.
> - **Never put it on GitHub (or any public repository), a public channel or a shared folder.** `out/` is root-only and in `.gitignore`, and the pre-commit hook refuses it.
> - **Hand it over privately:** fetch it from your own machine with `scp root@<server>:/opt/pc-remote/out/PC-Remote-Setup-<id>.bat .`, or, to an already enrolled computer, `pc NAME put /opt/pc-remote/out/PC-Remote-Setup-<id>.bat C:/Users/<user>/Desktop/PC-Remote-Setup.bat`.
> - Keep the validity short (`pc invite 2`) and revoke the invitation once your computers are registered: `pc revoke <id>`.

### On Windows

1. Double-click `PC-Remote-Setup.bat` and answer "Yes" (Administrator rights are needed). Windows must have `ssh.exe` (Windows 10/11 usually does; otherwise Settings > Apps > Optional features > "OpenSSH Client").
2. It goes through six steps and prints each: [1] OpenSSH server (the Windows feature, or the package from the server) - [2] listening on `127.0.0.1` only, keys only - [3] tunnel key - [4] registering with the server - [5] the administrator key - [6] the tunnel as a scheduled task (`\PCRemote\PC Remote tunnel`, runs as SYSTEM from Windows start-up and reconnects if it drops).
3. Afterwards a folder **PC Remote** and a Persian guide (`PC Remote - Guide.html`) appear on the Public Desktop. The folder holds a copy of the setup file and `PC Remote.bat`, which opens the control window: status, connect now / disconnect now, start with Windows, show the guide, set up / repair, and remove. Running the setup file again opens the same window; `PC-Remote-Setup.bat setup` repairs/re-installs.

   Note: that copy also contains the invitation key and is readable by every user of that computer. When you are done, revoke the invitation with `pc revoke` (the installed tunnel runs on the computer's own key and is not affected; only "set up / repair" then needs a fresh file from `pc invite`).
4. The tool's files live in `C:\ProgramData\PCRemote` (readable by Administrators and SYSTEM only).

### Working with the computers (on the server)

| Command | What it does |
|---|---|
| `pc` | list the computers (tunnel up/down) and the live invitations |
| `pc NAME` | interactive PowerShell as Administrator |
| `pc NAME run 'COMMAND'` | run one PowerShell command |
| `pc NAME put LOCAL REMOTE` | copy a file to it (REMOTE like `C:/Users/QQz/Desktop/x.txt`) |
| `pc NAME get REMOTE LOCAL` | copy a file from it |
| `pc invite [HOURS]` | a new setup file |
| `pc revoke ID` | revoke an invitation (its key stops working and its file in `out/` is deleted) |
| `pc remove NAME` | forget a computer (its tunnel key stops working) |

End-to-end test of the server side with a stand-in computer: `bash selftest.sh`.

### Remove

- **On the computer:** `PC-Remote-Setup.bat remove` (or the control window's remove button). It stops and deletes the scheduled task, ends the tunnel's ssh process, deletes its lines from the administrator keys, stops the OpenSSH server (start-up: manual) and deletes `C:\ProgramData\PCRemote`. The **PC Remote** folder on the Public Desktop is left; delete it by hand if you want.
- **On the server:** `pc remove NAME`.
- **The whole tool from the server:** `rm /etc/ssh/sshd_config.d/61-pc-remote.conf /etc/sudoers.d/pc-remote /usr/local/bin/pc; systemctl reload ssh; userdel -r pcremote; userdel -r pcenroll`.

### Safety in short

- The computer opens no port: the tunnel starts from the computer, and its sshd is on `127.0.0.1` with keys only.
- A computer's tunnel key can only open its own port on the server's `127.0.0.1` and has no shell.
- The invitation key can do three things only: register a computer, check a registered computer's tunnel, and fetch the OpenSSH package. A registered computer can only be re-registered by itself (same host key); a copied setup file does not take its place.
- Each computer's host key is pinned in `/root/.ssh/pc_known_hosts` (never `accept-new`).
- `nodes/`, `invites/`, `out/` and `invites.json` (live state and keys) stay on the server and are in `.gitignore`.

**If a setup file leaked or was posted somewhere public:** (1) run `pc` and check that no unknown computer enrolled (if one did: `pc remove NAME`); (2) `pc revoke <id>` - the key and its file stop working at once, and computers already registered keep working (they hold their own tunnel keys, not the invitation key); (3) make a new one with `pc invite`. Deleting the file from the latest version of a repository does not delete it from its **history**: treat a key that was ever public as burned.

### Separated from NMarketing

Until 2026-11-16 a copy of the setup file also shipped inside NMarketing's node update package and its public repository. It is now separate and comes only from this repository plus the administrator's hand. The old copies remain in that repository's history, so treat their invitation key as public and revoke it.
