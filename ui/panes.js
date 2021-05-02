import {duration} from './duration.js';

var idid = 42;
function genid() {
	idid += 1;
	return "id" + idid;
}

export class PaneArtists {
	constructor(addpane) {
		this.id = genid(); // "artists"
		this.addpane = addpane
		this.playlist = undefined;

		this.title = "Artists"
		this.items = []
	}
	sync(conn) {
		conn.sendCmd("list", {"what": "artists", "id": this.id});
	}
	setItems(ls) {
		for (const l of ls) {
			this.items.push({
				title: l.artist,
				selected: false,
				onclick: () => {
					this.playlist = l.artist
					this.addpane(this.nextPane(l.artist), this.id)
					for (var c of this.items) {
						c.selected = c.title == l.artist;
					}
				},
			});
		}	
	}
	nextPane(artist) {
		return new PaneAlbums(this.addpane, artist);
	}
	addtoplaylist(conn) {
		conn.sendCmd("findadd", { artist: this.playlist, });
	}
}

export class PaneAlbums {
	constructor(addpane, artist) {
		this.id = genid();
		this.addpane = addpane
		this.artist = artist

		this.title = artist
		this.items = []
	}
	sync(conn) {
		conn.sendCmd("list", {
			"what": "artistalbums",
			"id": this.id,
			"artist": this.artist,
		});
	}
	setItems(ls) {
		for (const l of ls) {
			this.items.push({
				title: l.album,
				onclick: () => {
					this.playlist = l.album;
					this.addpane(this.nextPane(l.artist, l.album), this.id)
					for (var c of this.items) {
						c.selected = c.title == l.album;
					}
				},
			});
		}	
	}
	nextPane(artist, album) {
		return new PaneTracks(this.addpane, artist, album);
	}
	addtoplaylist(conn) {
		conn.sendCmd("findadd", { artist: this.artist, album: this.playlist });
	}
}

export class PaneTracks {
	constructor(addpane, artist, album) {
		this.id = genid();
		this.addpane = addpane
		this.artist = artist
		this.album = album

		this.title = album
		this.items = []
	}
	sync(conn) {
		conn.sendCmd("list", {
			"what": "araltracks",
			"id": this.id,
			"artist": this.artist,
			"album": this.album,
		});
	}
	setItems(ls) {
		for (const l of ls) {
			this.items.push({
				title: l.track.title,
				onclick: () => {
					this.playlist = l.track.title,
					this.addpane(this.nextPane(l.track.id), this.id)
					for (var c of this.items) {
						c.selected = c.title == l.track.title;
					}
				},
			});
		}	
	}
	nextPane(trackid) {
		return new PaneTrack(trackid);
	}
	addtoplaylist(conn) {
		conn.sendCmd("findadd", {
			artist: this.artist, album: this.album, track: this.playlist });
	}
}

function esc(t) {
	return new Option(t).innerHTML; // META: there _must_ be a nicer way...
}

export class PaneTrack {
	constructor(trackid) {
		this.id = genid();
		this.trackid = trackid

		this.html = "loading..."
		this.endpane = true;
	}
	sync(conn) {
		conn.sendCmd("track", {
			"file": this.trackid,
			"id": this.id,
		});
	}
	setTrack(track) {
		this.html = esc(track.title) + "<br />" +
			"artist: " + esc(track.artist) + "<br />" +
			"album artist: " + esc(track.albumartist) + "<br />" +
			"album: " + esc(track.album) + "<br />" +
			"track: " + esc(track.track) + "<br />" +
			"duration: " + duration(track.duration) + "<br />" +
			"";
	}
	play(conn) {
		conn.sendCmd("clear");
		conn.sendCmd("add", { id: this.trackid, });
		conn.sendCmd("play");
	}
}

export class PaneFiles {
	constructor(addpane, fileid) {
		this.id = genid();
		this.addpane = addpane
		this.fileid = fileid
		this.playlist = undefined;

		this.title = fileid
		this.items = []
	}
	sync(conn) {
		conn.sendCmd("loaddir", {"file": this.fileid, "id": this.id});
	}
	setInodes(elems) {
		for (const l of elems) {
			if (l.file != null) {
				this.items.push({
					title: l.file.title,
					id: l.file.id,
					selected: false,
					onclick: () => {
						this.playlist = l.file.id
						const next = new PaneTrack(l.file.id);
						this.addpane(next, this.id)
						for (var c of this.items) {
							c.selected = c.id == l.file.id;
						}
					},
				});
			} else {
				this.items.push({
					title: l.dir.title,
					id: l.dir.id,
					selected: false,
					onclick: () => {
						this.playlist = l.dir.id
						const next = new PaneFiles(this.addpane, l.dir.id);
						this.addpane(next, this.id)
						for (var c of this.items) {
							c.selected = c.id == l.dir.id;
						}
					},
				});
			}
		}	
	}
	addtoplaylist(conn) {
		conn.sendCmd("add", { id: this.playlist, });
	}
}
