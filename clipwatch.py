#!/usr/bin/env python3
# clipwatch.py — clipboard watcher for the right-click→Claude tool.
#
# Two jobs on every clipboard change:
#   1. Freshness/security meta → ~/.claude/state/clipboard.json
#      {epoch, bundle, blocked}. The worker uses the clipboard as a fallback only
#      if FRESH (<TTL) and not blocked.
#   2. History → ~/.claude/state/cliphistory/ (index.json + item files), capped,
#      for the ClipHistory picker. Text and images. Secrets are never stored.
#
# Runs as a LaunchAgent (install-clipwatch.sh). Stores contents on disk for
# history — but never from a blocked/secret source.

import os, json, time, stat
from AppKit import (NSPasteboard, NSWorkspace, NSBitmapImageRep,
                    NSBitmapImageFileTypePNG)

# Clipboard history is plaintext on disk and can contain anything you copy
# (tokens, 2FA codes, private messages). Keep it strictly owner-only so other
# local users on a shared Mac can't read it. umask 0o077 → new files 0600,
# new dirs 0700.
os.umask(0o077)

STATE_DIR = os.path.expanduser("~/.claude/state")
META   = os.path.join(STATE_DIR, "clipboard.json")
HIST   = os.path.join(STATE_DIR, "cliphistory")
INDEX  = os.path.join(HIST, "index.json")
CONFIG = os.path.join(STATE_DIR, "command-config.json")
os.makedirs(HIST, mode=0o700, exist_ok=True)

def _lock_down():
    # Tighten perms on the dir + any pre-existing files from older versions
    # that may have been created world-readable under a 0022 umask.
    try: os.chmod(HIST, 0o700)
    except OSError: pass
    try:
        for name in os.listdir(HIST):
            try: os.chmod(os.path.join(HIST, name), 0o600)
            except OSError: pass
    except OSError: pass

_lock_down()

# Retention is time-based (set in the menu-bar UI → command-config.json). The
# count cap is just a disk-safety backstop, not the real limit.
DEFAULT_RETENTION_DAYS = 7
MAX_ITEMS = 1000
PREVIEW_LEN = 90

def retention_days():
    env = os.environ.get("CLIP_RETENTION_DAYS")
    if env:
        try: return max(1, int(env))
        except ValueError: pass
    try:
        with open(CONFIG) as f:
            v = json.load(f).get("retentionDays")
            if isinstance(v, (int, float)) and v >= 1: return int(v)
    except Exception:
        pass
    return DEFAULT_RETENTION_DAYS

BLOCK_BUNDLES = {
    "com.apple.keychainaccess", "com.apple.SecurityAgent",
    "com.1password.1password", "com.agilebits.onepassword7",
    "com.apple.wallet", "com.apple.Passwords",
}
CONCEAL_TYPES = {
    "org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
    "com.agilebits.onepassword.metadata",
}

def front_bundle():
    a = NSWorkspace.sharedWorkspace().frontmostApplication()
    return (a.bundleIdentifier() or "") if a else ""

def write_meta(epoch, bundle, blocked):
    tmp = META + ".tmp"
    with open(tmp, "w") as f:
        json.dump({"epoch": epoch, "bundle": bundle, "blocked": bool(blocked)}, f)
    os.replace(tmp, META)

def load_index():
    try:
        with open(INDEX) as f: return json.load(f)
    except Exception:
        return []

def save_index(items):
    tmp = INDEX + ".tmp"
    with open(tmp, "w") as f: json.dump(items, f)
    os.replace(tmp, INDEX)

def prune(items):
    # Drop anything older than the retention window (items are newest-first).
    cutoff = int(time.time()) - retention_days() * 86400
    kept = []
    for it in items:
        if it.get("ts", cutoff) < cutoff:
            try: os.remove(os.path.join(HIST, it["file"]))
            except Exception: pass
        else:
            kept.append(it)
    # Disk-safety backstop on count.
    while len(kept) > MAX_ITEMS:
        old = kept.pop()
        try: os.remove(os.path.join(HIST, old["file"]))
        except Exception: pass
    return kept

def prune_now():
    items = load_index()
    pruned = prune(items)
    if len(pruned) != len(items):
        save_index(pruned)

def save_image(pb, path):
    d = pb.dataForType_("public.png")
    if d:
        d.writeToFile_atomically_(path, True); return True
    d = pb.dataForType_("public.tiff")
    if d:
        rep = NSBitmapImageRep.imageRepWithData_(d)
        if rep:
            png = rep.representationUsingType_properties_(NSBitmapImageFileTypePNG, {})
            if png: png.writeToFile_atomically_(path, True); return True
    return False

def add_history(epoch, pb):
    items = load_index()
    types = set(pb.types() or [])
    text = pb.stringForType_("public.utf8-plain-text") or pb.stringForType_("public.text")
    is_img = bool(types & {"public.png", "public.tiff"})
    if text and text.strip():
        if items and items[0].get("type") == "text" and items[0].get("full") == text:
            return  # dedup consecutive
        fid = f"{epoch}.txt"
        with open(os.path.join(HIST, fid), "w") as f: f.write(text)
        items.insert(0, {"id": str(epoch), "type": "text", "file": fid,
                         "preview": text.strip().replace("\n", " ")[:PREVIEW_LEN],
                         "full": text, "ts": epoch})
    elif is_img:
        fid = f"{epoch}.png"
        if save_image(pb, os.path.join(HIST, fid)):
            items.insert(0, {"id": str(epoch), "type": "image", "file": fid,
                             "preview": "🖼 image", "ts": epoch})
        else:
            return
    else:
        return
    save_index(prune(items))

def main():
    pb = NSPasteboard.generalPasteboard()
    last = pb.changeCount()
    write_meta(int(time.time()), front_bundle(), False)
    last_prune = 0
    while True:
        now = int(time.time())
        cc = pb.changeCount()
        if cc != last:
            last = cc
            bundle = front_bundle()
            types = set(pb.types() or [])
            concealed = bool(types & CONCEAL_TYPES)
            blocked = concealed or (bundle in BLOCK_BUNDLES)
            write_meta(now, bundle, blocked)
            if not blocked:
                try: add_history(now, pb)
                except Exception: pass
        # Periodic prune so expired clips disappear without needing a new copy.
        if now - last_prune >= 60:
            last_prune = now
            try: prune_now()
            except Exception: pass
        time.sleep(1)

if __name__ == "__main__":
    main()
