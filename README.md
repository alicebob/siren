Browser based MPD client.

Made with Svelte and `display:grid`.

<img src="./img_playlist.png" width="400" /><img src="./img_files.png" width="400" />


## Releases

Binary releases are on the [releases](https://github.com/alicebob/siren/releases) page.


## History

Version 1.0 was with Elm 0.18.  
Version 2.0 was with Purescript.  
Version 3.0 was plain Javascript.  
Version 4.0 is svelte and esBuild.  


## Build

- you need a Go (>=1.16)
- `make`
- run the binary from ./siren
- open http://localhost:6601/

All resources are bundled in the binary, so you can copy it over to other
machines.

The UI files are stored compiled in the repo, so there is no need to install anything. See the Makefile in the `./ui/` dir how to update the JavaScript.


### Raspberry Pi build

Thanks to Go's cross-platform support you can build Siren on your laptop, and copy the executable to your Raspberry Pi.

- you need a Go compiler on your laptop
- `make build-pi`
- copy `siren/siren` to your Raspberry Pi
- open http://your_raspberry:6601/


## Running

Siren connects to the mpd at localhost:6600 by default. Change it with for example: `./siren -mpd=192.168.1.2:6600`

If you don't want to make Siren available to everyone in your subnet, use: `./siren -listen=localhost:6601`

### Artist vs Albumartist

By default Siren uses the `albumartist` field for the artist browse screen. If you want to use the `artist` instead field you can specify that with: `./siren -albumartist=false`.

### NGINX

Suggested nginx config:
```
        location /siren/ { 
                location /siren/mpd/ws { 
                        proxy_set_header Upgrade $http_upgrade; 
                        proxy_set_header Connection "upgrade"; 
                        proxy_http_version 1.1; 
                        proxy_set_header Host $host; 
                        proxy_pass http://127.0.0.1:6601/mpd/ws; 
                } 
                proxy_pass http://127.0.0.1:6601/; 
        } 
```


## Development

Usually the CSS and Javascript files are embedded in the executable, but you
can use the filesystem while developing. Run siren with:

`./siren/siren --docroot ./docroot`


## Links

- [Music Player Daemon](https://www.musicpd.org)
- [Go](https://golang.org)
- [Svelte](https://svelte.dev)
- [esbuild](https://esbuild.github.io)
