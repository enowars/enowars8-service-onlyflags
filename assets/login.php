<?php

// TODO: implement LOGIN

$title = "OnlyFlags login";
require '../header.php';
?>
<div class="form-box">
	<h5>Login</h5>
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
					<li><var>premium_forum</var>: (PREMIUM) our exclusive, anonymous forum</li>
				</ul>
			</li>
		</ul>
	</div>
</div>
<?php require '../footer.php';
