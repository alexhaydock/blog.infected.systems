# blog.infected.systems

Repository for https://blog.infected.systems

### Catpuccin-based Colour Scheme
* Light Mode (Default): Latte
* Dark Mode: Frappé
* Code Blocks: Mocha

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
