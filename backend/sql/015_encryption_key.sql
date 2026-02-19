-- Encryption key for encrypted Google Drive backups (AES-256-GCM)
-- Stored base64-encoded; generated client-side on first backup setup.

alter table dv_user_settings add column if not exists encryption_key text;
