Docker Proxy (Carina)
=======

This container allows a Docker client (the very native one) to connect to a remote Docker engine with a restrictive HTTP proxy between them. This is a common situation for Carina corporate to-be customers.

This image is based on `vertigo/lets-nginx` (wich is itself based on previous work from `smashwilson/lets-nginx`). This means it will automagically generate its SSL certificate using letsencrypt.

## What it does

* Generate SSL certificates for HTTPS
* Preserve the security (DOCKER_TLS_VERIFY)
* Work through "man-in-the-middle" proxies

## What it does not

* Make Carina free forever
* Stop people from voting on Trump

## Docker the normal way

Normally a docker engine protected by TLS can be exposed to the Internet (port 2376), because clients need a client certificate. This is well documented in [Protect the Docker daemon socket](https://docs.docker.com/engine/security/https/).

Carina already exposes TLS-protected engines, and Carina CLI makes it a lot easier to configure your shell prompt to connect with your remote Carina cluster. You can read a [quick intro to Carina here](https://github.com/vertigobr/lets-nginx/blob/master/CARINA.md).

## We hate them damn proxies

A corporate HTTP proxy, this damn thing born in the deep pits or burning Hell, makes it impossible to use Carina because:

* It blocks access to any external tcp port (except 80 and 443)
* It blocks any traffic with non-standard certificates (so it will refuse your cheap self-signed certificate and Carina cluster auto-generated CAs)
* It sniffs through all traffic and acts as a man-in-the-middle hacker, swapping certificates for their own

## What we are about to do

We will use a specific container to:

* Launch a self-service HTTPS nginx reverse proxy that auto generates its certificates with letsencrypt (using a domain hostname you provide)
* Configure this proxy to behave just like the normal Docker TLS-enabled endpoint with the least possible effort

## Read the docs

It won't hurt to read the docs from the base image [vertigo/lets-nginx](https://github.com/vertigobr/lets-nginx). I strongly recommend you to follow the steps in there in order to successfully use `vertigo/lets-nginx` to serve a backend service.

*If you manage to do so you will be able to keep the certificates generated and cached inside the volumes and skip sections "Create volumes" and "First run" below.*

We will use the server certificate generation and the client certificate authentication described in there.

## How to use

There are a few steps that you must take *while you are at home, at Starbucks, anywhere but at work*. You will need to setup your proxy where there is sanity.

The whole **While NOT at work** section assumes you are running docker commands that connect freely with your remote engine. This could be your Carina cluster, your Digital Ocean VM, it doesn't matter: you are setting up an HTTPS endpoint that, later on, your work proxy will not complain about.

## While NOT at work

You will do the steps:

* Create volumes
* First run
* Stop it now
* Running with client-certificate CA

### Create volumes

First create a set of volumes to cache letsencrypt, as in `volumes.sh`. **This is important**, because letsencrypt will refuse to generate them again after a few times.

```
docker volume create --name letsencrypt
docker volume create --name letsencrypt-backups
docker volume create --name dhparam-cache
```

Remember, there is no such thing as "mount host folder" on Carina. This is CaaS, and this is good.

### First run (won't work, must do)

The first run will generate the certificates and will allow some testing. Just run the command below (as in `runproxy.sh`), replacing the DOMAIN by your public hostname. **This must be a public DNS name that points to your host** (i.e. your Carina cluster IP), or letsencrypt will not work. Letsencrypt will not generated certificates for plain IP numbers too, you must have a named host, but a free DNS name from "noip.com" will do. Get one.

```bash
docker run --detach \
  --name docker-proxy \
  --env EMAIL=me@email.com \
  --env DOMAIN=yourhost.thedomain.youchose \
  --env UPSTREAM=unix:/var/run/docker.sock \
  --publish 80:80 \
  --publish 443:443 \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume letsencrypt:/etc/letsencrypt \
  --volume letsencrypt-backups:/var/lib/letsencrypt \
  --volume dhparam-cache:/cache \
  vertigo/docker-proxy
```

Certificate generation takes a somewhat long time, but you can follow the log with:

    docker logs -f docker-proxy

The log output should be something like:

```
UPSTREAM(sed-friendly)=unix:\/var\/run\/docker\.sock
Provided domains
yourhost.thedomain.youchose
Services to reverse-proxy
unix:\/var\/run\/docker\.sock
(...)
Rendering template of nginx.conf
Rendering template of yourhost.thedomain.youchose in /etc/nginx/vhosts/yourhost.thedomain.youchose.conf
Ready
```

After "Ready" shows up in the log you can test the remote Docker engine with a simple "ping":

```bash
curl https://yourhost.thedomain.youchose/_ping
```

If you get on "OK" string as a response this means everything is fine. We are halfway there. This is a good time to extract the root CA from the generated certificate.

### Get the root CA

You will need it later. Open the URL above in your browser and export the root certificate to a file. C'mon, you can do it: there is always a way to view the current certificate from a page, expand its tree and copy the topmost certificate (alas, the root one) to a local file.

Mine had an ugly name: "DST Root CA X3.cer". Let us make a deal and rename the file to "ca.domain.cer". We will need this file later!

### Stop it now, I said NOW

**IMPORTANT:** right now your Docker engine/cluster REST API is open for everyone in the world. The fact that the endpoint is HTTPS is irrelevant. We must change our proxy to require the client certificate expected on port 2376.

To stop your proxy:

```bash
docker stop docker-proxy
docker rm docker-proxy
```

### Running with client-certificate CA

If you are using Carina or not I assume you have gone through the steps that give you a bunch of certificates that make the TLS-enabled engine work. Carina CLI downloads them to your machine automagically.

You will need to locate the files:

* ca.pem
* cert.pem
* key.pem

If you ran "eval $(carina env yourcluster)" you have them at $DOCKER_CERT_PATH folder. ***Please, make a copy of "ca.pem" on the same folder, named "ca.original.pem"***.

You can now run the commands below (as in `runcaproxy.sh`):

```bash
docker stop docker-proxy
docker rm docker-proxy
SSLCLIENTCA=`cat $DOCKER_CERT_PATH/ca.original.pem`
docker run --detach \
  --name docker-proxy \
  --env EMAIL=me@email.com \
  --env DOMAIN=yourhost.thedomain.youchose \
  --env UPSTREAM=unix:/var/run/docker.sock \
  --env "SSLCLIENTCA=$SSLCLIENTCA" \
  --publish 80:80 \
  --publish 443:443 \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume letsencrypt:/etc/letsencrypt \
  --volume letsencrypt-backups:/var/lib/letsencrypt \
  --volume dhparam-cache:/cache \
  --restart=unless-stopped \
  vertigo/docker-proxy
```

Now your Docker proxy will *only* accept the very same client certificate demanded by the engine on its TLS-enabled 2376 port. To test this endpoint you must use curl again:

```bash
curl https://yourhost.thedomain.youchose/_ping
```

But this time we *want* the error below, demanding the client certificate:

```html
<html>
<head><title>400 No required SSL certificate was sent</title></head>
<body bgcolor="white">
<center><h1>400 Bad Request</h1></center>
<center>No required SSL certificate was sent</center>
<hr><center>nginx/1.10.0</center>
</body>
</html>
```

To test the same REST endpoint with curl *and* the certificates it is easy, but some versions of curl don't get along with client certificates very well. This is the case with OSX version of curl, so [please have a fix for curl](CURL.md).

```bash
curl --cert $DOCKER_CERT_PATH/cert.pem --key $DOCKER_CERT_PATH/key.pem https://yourhost.thedomain.youchose/_ping
```

If you get the "OK" answer you are doing great! We are almost there.

### Fooling Docker

We still can't use the Docker client because it is trying to validate certificates using the original CA (ca.pem). Our HTTPS proxy uses another CA (in my case, from "noip.com"), the one we have exported a while ago.

Our exported file is named "ca.domain.cer". This is a binary file, you can check it with:

```bash
cat ca.domain.cer
```

If you see a text file with "-----BEGIN CERTIFICATE-----" on its first line this is *not* a text file, so please rename it to "ca.domain.pem".

If instead all you see is garbage this is indeed a binary file and we must convert it:

```bash
openssl x509 -inform der -in ca.domain.cer -outform pem -out ca.domain.pem
```

Check if the new file is a text one (first line):

```bash
cat ca.domain.pem
```

Now we must copy "ca.domain.pem" to the same folder where the other certiticates are:

```bash
cp ca.domain.pem $DOCKER_CERT_PATH/ca.domain.pem
```

Ok, careful now: now we will replace the CA Docker client uses for our new one *and* we will inform Docker of the new REST endpoint:

```bash
cp $DOCKER_CERT_PATH/ca.domain.pem $DOCKER_CERT_PATH/ca.pem
export DOCKER_HOST=tcp://yourhost.thedomain.youchose:443
```

Now Docker client uses our new endpoint, and all commands below will work as intended:

```bash
docker ps
docker version
```

We did it! This setting will work within any corporate environment where a transparent proxy resides *and* is still safe. Leave this container running 

Remember, to restore the Docker client to the original configuration:

```bash
cp $DOCKER_CERT_PATH/ca.original.pem $DOCKER_CERT_PATH/ca.pem
export DOCKER_HOST=tcp://yourclusterip:2376
```

...or just use Carina CLI:

```bash
eval $(carina env yourclustername)
```

### Man-in-the-middle Proxies

TODO

### Build arguments

If you want to build this image yourself you can set the variables BASEREPO and EPELREPO before running `build.sh` in order to choose a specific "yum mirror" from your local network. Running local builds becomes a lot faster with a mirror around.

This is explained a [bit more here](https://github.com/vertigobr/docker-base/blob/master/BUILDARGS.md).
