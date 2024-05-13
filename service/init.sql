CREATE DATABASE pod;
CREATE USER 'web';
CREATE USER 'proxy';

GRANT INSERT,SELECT ON pod.* TO "web";
GRANT SELECT ON pod.* TO "proxy";

use pod;
CREATE TABLE user(
  username VARCHAR(20) NOT NULL UNIQUE,
  password VARCHAR(20) NOT NULL,
  plan ENUM('premium', 'regular') NOT NULL,
  created DATETIME NOT NULL
);
