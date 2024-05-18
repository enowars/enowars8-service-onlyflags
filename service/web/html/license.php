<?php
require '../vendor/autoload.php';

use Firebase\JWT\JWT;
use Firebase\JWT\Key;

if ($_SERVER['REQUEST_METHOD'] === "POST") {
  if (array_key_exists('key', $_POST)) {
  
    $publicKey = file_get_contents('../publickey.crt');
    try {
      $jwt = JWT::decode($_POST['key'], new Key($publicKey, 'RS256'));
      $con = require '../db.php';
      $query = $con->prepare("UPDATE user SET plan = 'premium' WHERE username = ?");
      $query->bindParam(1, $jwt->sub);
      $query->execute();

      header('Location: /license.php?success');
      exit();
    } catch(DomainException|UnexpectedValueException|SignatureInvalidException) {
    }
  }
  header('Location: /license.php?error');
  exit();
}

?>
<html lang="de">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OnlyFlags registration</title>
  </head>
  <body>
	<form action="/license.php" method="POST">
	<label for="key">Key:</label><input id="key" name="key"><br>
	<input type="submit" value="Register">
	</form>
<?php if (array_key_exists('success', $_GET)) { ?>
	SUCCESS
<?php } elseif (array_key_exists('error', $_GET)) { ?>
	ERROR
<?php } ?>
  </body>
</html>


