# DeskSuite architecture

Flutter and Dart provide a shared foundation. This first increment is a coherent vertical slice, not a set of empty modules.

- Application shell: responsive navigation, theme and home workspace.
- Creative Studio: versioned project model, editable text/shape/image elements, dragging, duplicate/delete, undo/redo, local save/reopen and PDF export.
- Photo Studio: local image decoding and transformations.
- Office Notes: local text persistence and TXT export.
- Print Studio: PDF generation and system print dialog.
- Business starter: local product catalogue, opening stock and stock decrement.
- Local storage: application-support files, project files and explicit export.

Projects use a versioned JSON structure with project ID, name, canvas dimensions, update timestamp and ordered elements. Notes and products are local files. Production business features need database migrations and transactional persistence.

Flutter shares code across Android, iOS, Windows and Linux. Platform folders can be generated with flutter create. Build on each supported operating system. iOS signing and App Store packaging require Apple's tooling and credentials.

Engineering rules: keep editable data separate from rendering; keep core operations local; test critical logic; preserve source images; distinguish import/view/edit support; and document platform limitations.
