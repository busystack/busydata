#!/usr/bin/env python3
"""Index source-bound parity captures without changing or normalizing images."""

import argparse
import hashlib
import html
import json
from pathlib import Path
import struct


SURFACES = {
    "welcome-retained-table": ("Welcome with a retained table", "lib/src/ui/common/workbench_view.dart",
                               "Returning from a table hides its target and representation controls without closing the table or session."),
    "welcome": ("Welcome", "lib/src/ui/common/workbench_view.dart",
                "Grouped create/open actions and saved resources; idle operational chrome is absent."),
    "sql-results-explorer": ("Workbench, Explorer and results", "lib/src/ui/common/workbench_view.dart",
                             "The shared shell surrounds a virtualized database grid and retained SQL controller."),
    "sql-text-menu": ("SQL editing menu", "lib/src/ui/common/workbench_editor_menu.dart",
                      "Cut, Copy, Paste and Select all use the existing editor operations. This capture uses the themed native-menu fallback."),
    "search-current-sql": ("Current SQL search", "lib/src/ui/common/workbench_sql_search.dart",
                           "The captured document owns navigation and revision-aware replacement; search does not execute SQL."),
    "search-actions": ("Actions search", "lib/src/ui/common/workbench_search.dart",
                       "One header query and category selector; registry entries keep eligibility, disabled reasons and effective shortcuts."),
    "search-objects": ("Database Objects search", "lib/src/ui/common/workbench_document_view.dart",
                       "Results retain the captured connection, namespace, inspection owner and metadata budgets."),
    "search-history": ("Query History search", "lib/src/ui/common/history_view.dart",
                       "The existing history catalog supplies results. Reopening SQL never runs it."),
    "settings-appearance": ("Appearance", "lib/src/ui/common/workbench_settings.dart",
                            "Language and system/light/dark preferences are immediately and durably acknowledged."),
    "settings-execution": ("Execution", "lib/src/ui/common/workbench_settings.dart",
                           "Database execution preferences retain scoped staged validation, Save and Discard."),
    "settings-recovery": ("Private recovery", "lib/src/ui/common/workbench_settings.dart",
                          "Recovery changes retain explicit review and staged persistence."),
    "settings-shortcuts": ("Keyboard shortcuts", "lib/src/ui/common/workbench_settings.dart",
                           "Grouped command rows and badges open a per-command editor; accepting that dialog saves the complete validated keymap."),
    "shortcut-editor": ("Shortcut editor", "lib/src/ui/common/workbench_settings.dart",
                        "Recording is isolated from application commands. Cancel discards the proposal."),
    "shortcut-saving": ("Shortcut · durable write pending", "lib/src/ui/common/workbench_settings.dart",
                        "The shared editor scaffold shows saving; proposal recording and cancellation are visibly disabled."),
    "shortcut-save-error": ("Shortcut · failed write", "lib/src/ui/common/workbench_settings.dart",
                            "The valid proposal stays in the dialog with an enabled Apply retry; the acknowledged mapping is preserved."),
    "connection-general": ("Connection · General", "lib/src/ui/common/connection_form.dart",
                           "Independent source drafts and pinned actions retain Test, Apply, Cancel and Save & connect semantics."),
    "connection-ssh-ssl": ("Connection · SSH/SSL", "lib/src/ui/common/connection_form.dart",
                           "The SSH configuration action has a localized name; authentication and trust review remain separate."),
    "connection-options": ("Connection · Options", "lib/src/ui/common/connection_form.dart",
                           "Environment, timeouts and connection options use the shared grouped controls."),
    "structure": ("Structure", "lib/src/ui/common/workbench_document_view.dart",
                  "Exact metadata uses selectable property values and the shared representation selector."),
    "designer": ("Object designer", "lib/src/ui/common/object_designer.dart",
                 "The grouped draft editor retains explicit DDL review and captured targets."),
    "plan": ("Execution plan", "lib/src/ui/common/plan_view.dart",
             "Shared tree rows surround captured plan evidence; disclosure keys follow UI direction."),
    "history": ("Query history", "lib/src/ui/common/history_view.dart",
                "Record rows retain privacy, pagination, inspect and reopen actions."),
    "snippets": ("Snippet editor", "lib/src/ui/common/snippet_view.dart",
                 "The existing code controller and editing menu retain insert, storage and undo behavior."),
    "transfer": ("Transfer", "lib/src/ui/common/transfer_document.dart",
                 "Grouped forms retain immutable reviewed inputs and captured source/destination."),
    "backup": ("Backup/restore", "lib/src/ui/common/transfer_document.dart",
               "Database-specific review, overwrite and cancellation remain explicit."),
    "changes-review": ("Changes review", "lib/src/ui/common/workbench_document_view.dart",
                       "Original/proposed values, approval and Apply/commit remain visible and owner-bound."),
    "comparison": ("Schema comparison", "lib/src/ui/common/workbench_document_view.dart",
                   "Current, Desired and Apply target retain separate meanings and revision guards."),
    "privileges": ("Users and privileges", "lib/src/ui/common/privileges_view.dart",
                   "Shared grouped forms preserve engine capability and review restrictions."),
    "activity": ("Activity", "lib/src/ui/common/activity_view.dart",
                 "Record/property rows retain polling ownership and termination review."),
    "capabilities": ("Capabilities", "lib/src/ui/common/capabilities_view.dart",
                     "Selectable read-only details use shared property rows; request admission occurs after the shell frame."),
    "diagram": ("ER diagram", "lib/src/ui/common/schema_tools_view.dart",
                "The surrounding toolbar and feedback are shared; the database canvas keeps pan, zoom, layout and export."),
    "jobs": ("Jobs", "lib/src/ui/common/workbench_document_view.dart",
             "Persistent job state and bounded selectable diagnostics remain visible."),
    "problems-empty": ("Problems · empty", "lib/src/ui/common/workbench_document_view.dart",
                       "The common empty-state hierarchy is used."),
    "problems-error": ("Problems · failure", "lib/src/ui/common/workbench_document_view.dart",
                       "Operational failure evidence stays persistent and selectable."),
    "recovery": ("Recovery", "lib/src/ui/common/workbench_document_view.dart",
                 "Recovery choices and unknown outcomes remain durable, reviewed states."),
}
REFERENCE = {"welcome": "welcome", "sql-results-explorer": "workspace",
             "search-actions": "search-actions", "settings-appearance": "settings-appearance",
             "settings-shortcuts": "settings-shortcuts"}
BASELINE = {"welcome": "welcome", "sql-results-explorer": "workbench",
            "search-current-sql": "find-inline", "settings-execution": "settings"}


def image_record(path, root):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not PNG: {path}")
    width, height = struct.unpack(">II", data[16:24])
    return {"path": str(path.relative_to(root)), "sha256": hashlib.sha256(data).hexdigest(),
            "review": "Unaccepted Arabic glyph fallback in the headless renderer" if '-ar-' in path.name else "Rendering evidence; not native acceptance",
            "width": width, "height": height}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("build/ui-parity/current"))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = (root / args.output).resolve()
    gallery = output / "gallery"
    identity = json.loads((output / "gallery-source-identity.json").read_text())
    records = [image_record(path, gallery) for path in sorted(gallery.rglob("*.png"))]
    manifest = {"conditions": identity["captureConditions"], "images": records,
                "sources": "../gallery-source-identity.json", "surfaces": SURFACES}
    (gallery / "images.json").write_text(json.dumps(manifest, indent=2) + "\n")
    parts = ["""<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>BusyData / BusyMark Linux comparison</title>
<style>body{font:16px/1.5 system-ui,sans-serif;background:#eee;color:#202020;margin:2rem;max-width:1800px}
h1,h2,h3{line-height:1.2}section{margin:3rem 0}figure{margin:0;min-width:0}img{display:block;width:100%;height:auto;border:1px solid #888}
figcaption{padding:.5rem 0}.pair{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,460px),1fr));gap:1.2rem}
.note{background:white;border-left:4px solid #3584e4;padding:1rem}a{color:#064a9c}code{overflow-wrap:anywhere}</style>
<h1>BusyData and BusyMark · Linux presentation</h1>
<p class="note">Production widgets, real fonts, explicit Linux platform, light/dark, 1× DPR.
Full screens use a blue accent; component sheets use the reference's default Yaru orange.
Storage, backend and native channels are fixtures. These images do not certify native GTK menus/icons,
IME, screen readers, database workflows, Windows, Wayland or fractional compositor scale.
Click an image for its original size. Database viewports and operational evidence retain their functional geometry.</p>"""]
    def link(path, text):
        return f'<a href="{html.escape(path)}">{html.escape(text)}</a>'
    def figure(path, caption):
        relative = html.escape(str(path.relative_to(gallery)))
        label = html.escape(caption)
        return (f'<figure><a href="{relative}"><img loading="lazy" src="{relative}" '
                f'alt="{label}"></a><figcaption>{label}</figcaption></figure>')
    parts.append('<p>' + ' · '.join([
        link('../gallery-source-identity.json', 'Exact current sources, dependency locks and fonts'),
        link('../baseline-source-identity.json', 'Before source baseline'),
        link('images.json', 'Image hashes and surface callers'),
        link('../verification-summary.json', 'Executed verification record'),
    ]) + '</p>')
    parts.append('<p>BusyData current canonical source <code>' + html.escape(identity['busydata']['buildSourceSha256']) + '</code>; BusyMark current <code>' + html.escape(identity['busymark']['head']) + '</code>. Historical source identities are recorded separately. The reference checkout was read only; its captures use an isolated copy.</p>')
    for mode in ('light', 'dark'):
        parts.append(f'<section><h2>{mode.title()} · full application surfaces</h2>')
        for name, (title, source, caption) in SURFACES.items():
            current = gallery / 'screens' / mode / f'{name}.png'
            if not current.exists():
                raise ValueError(f'Missing surface capture: {current}')
            parts.append(f'<h3>{html.escape(title)}</h3><p>{html.escape(caption)}<br><code>{html.escape(source)}</code></p><div class="pair">')
            if name in REFERENCE:
                reference = gallery / 'reference-screens' / mode / (REFERENCE[name] + '.png')
                if not reference.exists(): raise ValueError(f'Missing reference: {reference}')
                parts.append(figure(reference, 'BusyMark · current reference'))
            if name in BASELINE:
                before = gallery / 'baseline-screens' / mode / (BASELINE[name] + '.png')
                if not before.exists(): raise ValueError(f'Missing before capture: {before}')
                parts.append(figure(before, 'BusyData · archived before source'))
            parts.append(figure(current, 'BusyData · current implementation'))
            parts.append('</div>')
        for scale in (150, 200):
            for kind in ('welcome', 'search'):
                name = f'compact-{kind}-{scale}'
                parts.append(f'<h3>Compact {kind} · {scale}% text · 760 × 720</h3><div class="pair">')
                for project, label in [('reference-screens', 'BusyMark'), ('screens', 'BusyData')]:
                    path = gallery / project / mode / f'{name}.png'
                    if not path.exists(): raise ValueError(f'Missing compact capture: {path}')
                    parts.append(figure(path, label))
                parts.append('</div>')
        for name, title in [
            ('welcome-de-150', 'German Welcome · 150% text'),
            ('settings-de-150', 'German Appearance · 150% text'),
            ('welcome-ar-150', 'Arabic Welcome · RTL · 150% text'),
            ('settings-ar-150', 'Arabic Appearance · RTL · 150% text'),
            ('welcome-ar-high-contrast-150', 'Arabic Welcome · high contrast · reduced motion · 150% text'),
        ]:
            parts.append(f'<h3>{title}</h3><div class="pair">')
            if '-ar-' in name:
                parts.append('<p class="note">Arabic glyph fallback is missing in both headless renders. These images exercise direction/allocation and do not accept Arabic typography. The real fonts are loaded; neither app is restyled to hide the missing fallback.</p>')
            for project, label in [('reference-screens', 'BusyMark'), ('screens', 'BusyData')]:
                path = gallery / project / mode / f'{name}.png'
                if not path.exists(): raise ValueError(f'Missing locale/contrast capture: {path}')
                parts.append(figure(path, label))
            parts.append('</div>')
        parts.append('</section>')
    parts.append('<section><h2>Shared components and interaction states</h2><p>These use actual source components. Labels, application identity and illustrative content differ. Native menus use the same explicit fallback fixture.</p>')
    reference_components = sorted((gallery / 'busymark').glob('*.png'))
    for reference in reference_components:
        current = gallery / 'busydata' / reference.name
        if not current.exists(): raise ValueError(f'Missing component: {current}')
        parts.append(f'<h3>{html.escape(reference.stem)}</h3><div class="pair">' + figure(reference, 'BusyMark') + figure(current, 'BusyData') + '</div>')
    parts.append('</section></html>')
    workflows = gallery / 'workflows'
    if workflows.exists():
        parts.pop()
        parts.append('</section><section><h2>Eight screenshot workflows · workbench correction</h2><p class="note">Before images are the supplied ordinary Linux screenshots. After images assemble the current production widgets with realistic JDBC metadata and captured result fixtures. They are rendering evidence; native execution, accessibility and performance must be accepted separately. Original image bytes are preserved.</p>')
        cases = [
            ('01-empty-query-short', '13-35-33', 'Empty query and document names'),
            ('02-customers-structure-tall', '13-36-34', 'Five-column customers Structure'),
            ('03-customers-data-four-tall', '13-36-58', 'Customers · four rows'),
            ('04-orders-data-six-tall', '13-37-09', 'Order items · six rows'),
            ('05-column-structure-tall', '13-37-31', 'Direct column inspection'),
            ('06-view-results-tall', '13-37-56', 'View results'),
            ('07-queries-duplicate-objects-tall', '13-38-32', 'Queries and duplicate object names'),
            ('08-connection-general-tall', '13-39-02', 'Connection manager · filled General'),
        ]
        for name, before, title in cases:
            parts.append(f'<h3>{html.escape(title)}</h3><div class="pair">')
            parts.append(figure(gallery / 'user-before' / f'{before}.png', 'Before · supplied native dark appearance'))
            for mode in ('dark', 'light'):
                parts.append(figure(workflows / mode / f'{name}.png', f'After · {mode} production composition'))
            parts.append('</div>')
        parts.append('<h2>Other sections, sizes, text scales and locales</h2>')
        shown = {case[0] for case in cases}
        for path in sorted(workflows.rglob('*.png')):
            if path.stem in shown:
                continue
            parts.append(figure(path, 'Current production composition · ' + str(path.relative_to(workflows))))
        parts.append('</section></html>')
    (gallery / 'index.html').write_text('\n'.join(parts) + '\n')
    print(gallery / 'index.html')


if __name__ == '__main__':
    main()
