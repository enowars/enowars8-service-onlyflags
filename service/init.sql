CREATE DATABASE pod;
CREATE DATABASE premium_forum;
CREATE USER 'web'@'10.6.0.3';
CREATE USER 'proxy'@'10.6.0.4';
CREATE USER 'premium_forum'@'10.5.0.3';

GRANT INSERT,SELECT ON pod.* TO "web"@"10.6.0.3";
GRANT SELECT ON pod.* TO "proxy"@"10.6.0.4";

GRANT INSERT,SELECT ON premium_forum.* TO "premium_forum"@"10.5.0.3";

use pod;
CREATE TABLE user(
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  plan ENUM('premium', 'regular') NOT NULL,
  created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
GRANT UPDATE(plan) on user TO "web"@"10.6.0.3";
CREATE EVENT cleanup_user ON SCHEDULE EVERY 5 SECOND DO DELETE FROM user WHERE TIMESTAMPDIFF(SECOND, created, CURRENT_TIME) > 600;

use premium_forum;
CREATE TABLE post(
  thread TEXT NOT NULL,
  content TEXT NOT NULL,
  created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX post_thread_IDX ON post(thread);
CREATE EVENT cleanup_post ON SCHEDULE EVERY 5 SECOND DO DELETE FROM post WHERE TIMESTAMPDIFF(SECOND, created, CURRENT_TIME) > 600;
