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
$title = "OnlyFlags registration";
require '../header.php';
?>
<div class="form-box">
	<h5>Sign Up</h5>
	<form action="/" method="POST">
		<div class="form-element">
			<label for="username">Username:</label><br>
			<input id="username" name="username" pattern="[a-zA-Z0-9-+=\/]{1,45}" title="only english letters, numbers and -+=\/ allowed">
		</div>
		<div class="form-element">
			<label for="password">Password:</label><br>
			<input id="password" name="password" pattern="[a-zA-Z0-9-+=\/]{1,45}" title="only english letters, numbers and -+=\/ allowed">
		</div>
		<div class="form-element">
			<input type="submit" value="Register">
		</div>
	</form>
	<?php if (array_key_exists('success', $_GET)) { ?>
	<div class="form-message success">signup successful!</div>
	<?php } elseif (array_key_exists('error', $_GET)) { ?>
	<div class="form-message error">failed to sign up!</div>
	<?php } ?>
	<div class="ad">
		<img src="/assets/ad1.png" alt="Free sample with the shirt ;)">
		<p>Free sampe with the shirt ;)</p>
	</div>
</div>
<div>
	<h1>ONLYFLAGS</h1>
	<p>Welcome to our private network of flag sharing enthusiasts. We boast one of the most active network of forums for the most dirty of flag sharing needs.</p>
	<p>We have a highly fault-tolerant network proxy, from which all users connect to, to access our services.</p>
	<p>After signing up, you are able to connect to our network with the following:</p>

	<div class="command-box">
		<div class="code">ncat --proxy $TARGET_IP --proxy-type socks5 --proxy-dns remote --proxy-auth $USER:$PW $SERVICE $SERVICE_PORT</div>
		<ul>
			<li><var>TARGET_IP</var>: our network's address</li>
			<li><var>USER</var>,<var>PW</var>: your credentials</li>
			<li><var>SERVICE_PORT</var>: all our services are on port 1337</li>
			<li><var>SERVICE</var>: our services reachable in the network
				<ul>
					<li><var>echo</var>: test service to test the connection</li>
					<li><var>open-forum</var>: general open forum accesible for everyone. (please note: flag sharing is not allowed)</li>
					<li><var>premium-forum</var>: (PREMIUM) our exclusive, anonymous forum</li>
				</ul>
			</li>
		</ul>
	</div>
</div>
<?php require '../footer.php';
