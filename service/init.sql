CREATE DATABASE pod;
CREATE DATABASE premium_forum;
CREATE USER 'web';
CREATE USER 'proxy';
CREATE USER 'premium_forum';

GRANT INSERT,SELECT ON pod.* TO "web";
GRANT SELECT ON pod.* TO "proxy";

GRANT INSERT,SELECT ON premium_forum.* TO "premium_forum";

use pod;
CREATE TABLE user(
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  plan ENUM('premium', 'regular') NOT NULL,
  created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
GRANT UPDATE(plan) on user TO "web";

use premium_forum;
CREATE TABLE post(
  thread TEXT NOT NULL,
  content TEXT NOT NULL,
  created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX post_thread_IDX ON post(thread);

