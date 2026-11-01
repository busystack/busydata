# BusyMark reference mapping and command-route inventory

This inventory accompanies `ui_workbench_spec.md`. All IDs remain registered in
`WorkbenchActions`; Linux places application actions at the root of one native application menu.
Documents contains file/workspace actions; SQL execution groups editing and run
actions; Database groups connections and objects. View contains global tools. Settings does not expose the hidden workbench menu. Explorer, document target, grid and caret menus retain
their scoped routes. Registry visibility, eligibility and captured targets apply
at presentation and invocation. Session/diagnostic families expand from existing
backend enums; no workflow is recreated in Linux presentation.

| Former category | Current Linux destination | Preserved command IDs |
| --- | --- | --- |
| File | Application menu → Documents; Settings at the application root | `file.new`, `file.open`, `file.save`, `file.close`, `workspace.open`, `workspace.save`, `preferences` |
| Edit | Application menu → SQL execution → Edit; editor context and search | `editor.find`, `editor.replace`, `editor.format`, `editor.comment`, `editor.snippets` |
| View | Application menu → View; applicable contextual controls | `view.palette`, `view.explorer`, `view.history`, `view.results`, `view.jobs`, `view.problems`, `view.sessions`, `backend.restart`, `view.recovery`, `result.plan` |
| Connection | Application menu → Database → Connection; applicable contextual controls | `connection.consoles`, `connection.new`, `connection.new-query`, `connection.edit`, `connection.favorite`, `folder.new`, `folder.rename`, `source.move`, `source.up`, `source.down`, `folder.remove`, `connection.connect`, `connection.deactivate`, `connection.disconnect`, `connection.share`, `connection.search`, `connection.details`, `connection.capabilities`, `connection.activity`, `connection.principals`, `connection.duplicate`, `connection.delete`, `session.${entry.key.value}`, `backup.dump`, `backup.restore`, `diagnostics.${kind.value}` |
| Object | Application menu → Database → Object; applicable contextual controls | `virtual.new`, `virtual.edit`, `virtual.rename`, `virtual.open`, `virtual.run`, `virtual.remove`, `virtual.rebind`, `schema.snapshot`, `schema.compare`, `object.compare`, `schema.designer`, `schema.diagram`, `object.structure`, `object.reveal`, `object.documentation`, `object.ddl`, `object.data`, `object.refresh`, `object.sql`, `object.copy`, `transfer.import` |
| Run options | Application menu → SQL execution → Run options; applicable contextual controls | `job.cancel`, `sql.options`, `sql.run`, `sql.selection`, `sql.script`, `sql.explain`, `sql.analyze`, `transfer.sql` |

Additional presentation routes are `view.start` / `view.workbench` (retained
navigation) and `history.search` (the shared History category). Existing
`editor.find`, `editor.replace`, `connection.search` and `view.palette` route to
the corresponding category of the single header/sidebar search session. History
management retains `view.history`. No persisted ID is renamed or aliased.

Commands in Results/Changes stay in their document/grid context and Actions
search. The shared search shortcut and command ID remain `view.palette` for
persistence; there is one active header/sidebar presentation. Shortcut assignment
keys and stored settings formats remain unchanged.

Prepare a read-only current-source identity snapshot with:

```sh
python3 tool/capture_reference_gallery.py --reference /path/to/busymark --prepare-only
```

The tool copies current reference source and legitimate first-party sibling
packages into ignored build output, retains its lockfile and extracted tab
presentation, and records actual resolved fonts, source identity and capture
conditions. It never writes the reference checkout and the product has no
dependency on its location. Standalone comparative rendering is unavailable until
the reference has independent hosted and native source verification, as described
in [development.md](development.md). A prepared snapshot does not certify a build
or rendered comparison. Recorded widget captures remain supplemental to native
menu, compositor, IME and screen-reader acceptance.

The optional screen pass instantiates the ordinary BusyMarkApp and
LinuxBusyDataApp with test storage/backend and native channel fixtures. It includes
complete Welcome/workbench/search/Settings captures alongside database-specific
views. Native facilities and compositor behavior still require the actual desktop
acceptance paths. The source manifests and font hashes accompany the gallery.

The `9c3acfa` follow-up rechecks BusyMark's modal saving/cancellation, effective
shortcut hints, text-location menu anchor and supported-locale normalization.
BusyData adapts those interactions to its existing editor and durable writer.
History handoff/pagination and search button routing retain BusyData ownership.
`tool/package_ui_comparison.py` validates all linked image files and image hashes,
then creates a complete ZIP plus a standalone HTML with embedded images/manifests.
Always hand off that bundle, not a loose index with missing relative files.

The `476ce5e` review correction retains the History query/backend page identity
while refreshing shared search on every opening. Linux action rows reuse the
selector combined-name policy for native accessibility. Component-menu capture
fixtures connect the reference trigger FocusNode and assert visible entries in
both themes before saving; BusyMark production widgets remain read-only.
