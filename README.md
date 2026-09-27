# Upload-Codeforces-Submissions-DL

A small utility that downloads a Codeforces user's full submission history via the official [Codeforces API](https://codeforces.com/apiHelp) and saves it as a local JSON file. Requests are signed and retried automatically if they fail. This data is being collected for my PhD research.

Two equivalent implementations are included:

- `get_submissions.ps1` — PowerShell (Windows)
- `get_submissions.sh` — Bash (Linux/macOS)

Both take the same inputs and produce the same output: `data/submissions/<handle>_submissions.json`.

Please fill this [Google Form](https://docs.google.com/forms/d/e/1FAIpQLSeu7HDn3IjlPVEXwVW01DMtxURptSzq3nopQ0eUs2PZ1Ric8A/viewform) and upload the `<handle>_submissions.json` file.

## Prerequisites

You'll need a Codeforces API key and secret. Generate one from your Codeforces profile:

1. Go to your [Settings](https://codeforces.com/settings/api) page while logged in.
2. Under "API", click "Add API Key" and copy the generated **key** and **secret**.

Depending on which version you use:

| Version | Requirements |
|---|---|
| PowerShell | PowerShell 5.1+ (Windows) or PowerShell Core 7+ (cross-platform) |
| Bash | `curl`, `jq`, `sha512sum` (or `shasum` on macOS) |

If any of these are missing:

```bash
# Debian/Ubuntu
sudo apt install curl jq coreutils

# macOS (Homebrew)
brew install curl jq
```

## Usage

### Windows
#### PowerShell

```powershell
.\get_submissions.ps1 <handle> -ApiKey <your_key> -ApiSecret <your_secret>
```

Optional parameters: `-Retries` (default 3), `-Count` (default 100000).

If Windows blocks the script with an "is not digitally signed" error, either run it with the policy bypassed for that one call:

```powershell
powershell -ExecutionPolicy Bypass -File .\get_submissions.ps1 <handle> -ApiKey <your_key> -ApiSecret <your_secret>
```

or unblock the file once and allow local scripts for your user:

```powershell
Unblock-File -Path .\get_submissions.ps1
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Linux / MacOS
#### Bash

```bash
chmod +x get_submissions.sh
./get_submissions.sh <handle> --api_key <your_key> --api_secret <your_secret>
```

Optional flags: `--retries` (default 3), `--count` (default 100000).

## Output

Each run writes a single JSON file containing the full list of submissions returned by the Codeforces `user.status` endpoint:

```
data/submissions/<handle>_submissions.json
```

## Notes

- Requests are rate-limited with a 2-second pause between pages to stay within Codeforces' API limits.
- Failed requests are retried automatically (configurable via `--retries` / `-Retries`), with each failure logged.
- Keep your API key and secret private
