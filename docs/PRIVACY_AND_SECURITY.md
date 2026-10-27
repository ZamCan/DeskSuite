# Privacy and security

Current behavior:
- Projects, notes and product records are saved to the application's local support directory.
- Image transformations and design editing run locally.
- No account or remote API is required.
- Export and printing use operating-system facilities.
- Local files are not encrypted by DeskSuite.

Back up important projects and device data. Uninstalling the app or clearing its storage may remove local records. Current product records are a starter implementation, not a transactional accounting database.

Before production: implement and test backup/restore; add migrations and transactional storage; validate imported files; document permissions; add dependency notices; keep signing keys out of Git; and review security before optional networking.
