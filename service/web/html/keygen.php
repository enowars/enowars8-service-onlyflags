<?php

require '../vendor/autoload.php';

use Firebase\JWT\JWT;

$key = file_get_contents('../keypair.pem');

echo JWT::encode(["sub" => "ASDFASDF"], $key, 'RS256');

