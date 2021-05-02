export default class Conn {
	constructor(url) {
		this.wsURL = url;
	}
	connect() {
		const ws = new WebSocket(this.wsURL);
		this.ws = ws;
		const self = this;
		ws.addEventListener('open', function (event) {
			self.setConnected(true);
		});
		ws.addEventListener('close', function (event) {
			self.setConnected(false);
		});
		ws.addEventListener('message', function (event) {
			const msg = JSON.parse(event.data);
			self.handleMsg(msg.name, msg.value);
		});
	}
	setConnected(c) {
		console.log("setConnected", c);
	}
	setConfig(mpdhost, artistmode) {
		console.log("setConfig", mpdhost, artistmode);
	}
	setMPDConnected(c) {
		console.log("setMPDConnected", c);
	}
	setPlaylist(c) {
		console.log("setPlaylist", c);
	}
	setPlaybackStatus(songid, state, duration, elapsed) {
		console.log("setPlaybackStatus", songid, state, duration, elapsed);
	}
	setList(id, l) {
		console.log("setList", id, l);
	}
	setInodes(id, l) {
		console.log("setInodes", id, l);
	}
	setTrack(id, t) {
		console.log("setTrack", id, t);
	}

	handleMsg(msgName, payload) {
		switch(msgName) {
			case "siren/config":
				this.setConfig(payload.mpdhost, payload.artistmode);
				break;
			case "siren/connection":
				this.setMPDConnected(payload);
				break;
			case "siren/playlist":
				this.setPlaylist(payload);
				break;
			case "siren/status":
				this.setPlaybackStatus(payload.songid, payload.state, payload.duration, payload.elapsed);
				break;
			case "siren/list":
				this.setList(payload.id, payload.list);
				break;
			case "siren/inodes":
				this.setInodes(payload.id, payload.inodes);
				break;
			case "siren/track":
				this.setTrack(payload.id, payload.track);
				break;
			default:
				console.log("unhandled message type", msgName, payload);
		}
	}

	sendCmd(name, payload) {
		// TODO: handle if not connected
		if (payload === undefined) {
			payload = {};
		}	
		this.ws.send(JSON.stringify({"name": name, "value": payload}));
	}
}
