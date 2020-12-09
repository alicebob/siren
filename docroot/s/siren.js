class UI {
	constructor(root) {
		this.root = root;
		this.mpdhost = "";
		this.playlist = [];
		this.sendCmd = function(){}; // FIXME?
		this.playTrackID = 0;
		this.playState ="stop";
		this.tab = "playlist";
		this.setupPanes();
	}

	setupPanes() {
		this.paneFile = new Pane(
			"root",
			"/",
			(ui) => {
				ui.sendCmd("loaddir", {"file": "", "id": "root"});
			},
		);
		this.paneArtists = new Pane(
			"artists",
			"Artists",
			(ui) => {
				ui.sendCmd("list", {"what": "artists", "id": "artists"});
			},
		);
	}

	setConnected(connected, reconnectCB) {
		const elem = this.root.querySelector("#connected");
		if (connected) {
			elem.className = "status online";
			elem.innerHTML = "No MPD";
			elem.title = "connected to the Siren daemon, but no connection to MPD " + escape(this.mpdhost);
			elem.onclick = undefined;

			this.renderTabs("playlist");
			return;
		}
		elem.className = "status offline";
		elem.innerHTML = "Offline";
		elem.title = "offline. Click to reconnect";
		elem.onclick = reconnectCB;
		if (this.timer !== undefined) {
			window.clearInterval(this.timer);
			this.timer = undefined;
		}
	}

	setMPDConnected(connected) {
		if (! connected) {
			this.setConnected(true, undefined);
			return;
		}
		const elem = this.root.querySelector("#connected");
		elem.innerHTML = "Online";
		elem.title = "connected to Siren and MPD " + escape(this.mpdhost);

		this.paneFile.sync(this);
		this.paneArtists.sync(this);
	}

	setPlaylist(playlist) {
		this.playlist = playlist;
		this.root.querySelector("#playlisttab").innerHTML = "Playlist (" + playlist.length + ")";

		this.renderPlaylist();
	}

	setPlaybackStatus(trackID, state, duration, elapsed) {
		this.playTrackID = trackID;
		this.playState = state; // play/pause/stop...
		this.playDuration = duration;
		this.playElapsed = elapsed;

		this.renderPlayback();
		this.renderProgress();
		this.renderPlaylist();
		if (this.timer !== undefined) {
			window.clearInterval(this.timer);
		}
		if (state === "play") {
			this.timer = window.setInterval(() => {
				// TODO: this is not precise enough
				this.playElapsed += 1;
				this.renderProgress();
			}, 1000);
		}
	}

	eventProgress(v) {
		this.sendCmd("seek", {"seconds": parseFloat(v), "song": this.playTrackID});
	}

	setPane(id, callback) {
		let pane = this.paneFile;
		while (pane) {
			if (pane.id === id) {
				callback(pane);
				return;
			}
			pane = pane.next;
		}
		pane = this.paneArtists;
		while (pane) {
			if (pane.id === id) {
				callback(pane);
				return;
			}
			pane = pane.next;
		}
	}

	// content of a directory
	setInodes(id, inodes) {
		let ls = [];
		for (const e of inodes) {
			ls.push(loadInode(e));
		}

		this.setPane(id, (pane) => {
			pane.setList(ls);
		})
	}

	setTrack(id, track) {
		this.setPane(id, (pane) => {
			pane.setTrack(track);
		})
	}

	// add list of files/artists/... from server. They are the content of a single pane.
	setList(id, entries) {
		let ls = [];
		if (entries) {
			for (const e of entries) {
				ls.push(loadEntry(e));
			}
		}

		// Find the pane this update is for. It's possible that it's not there,
		// if the user clicked on something before the update came in.
		this.setPane(id, (pane) => {
				pane.setList(ls);
				// this.renderTabAlbum();
		})
	}

	findInPlaylist(trackID) {
		for (const t of this.playlist) {
			if (t.id === trackID) {
				return t.track;
			}
		}
		return undefined;
	}

	showTab(tab) {
		this.renderTabs(tab)
		// FIXME display stuff
		this.root.querySelector("#pageplaylist").style.display = "none";
		this.root.querySelector("#pagefiles").style.display = "none";
		this.root.querySelector("#pagealbum").style.display = "none";
		switch (tab) {
			case "playlist":
				this.root.querySelector("#pageplaylist").style.display = "grid";
				// this.renderPlaylist() // FIXME: remove
				break
			case "files":
				this.root.querySelector("#pagefiles").style.display = "grid";
				this.renderTabFiles() // FIXME: remove
				break
			case "album":
				this.root.querySelector("#pagealbum").style.display = "grid";
				this.renderTabAlbum() // FIXME: remove
				break
		}
	}

	renderTabs(selectedTab) {
		const playlist = this.root.querySelector("#playlisttab")
		playlist.onclick = () => {
			this.showTab("playlist")
		};
		playlist.className = selectedTab === "playlist" ? "tab current" : "tab inactive"

		const files = this.root.querySelector("#filestab")
		filestab.onclick = () => {
			this.showTab("files")
		};
		filestab.className = selectedTab === "files" ? "tab current" : "tab inactive"

		const album = this.root.querySelector("#albumtab")
		album.onclick = () => {
			this.showTab("album")
		};
		album.className = selectedTab === "album" ? "tab current" : "tab inactive"
	}

	renderPlayback() {
		const play = this.root.querySelector("#playplay");
		const pause = this.root.querySelector("#playpause");
		switch (this.playState) {
			case "play":
				play.style.display = "none";
				pause.style.display = "inline-block";
				break;
			case "pause":
			case "stop":
				play.style.display = "inline-block";
				pause.style.display = "none";
				break;
		}

		this.root.querySelector(".player .title").textContent = "";
		this.root.querySelector(".player .artist").textContent = "";
		switch (this.playState) {
			case "play":
			case "pause":
				const song = this.findInPlaylist(this.playTrackID);
				if (song) {
					this.root.querySelector(".player .title").textContent = song.title;
					this.root.querySelector(".player .artist").textContent = song.artist;
				}
		}
	}

	renderProgress()  {
		this.root.querySelector("#progress").max = this.playDuration;
		this.root.querySelector("#progress").value = this.playElapsed;
		this.root.querySelector("#progresstxt").textContent = duration(this.playElapsed) + "/" + duration(this.playDuration);
	}


	renderPlaylist() {
		const elem = this.root.querySelector("#playlist");
		cleanElem(elem);
		for (const song of this.playlist) {
			let entry = document.createElement("div");
			entry.className = "entry" + (this.playTrackID === song.id ? " playing" : "");
			entry.appendChild(simplediv("track", song.track.track));
			entry.appendChild(simplediv("title", song.track.title));
			entry.appendChild(simplediv("artist", song.track.artist)); // FIXME
			entry.appendChild(simplediv("album", song.track.album));
			entry.appendChild(simplediv("dur", duration(song.track.duration)));
			entry.onclick = () => this.sendCmd("playid", {"id": song.id});
			elem.appendChild(entry);
		}
	}

	renderTabFiles() {
		const elem = this.root.querySelector("#pagefiles");
		cleanElem(elem);
		let pane = this.paneFile;
		while (pane) {
			elem.appendChild(pane.render(this))
			pane = pane.next
		}
	}

	renderTabAlbum() {
		const elem = this.root.querySelector("#pagealbum");
		cleanElem(elem);
		let pane = this.paneArtists;
		while (pane) {
			elem.appendChild(pane.render(this))
			pane = pane.next
		}
	}

	scrollRight(elem) {
		elem.scrollLeft = elem.scrollLeftMax;
	}
}

function cleanElem(elem) {
	if (elem === null) {
		return
	}
	while (elem.firstChild) {
		elem.removeChild(elem.firstChild);
	}
}

// a div with a class and text content
function simplediv(cl, txt) {
	let elem = document.createElement("div");
	elem.className = cl;
	elem.appendChild(document.createTextNode(txt));
	return elem;
}

class Pane {
	constructor(id, title, sync) {
		this.id = id // dom ID
		this.syncCB = sync
		this.list = [] // list of Entry() objects
		this.next = null // pointer to the next pane, if any

		this.footer = simplediv("footer", "");

		let main = document.createElement("div");
		main.className = "main";
		this.main = main;

		let pane = document.createElement("div");
		pane.className = "pane";
		pane.appendChild(simplediv("title", title));
		pane.appendChild(main);
		pane.appendChild(this.footer);
		this.dom = pane;
	}

	remove() {
		if (this.next) {
			this.next.remove();
		}
		this.dom.remove();
	}

	setSelected(id) {
		for (let item of this.main.children) {
			item.className = id == item.id ? "selected" : "";
		}
	}

	setList(ls) {
		cleanElem(this.main);
		for (let item of ls) {
			const it = simplediv("", item.title());
			it.id = item.elemid();
			it.onclick = () => {
				if (this.next) {	
					this.next.remove();
				}

				this.setSelected(item.elemid());
				this.addFooter(ui, item);
				const p = item.nextPane();
				// on click, we make a new pane and put if after the pane you clicked on.
				// It'll be filled later, when we get the content via the websocket.
				this.next = p;
				// sync sends the update request to the server, which must be
				// done after the panel is added to the list.
				p.sync(ui);
				this.dom.parentElement.appendChild(p.render(ui));
				ui.scrollRight(this.dom.parentElement);
			};
			this.main.appendChild(it);
		}
	}

	render(ui) {
		return this.dom;
	}

	addFooter(ui, item) {
		cleanElem(this.footer);

		let add = document.createElement("button");
		add.className = "add";
		add.innerHTML = "ADD TO PLAYLIST";
		add.onclick = () => {
			item.addToPlaylist(ui);
		};
		this.footer.appendChild(add);

		let play = document.createElement("button");
		play.className = "play";
		play.innerHTML = "PLAY";
		play.onclick = () => {
			ui.sendCmd("clear");
			item.addToPlaylist(ui);
			ui.sendCmd("play");
		};
		this.footer.appendChild(play);
	}

	sync(ui) {
		this.syncCB(ui)
	}
}

class TrackPane {
	constructor(id, trackID, loading) {
		this.id = id
		this.trackID = trackID
		this.loading = loading

		let pane = document.createElement("div");
		pane.className = "endpane";
		this.dom = pane
	}

	remove() {
		this.dom.remove();
	}

	render(ui) {
		let main = document.createElement("div");
		main.className = "main";
		main.innerHTML = this.loading;
		this.main = main

		const footer = simplediv("footer", "");
		let add = document.createElement("button");
		add.innerHTML = "PLAY";
		add.onclick = () => {
			ui.sendCmd("clear");
			ui.sendCmd("add", { id: this.trackID, });
			ui.sendCmd("play");
		};
		footer.appendChild(add);

		cleanElem(this.dom);
		this.dom.appendChild(main);
		this.dom.appendChild(footer);
		return this.dom
	}

	setTrack(track) {
		cleanElem(this.main);
		renderTrack(track, this.main);
	}

	sync(ui) {
		ui.sendCmd("track", {
			"file": this.trackID,
			"id": this.id,
		});
	}
}

class Entry {
	constructor(elem) {
		this.type = elem.type
	}

	elemid() {
		return this.type + this.title();
	}

	title() { return ""; }

	addToPlaylist(ui) {}

	nextPane() { return undefined; }
}

class EntryArtist extends Entry {
	constructor(elem) {
		super(elem);
		this.artist = elem.artist;
	}

	title() {
		return this.artist;
	}

	addToPlaylist(ui) {
		ui.sendCmd("findadd", {
			artist: this.artist,
		});
	}

	nextPane() {
		return new Pane(
			this.elemid(),
			this.artist,
			(ui) => {
				ui.sendCmd("list", {
					"what": "artistalbums",
					"id": this.elemid(),
					"artist": this.artist,
				});
			},
		);
	}
}

class EntryAlbum extends Entry {
	constructor(elem) {
		super(elem);
		this.artist = elem.artist;
		this.album = elem.album;
	}

	elemid() {
		return this.type + this.artist + this.album;
	}

	title() {
		return this.album;
	}

	addToPlaylist(ui) {
		ui.sendCmd("findadd", {
			artist: this.artist,
			album: this.album,
		});
	}

	nextPane() {
		return new Pane(
			this.elemid(),
			this.album,
			(ui) => {
				ui.sendCmd("list", {
					"what": "araltracks",
					"id": this.elemid(),
					"artist": this.artist,
					"album": this.album,
				});
			},
		);
	}
}

class EntryTrack extends Entry {
	constructor(elem) {
		super(elem);
		this.track = elem.track;
	}

	title() {
		return this.track.title;
	}

	addToPlaylist(ui) {
		ui.sendCmd("findadd", {
			artist: this.track.artist,
			album: this.track.album,
			track: this.track.title,
		});
	}

	nextPane() {
		return new TrackPane("file" + this.track.id, this.track.id, "loading...");
	}
}

class EntryDir {
	constructor(dir) {
		this.id = dir.id;
		this._title = dir.title;
	}

	title() {
		return this._title;
	}

	elemid() {
		return "dir" + this.id;
	}

	addToPlaylist(ui) {
		ui.sendCmd("add", { id: this.id, });
	}

	nextPane() {
		return new Pane(
			this.elemid(),
			this._title,
			(ui) => {
				ui.sendCmd("loaddir", {"file": this.id, "id": this.elemid()});
			},
		);
	}
}

class EntryFile {
	constructor(file) {
		this.id = file.id;
		this._title = file.title;
	}

	title() {
		return this._title;
	}

	elemid() {
		return "file" + this.id;
	}

	addToPlaylist(ui) {
		ui.sendCmd("add", { id: this.id, });
	}

	nextPane() {
		return new TrackPane(
			this.elemid(),
			this.id,
			"loading...",
		);
	}
}

function loadEntry(elem) {
	switch (elem.type) {
		case "artist":
			return new EntryArtist(elem);
		case "album":
			return new EntryAlbum(elem);
		case "track":
			return new EntryTrack(elem);
	}
}

function loadInode(elem) {
	if (elem.dir !== null) {	
		return new EntryDir(elem.dir);
	}
	return new EntryFile(elem.file);
}

function renderTrack(track, p) {
	p.appendChild(document.createTextNode(track.title));
	p.appendChild(document.createElement("br"));
	p.appendChild(document.createTextNode("artist: " + track.artist));
	p.appendChild(document.createElement("br"));
	p.appendChild(document.createTextNode("album artist: " + track.albumartist));
	p.appendChild(document.createElement("br"));
	p.appendChild(document.createTextNode("album: " + track.album));
	p.appendChild(document.createElement("br"));
	p.appendChild(document.createTextNode("track: " + track.track));
	p.appendChild(document.createElement("br"));
	p.appendChild(document.createTextNode("duration: " + duration(track.duration)));
	p.appendChild(document.createElement("br"));
	return p;
}

function duration(t) {
	t = t.toFixed(0);
	sec = (t % 60).toFixed(0);
	min = Math.floor(t / 60);
	if (sec < 10) {
		return min + ":0" + sec;
	}
	return min + ":" + sec;
}
