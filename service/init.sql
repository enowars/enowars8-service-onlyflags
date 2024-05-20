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
  username VARCHAR(20) NOT NULL UNIQUE,
  password VARCHAR(20) NOT NULL,
  plan ENUM('premium', 'regular') NOT NULL,
  created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
GRANT UPDATE(plan) on user TO "web";

use premium_forum;
CREATE TABLE post(
  thread VARCHAR(20) NOT NULL,
  content VARCHAR(50) NOT NULL,
  created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX post_thread_IDX ON post(thread);

