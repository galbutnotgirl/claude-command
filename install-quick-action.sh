#!/bin/zsh
# install-quick-action.sh
# Generates + installs the "Send to Claude" macOS Quick Actions (Services) that
# appear in the right-click menu on selected text in any app. Each one is a thin
# launcher that calls send-to-claude.sh with a different ACTION.
#
# Actions installed as optional right-click Services (edit ACTIONS to add/remove).
# Global hotkeys are owned by Command; set-hotkeys.sh only binds Add/New,
# Screenshot Add/New, and Clipboard History by default.
# Installed Services:
#   Claude - Go         bg-feel: new session, submit, focus returns; Claude acts
#   Claude - New        new session pre-filled, foreground, you add a note & send
#   Claude - Add        paste selection into the already-open Claude chat
#   Claude - To-Do      legacy alias → background handoff
#
# Re-run safely (overwrites). Uninstall: ./uninstall-quick-action.sh

emulate -L zsh
set -uo pipefail

SCRIPT_DIR="${0:A:h}"
WORKER="${SCRIPT_DIR}/send-to-claude.sh"
SERVICES_DIR="${HOME}/Library/Services"

# label | ACTION env value  (names start with "Claude" so they group together)
# Text services — appear on a text selection + hotkey-bindable.
ACTIONS=(
  "Claude - Go|go"
  "Claude - New|comment"
  "Claude - Add|add"
  "Claude - To-Do|todo"
)
# No-input services — hotkey-driven, no selection needed (screenshots, picker).
NOINPUT_ACTIONS=(
  "Claude - Screenshot Go|shotgo"
  "Claude - Screenshot New|shotcomment"
  "Claude - Screenshot Add|shotadd"
  "Claude - Clipboard History|cliphistory"
)

[ -x "$WORKER" ] || chmod +x "$WORKER" 2>/dev/null
print -- "[install] worker: $WORKER"

make_bundle() {
  local name="$1" action="$2" intype="${3:-text}"
  local bundle="${SERVICES_DIR}/${name}.workflow"
  local in_uuid out_uuid act_uuid svc_input send_types
  in_uuid="$(uuidgen)"; out_uuid="$(uuidgen)"; act_uuid="$(uuidgen)"
  if [ "$intype" = "none" ]; then
    svc_input="com.apple.Automator.nothing"; send_types=""
  else
    svc_input="com.apple.Automator.text"; send_types="<string>NSStringPboardType</string>"
  fi
  mkdir -p "${bundle}/Contents"

  cat > "${bundle}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSMenuItem</key>
			<dict><key>default</key><string>${name}</string></dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
			<key>NSRequiredContext</key>
			<dict><key>NSServiceCategory</key><string>public.text</string></dict>
			<key>NSSendFileTypes</key>
			<array/>
			<key>NSSendTypes</key>
			<array>${send_types}</array>
		</dict>
	</array>
</dict>
</plist>
PLIST

  cat > "${bundle}/Contents/document.wflow" <<WFLOW
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key><string>521</string>
	<key>AMApplicationVersion</key><string>2.10</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key><string>List</string>
					<key>Optional</key><true/>
					<key>Types</key><array><string>com.apple.cocoa.string</string></array>
				</dict>
				<key>AMActionVersion</key><string>2.0.3</string>
				<key>AMApplication</key><array><string>Automator</string></array>
				<key>AMParameterProperties</key>
				<dict>
					<key>COMMAND_STRING</key><dict/>
					<key>CheckedForUserDefaultShell</key><dict/>
					<key>inputMethod</key><dict/>
					<key>shell</key><dict/>
					<key>source</key><dict/>
				</dict>
				<key>AMProvides</key>
				<dict>
					<key>Container</key><string>List</string>
					<key>Types</key><array><string>com.apple.cocoa.string</string></array>
				</dict>
				<key>ActionBundlePath</key><string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key><string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key><string>ACTION=${action} ${WORKER} 2&gt;/dev/null</string>
					<key>CheckedForUserDefaultShell</key><true/>
					<key>inputMethod</key><integer>0</integer>
					<key>shell</key><string>/bin/zsh</string>
					<key>source</key><string></string>
				</dict>
				<key>BundleIdentifier</key><string>com.apple.RunShellScript</string>
				<key>CFBundleVersion</key><string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key><false/>
				<key>CanShowWhenRun</key><true/>
				<key>Category</key><array><string>AMCategoryUtilities</string></array>
				<key>Class Name</key><string>RunShellScriptAction</string>
				<key>InputUUID</key><string>${in_uuid}</string>
				<key>Keywords</key><array><string>Shell</string></array>
				<key>OutputUUID</key><string>${out_uuid}</string>
				<key>UUID</key><string>${act_uuid}</string>
				<key>UnlocalizedApplications</key><array><string>Automator</string></array>
				<key>arguments</key><dict/>
				<key>isViewVisible</key><integer>1</integer>
				<key>location</key><string>449.000000:316.000000</string>
				<key>nibPath</key><string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
			</dict>
			<key>isViewVisible</key><integer>1</integer>
		</dict>
	</array>
	<key>connectors</key><dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>applicationBundleIDsByPath</key><dict/>
		<key>applicationPaths</key><array/>
		<key>inputTypeIdentifier</key><string>${svc_input}</string>
		<key>outputTypeIdentifier</key><string>com.apple.Automator.nothing</string>
		<key>presentationMode</key><integer>11</integer>
		<key>processesInput</key><integer>0</integer>
		<key>serviceApplicationBundleID</key><string></string>
		<key>serviceApplicationPath</key><string></string>
		<key>serviceInputTypeIdentifier</key><string>${svc_input}</string>
		<key>serviceOutputTypeIdentifier</key><string>com.apple.Automator.nothing</string>
		<key>serviceProcessesInput</key><integer>0</integer>
		<key>systemImageName</key><string>NSActionTemplate</string>
		<key>useAutomaticInputType</key><integer>0</integer>
		<key>workflowTypeIdentifier</key><string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
WFLOW

  plutil -lint "${bundle}/Contents/Info.plist" >/dev/null || { print -- "[install] ERROR Info.plist lint ($name)"; return 1; }
  plutil -lint "${bundle}/Contents/document.wflow" >/dev/null || { print -- "[install] ERROR wflow lint ($name)"; return 1; }
  print -- "[install] wrote: ${name}.workflow  (ACTION=${action})"
}

for entry in "${ACTIONS[@]}"; do
  make_bundle "${entry%%|*}" "${entry##*|}" text || exit 1
done
for entry in "${NOINPUT_ACTIONS[@]}"; do
  make_bundle "${entry%%|*}" "${entry##*|}" none || exit 1
done

/System/Library/CoreServices/pbs -flush 2>/dev/null
/System/Library/CoreServices/pbs -update 2>/dev/null
print -- "[install] flushed Services cache"

# Verify against the on-disk bundle (pbs -dump escapes em dashes to \U2014,
# so grepping the label there gives false negatives — check the bundle instead).
PBS_DUMP="$(/System/Library/CoreServices/pbs -dump 2>/dev/null)"
for entry in "${ACTIONS[@]}" "${NOINPUT_ACTIONS[@]}"; do
  name="${entry%%|*}"
  if [ -d "${SERVICES_DIR}/${name}.workflow" ] && print -r -- "$PBS_DUMP" | grep -q "$(printf '%s' "$name" | sed 's/—/.U2014/')"; then
    print -- "[install] ✓ registered: $name"
  elif [ -d "${SERVICES_DIR}/${name}.workflow" ]; then
    print -- "[install] ✓ installed: $name (registry refresh may lag a few s)"
  else
    print -- "[install] ⚠ failed: $name"
  fi
done

cat <<'NEXT'

Installed. Next:
  • Right-click selected text → Services → pick an action.
  • Hotkeys: System Settings ▸ Keyboard ▸ Keyboard Shortcuts ▸ Services ▸ Text.
  • "Go" auto-sends — needs Accessibility for the Service runner the first time.
    System Settings ▸ Privacy & Security ▸ Accessibility (allow when prompted).
  • Test worker: ACTION=go DRY_RUN=1 ./send-to-claude.sh 'hello'
NEXT
