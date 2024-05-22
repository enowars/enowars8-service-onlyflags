<?php

if ($_SERVER['REQUEST_METHOD'] === "POST") {
  if (array_key_exists('username', $_POST)
      && array_key_exists('password', $_POST)
      && preg_match('/^[a-zA-Z0-9-+=\/]{1,45}$/', $_POST['username'])
      && preg_match('/^[a-zA-Z0-9-+=\/]{1,45}$/', $_POST['password']))
    try {
      $con = require '../db.php';
      $query = $con->prepare("INSERT INTO user(username, password, plan) VALUES (?,?,'regular')");
      $query->bindParam(1, $_POST['username']);
      $query->bindParam(2, $_POST['password']);
      $query->execute();
      header('Location: /?success');
      exit();
    } catch (PDOException) {
    }
  header('Location: /?error');
  exit();
}
?>
<!DOCTYPE html>
<html lang="de">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OnlyFlags registration</title>
  </head>
  <body>
	<form action="/" method="POST">
	<label for="username">Username:</label><input id="username" name="username"><br>
	<label for="username">Password:</label><input name="password"><br>
	<input type="submit" value="Register">
	</form>
<?php if (array_key_exists('success', $_GET)) { ?>
	SUCCESS
<?php } elseif (array_key_exists('error', $_GET)) { ?>
	ERROR
<?php } ?>
  </body>
</html>

