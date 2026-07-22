# Command Background Actions

Background delivery runs a prompt through a local Claude or Codex CLI without opening an assistant window. Command records each run locally so you can inspect status, result, and logs.

## Before You Start

- Install Node.js 20 or later.
- Install and sign in to Claude CLI, Codex CLI, or both.
- Choose an existing working directory. Codex requires a valid workspace path.

Command does not manage CLI accounts, network access, tools, or file permissions. Those come from your local CLI configuration and selected execution settings.

## Configure A Provider

1. Open **Settings -> Background**.
2. Under **Claude CLI** or **Codex CLI**, enter command and working directory.
3. For Codex, choose **Read-only** or **Workspace changes**. Read-only is safer default.
4. Put each optional extra argument on its own line.
5. Click provider test button.
6. Click **Save** after test succeeds.

Use **Reveal in Finder** to inspect local background records and logs. Legacy fields support older imported actions; new Custom Actions use prompt and skill configured on action itself.

## Create A Background Action

1. Open **Settings -> Shortcut Settings**.
2. Under **Custom Actions**, click **Add**.
3. Choose **Claude**, **ChatGPT**, or **Default** for provider.
4. Set **Delivery** to **Background**.
5. Write prompt. Add optional Background skill when your CLI has one configured.
6. Save, then add Selected text, Screenshot, Popup, or Voice trigger.
7. Bind shortcut and run it.

Provider can be inherited from top-level default, set on action, or overridden on individual trigger. Destination and auto-submit do not apply to Background delivery.

## Prompt Inputs

| Input | Behavior |
|---|---|
| `{selection}` | Selected, typed, or spoken text. Appended automatically when omitted. |
| `{context}` | Matching Context rule text. |
| `{url}` | Source URL when Command can read it. |
| `{file}` | Screenshot file path for Background screenshot trigger. |

Selected-text trigger falls back to clipboard when no text is selected. Screenshot trigger needs Screen Recording permission. Voice trigger needs enabled dictation, Microphone permission, and downloaded model.

## Results And History

Open **Settings -> History** to review Foreground and Background runs. Retention defaults to seven days.

If final non-empty CLI output line is exactly `KEY=value`, Command stores value as structured result and shows it in notification and History. Only final line counts.

```text
TASK_ID=abc123
```

Command does not run another action from result automatically. Use run log to inspect full CLI output.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Provider test fails | Confirm command path, CLI sign-in, and working directory. |
| Codex workspace not found | Choose existing folder in **Settings -> Background**. |
| Run remains Running | Open **Settings -> History**, mark failed, then retry. |
| Screenshot has no image | Grant Screen Recording and restart Command. |
| Voice action does not start | Enable dictation, grant Microphone, and download model. |
| Result missing | Put `KEY=value` on final non-empty output line. |

For provider fields and defaults, see [Settings Reference](SETTINGS_REFERENCE.md). For app-wide checks and log locations, see [Troubleshooting](TROUBLESHOOTING.md). For local data behavior, see [Privacy](PRIVACY.md).
