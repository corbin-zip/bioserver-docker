# Biohazard: Outbreak Server, Dockerized

Hi all. This is my first attempt at building a docker image, and I thought it came out alright. There is still some work to do, but it functions enough for an initial commit I think. Read on!

## What does it do?

It currently pulls the DNASrep (DNAS replacement server) and bioserver (Biohazard: Outbreak file 1 & 2 server) repos from my github, and builds and configures a mostly functional (see limitations section below) Outbreak server utilizing these components. It also downloads and builds OpenSSL and Apache from source, as they require configuration prior to compilation to make the DNAS server work

## How do I use it?

This requires docker & git to be installed locally and ultimately seems to build a ~2.25GB image.

```
git clone https://github.com/corbin-ch/bioserver-docker.git
cd bioserver-docker
docker build -t "bioserver-docker" .
docker run -ti --name bioserver bioserver-docker
docker container create --name bioserver bioserver-docker:latest
docker container start bioserver
```

Grab the IP address of your running docker container via `docker ps -q | xargs docker inspect --format "{{range .NetworkSettings.Networks}}{{print .IPAddress}} {{end}}{{.Name}}"` (I know, isn't it crazy how non-trivial it is to get such a basic piece of information? I found this answer [here](https://superuser.com/questions/1167922/get-list-of-docker-ip-containers))

Now you can go ahead and configure your PS2's emulator running on the same device to use your container's IP as its DNS server

## What are its limitations?

**Currently, this only supports local connections. "But it's a server! It should support remote connections!" I know, and that support is planned but not currently implemented.**

If you'd like to give it a try before it's officially supported, before running the `docker build` command, go ahead and edit `config/entrypoint.sh` and look at the 4 `sed` lines that all contain the string `$(hostname -i)`. I believe that you can edit all of these lines (except for the line containing `dnsmasq.conf`) and replace `$(hostname -i)` with either the local IP address of the device you're running docker on (ie: `192.168.1.123`), or with your external IP address (ie: the IP address that your ISP assigns you). Ignore the fact that some say `{{EXTERNAL_IP}}` and others say `{{CONTAINER_IP}}` -- I was making my best guesses as I wrote this script but I now believe that all of those should be the same. For all 3 lines (again, exclude the `dnsmasq.conf` line), use either your LAN IP if you're trying to run this on a LAN, or your external IP if you're trying to run this over the internet

Lastly, when you run `docker container create`, you'll need to publish several ports. You will also need to forward these ports if you're planning on running this over the internet, but that's beyond the scope of this guide. Here is a sample `docker container create` command that publishes all of the necessary ports:

`docker container create -p 53:53 -p 80:80 -p 443:443 -p 8200:8200 -p 8300:8300 -p 8590:8590 -p 8690:8690 --name bioserver bioserver-docker:latest`

I want to re-iterate that this sort of functionality will be supported shortly, and this section is merely intended as a temporary workaround if you wanted to get something up and running ASAP
