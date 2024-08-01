# OnlyFlags

OnlyFlags is a microservice network, where two text-tcp-based forums are behind a SOCKS5 proxy.

## Service topology
![service topology](../assets/topology.svg)

All data is stored in the database. The forums and echo server are in a isolatied network.

### Generate keys for licensing
This should be done before an ctf event, as only the checker should have access to the private key.

```sh
openssl genrsa -out jwt_priv.pem 2048
openssl rsa -in jwt_priv.pem -pubout -out jwt_pub.crt
mv jwt_priv.pem checker/
mv jwt_pub.pem service/web/
```

## Basic Usage

after creating an account the user can access the internal_net with
```sh
ncat --proxy $TARGET_IP --proxy-type socks5 --proxy-dns remote --proxy-auth $USER:$PW $SERVICE $SERVICE_PORT
```

To test the access the user can use the `echo` service with the port `1337`.


## Vulnearbilities

both exploits are shown in the `only_exp_*.py` files.

### 1st vuln in the proxy service

An error in population of the `Proxy.UserCache` in the proxy server makes it possible to access the restricted service for a short period of time after the user registers.

To fix it, a defender can just skip the upserting into the cache and construct the access map from scratch.

### 2nd vuln in the (open-)forum service (Shamir's secret censoring)

The checker is depositing the flags 3 times like a spambot and the service encrypts them in order to "censor" them.

The flag is computed with a polynomial so that `f(0) = flag` and `f(post_id) = shown_value`.

In the provided implementation that polynomial is of degree 2, meaning an attacker can read the encrypted values and post ids and with Shamir's secret sharing can be decrypted.

To fix it, a defender can just add more coefficient to the polynomial.
