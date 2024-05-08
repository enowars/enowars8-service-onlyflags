CREATE DATABASE pod;
CREATE USER "web"@"web";

GRANT INSERT,SELECT ON pod.* TO "web"@"web";

