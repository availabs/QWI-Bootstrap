CREATE USER qwi_api;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE ON TABLES TO qwi_api;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO qwi_api;
