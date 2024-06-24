CREATE DATABASE pod;
CREATE DATABASE premium_forum;
CREATE USER 'web'@'10.6.0.3';
CREATE USER 'proxy'@'10.6.0.4';
CREATE USER 'premium_forum'@'10.5.0.3';
CREATE USER 'open_forum';

GRANT INSERT,SELECT ON pod.* TO "web"@"10.6.0.3";
GRANT SELECT ON pod.* TO "proxy"@"10.6.0.4";

GRANT INSERT,SELECT ON premium_forum.* TO "premium_forum"@"10.5.0.3";

use pod;

CREATE TABLE config(
	network_id VARCHAR(50) NOT NULL
);
INSERT INTO config(network_id) VALUES (LOWER(HEX(RANDOM_BYTES(25))));
GRANT SELECT on config TO "web"@"10.6.0.3";

CREATE TABLE user(
  username VARCHAR(50) NOT NULL UNIQUE,
  password VARCHAR(50) NOT NULL,
  plan ENUM('premium', 'regular') NOT NULL,
  censor_data TEXT NULL,
  created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE post(
  id INT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(50) NOT NULL,
  thread TEXT NOT NULL,
  content TEXT NOT NULL,
  created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
GRANT UPDATE(plan) on user TO "web"@"10.6.0.3";
GRANT INSERT,UPDATE,SELECT on post TO "open_forum";
GRANT SELECT,UPDATE(censor_data) on user TO "open_forum";
CREATE EVENT cleanup_user ON SCHEDULE EVERY 5 SECOND DO DELETE FROM user WHERE TIMESTAMPDIFF(SECOND, created, CURRENT_TIME) > 600;

use premium_forum;
CREATE TABLE post(
  id INT PRIMARY KEY AUTO_INCREMENT,
  username VARCHAR(50) NOT NULL,
  thread TEXT NOT NULL,
  content TEXT NOT NULL,
  censor_data TEXT NULL,
  created DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX post_thread_IDX ON post(thread);
CREATE EVENT cleanup_post ON SCHEDULE EVERY 5 SECOND DO DELETE FROM post WHERE TIMESTAMPDIFF(SECOND, created, CURRENT_TIME) > 600;
