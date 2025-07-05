# blog.infected.systems

Repository for https://blog.infected.systems

### Refresh Git submodules for themes & addons
```sh
git submodule update --init --recursive
```

### Install Hugo
```sh
sudo snap install hugo
```

### Test site
```sh
hugo serve
```

### Build prod site
```sh
hugo
```

### Sync site to Nintendo Wii for deployment
```sh
rsync -avsh --delete $PWD/public/ root@192.168.191.88:/srv/www/htdocs/
```
