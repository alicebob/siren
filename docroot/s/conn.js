function runWS(wsURL, ui) {
	console.log("connecting to ", wsURL);
	const ws = new WebSocket(wsURL);
	ws.addEventListener('open', function (event) {
		console.log("got ws connection");
		ui.setConnected(true, undefined);
		ui.sendCmd = function(name, payload) {
			if (payload === undefined) {
				payload = {};
			}	
			ws.send(JSON.stringify({"name": name, "value": payload}));
		}
	});
	ws.addEventListener('close', function (event) {
		console.log("lost ws connection");
		ui.setConnected(false, function() { runWS(wsURL, ui) });
	});
	ws.addEventListener('message', function (event) {
		const msg = JSON.parse(event.data);
		handleMsg(msg.name, msg.value, ui);
	});
};

function handleMsg(msgName, payload, ui) {
	switch(msgName) {
		case "siren/config":
			ui.mpdhost = payload.mpdhost;
			ui.artistmode = payload.artistmode;
			break;
		case "siren/connection":
			ui.setMPDConnected(payload);
			break;
		case "siren/playlist":
			ui.setPlaylist(payload);
			break;
		case "siren/status":
			ui.setPlaybackStatus(payload.songid, payload.state, payload.duration, payload.elapsed);
			break;
		case "siren/list":
			ui.setList(payload.id, payload.list);
			break;
		case "siren/inodes":
			ui.setInodes(payload.id, payload.inodes);
			break;
		case "siren/track":
			ui.setTrack(payload.id, payload.track);
			break;
		default:
			console.log("unhandled message type", msgName, payload);
	}
}
