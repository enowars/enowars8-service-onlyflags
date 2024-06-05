<?php
require '../vendor/autoload.php';

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Firebase\JWT\SignatureInvalidException;

if ($_SERVER['REQUEST_METHOD'] === "POST") {
  if (array_key_exists('key', $_POST)) {
  
    $publicKey = file_get_contents('../jwt_pub.crt');
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

$title = "OnlyFlags license activation";
require '../header.php';
?>
<div class="form-box">
	<h5>Activate License</h5>
	<form action="/license.php" method="POST">
		<div class="form-element">
			<label for="key">Key:</label><br>
			<input id="key" name="key"><br>
		</div>
		<div class="form-element">
			<input type="submit" value="Submit">
		</div>
	</form>
	<?php if (array_key_exists('success', $_GET)) { ?>
	<div class="form-message success">license activated!</div>
	<?php } elseif (array_key_exists('error', $_GET)) { ?>
	<div class="form-message error">license activation failed!</div>
	<?php } ?>
</div>
<div>
	<h1>Premium License</h1>
	<p>If you want to access our premium features then contact our sales (trust and safety) department in order to for us to check your identity and street cred and discuss.</p>
</div>
<?php require '../footer.php';
