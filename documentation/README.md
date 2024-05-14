# OnlyFlags

## Basic Usage

after creating an account the user can access the internal_net with
```sh
ncat --proxy $TARGET_IP --proxy-type socks5 --proxy-auth $USER:$PW $SERVICE $SERVICE_PORT
```

To test the access the user can use the `echo` service with the port `1337`.


## Vulnearbilities

### 1st vuln in the proxy service

An error in population of the `Proxy.UserCache` in the proxy server makes it possible to access the restricted service for a short period of time after the user registers.


