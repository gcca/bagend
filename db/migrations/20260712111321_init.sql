-- migrate:up

CREATE TABLE auth_user (
  username TEXT NOT NULL PRIMARY KEY,
  password TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  last_logged_at INTEGER DEFAULT (unixepoch())
);

CREATE TABLE auth_session (
  token TEXT NOT NULL PRIMARY KEY,
  username TEXT NOT NULL REFERENCES auth_user(username) ON DELETE CASCADE,
  created_at INTEGER DEFAULT (unixepoch()),
  expires_at INTEGER NOT NULL
);

CREATE INDEX idx_auth_session_username ON auth_session(username);
CREATE INDEX idx_auth_session_expires_at ON auth_session(expires_at);

CREATE TRIGGER update_last_logged_at
AFTER UPDATE ON auth_session
FOR EACH ROW
WHEN NEW.username IS NOT NULL
BEGIN
    UPDATE auth_user SET last_logged_at = unixepoch() WHERE username = NEW.username;
END;

CREATE TABLE home_app (
  name TEXT NOT NULL PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT NOT NULL
);

CREATE TABLE home_userapp (
  username TEXT NOT NULL REFERENCES auth_user(username) ON DELETE CASCADE,
  appname TEXT NOT NULL REFERENCES home_app(name) ON DELETE CASCADE
);

CREATE INDEX idx_home_userapp_username ON home_userapp(username);
CREATE INDEX idx_home_userapp_appname ON home_userapp(appname);

-- migrate:down

DROP TABLE home_app;
DROP TABLE home_userapp;
DROP INDEX idx_auth_session_expires_at;
DROP INDEX idx_auth_session_username;
DROP TRIGGER update_last_logged_at;
DROP TABLE auth_session;
DROP TABLE auth_user;
