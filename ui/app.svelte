<script>
	import conlib from './conn.js';
	import { afterUpdate } from 'svelte';
	import {PaneArtists, PaneFiles} from './panes.js';
	import Playlist from './playlist.svelte';
	import Artists from './artists.svelte';

	let view = 'playlist';
	let timer = undefined;
	function stopTimer() {
		if (timer !== undefined) {
			window.clearInterval(timer);
			timer = undefined;
		}
	}

	function addArtistPane(pane, after) {
		mpd.artistPanes.forEach((item, i) => {
			if (item.id === after) {
				mpd.artistPanes.splice(i+1)
			}
		})
		mpd.artistPanes.push(pane)
		mpd.artistPanes = mpd.artistPanes; // trigger render
		pane.sync(conn);
	}

	function addFilePane(pane, after) {
		mpd.filePanes.forEach((item, i) => {
			if (item.id === after) {
				mpd.filePanes.splice(i+1)
			}
		})
		mpd.filePanes.push(pane)
		mpd.filePanes = mpd.filePanes; // trigger render
		pane.sync(conn);
	}

	afterUpdate(() => {
		// Scroll the panes to the right as far as they go.
		// meta: no idea how to do this only on a new pane
		var elem = document.getElementsByClassName("mc")
		if (elem.length > 0) {
			elem[0].scrollLeft = elem[0].scrollLeftMax;
		}
	});

	let mpd = {
		connected: false,
		mpdconnected: false,
		mpdhost: '',
		artistmode: '',
		playlist: [],
		filePanes: [new PaneFiles(addFilePane, "/")],
		artistPanes: [new PaneArtists(addArtistPane)],
		playback_songid: 0,
		playback_state: 'stop',
		playback_elapsed: 0,

		apply: (id, cb) => {
			for (const a of mpd.filePanes) {
				if (a.id === id) {
					cb(a);
					mpd.foo = 1; // trigger UI update
				}
			}
			for (const a of mpd.artistPanes) {
				if (a.id === id) {
					cb(a);
					mpd.foo = 1; // trigger UI update
				}
			}
		},
	};


	var wsURL = (window.location.protocol === "https:" ? "wss://" : "ws://") +
		window.location.host +
		window.location.pathname + "mpd/ws";
	let conn = new conlib(wsURL);
	conn.setConnected = (c) => {
		mpd.connected = c;
		mpd.filePanes[0].sync(conn);
		mpd.artistPanes[0].sync(conn);
	}
	conn.setMPDConnected = (c) => mpd.mpdconnected = c;
	conn.setPlaylist = (c) => mpd.playlist = c;
	conn.setPlaybackStatus = (songid, state, duration, elapsed) => {
		mpd.playback_songid = songid
		mpd.playback_state = state
		// mpd.playback_duration = duration
		mpd.playback_elapsed = elapsed

		stopTimer();
		if (state === 'play') {
			timer = window.setInterval(() => {
                // TODO: this is not precise enough
                mpd.playback_elapsed += 1;
            }, 1000);
		}
	}
	conn.setConfig = (mpdhost, artistmode) => {
		mpd.mpdhost = mpdhost;
		mpd.artistmode = artistmode;
	};
	conn.setList = (id, elems) => {
		mpd.apply(id, (pane) => {
			pane.setItems(elems);
		})
	};
	conn.setInodes = (id, ls) => {
		mpd.apply(id, (pane) => {
			pane.setInodes(ls);
		})
	};
	conn.setTrack = (id, track) => {
		mpd.apply(id, (pane) => {
			pane.setTrack(track);
		})
	};
	conn.connect();

	$: playlistHeader = "Playlist (" + mpd.playlist.length + ")"
</script>

<div class="mpd">
<nav>
	<a href="#playlist" class="logo" on:click|preventDefault={() => view = 'playlist'}
	>Siren!</a>
	<span></span>
	<a href="#playlist"
		class="tab {view === 'playlist'?"current":"inactive"}"
		title="Show playlist"
		on:click|preventDefault={() => view = 'playlist'}
	>{playlistHeader}</a>
	<a href="#files"
		class="tab {view === 'files'?"current":"inactive"}"
		title="Browse the filesystem"
		on:click|preventDefault={() => view = 'files'}
	>Files</a>
	<a href="#artists"
		class="tab {view === 'artists'?"current":"inactive"}"
		title="Browse by {mpd.artistmode}"
		on:click|preventDefault={() => view = 'artists'}
	>Artists</a>
	<span></span>
	{#if mpd.connected}
		<a href="#reconnect"
			class="status online"
			title={mpd.mpdconnected
					? "connected to the Siren daemon, and to MPD {mpd.mpdhost}"
					: "connected to the Siren daemon, but no connection to MPD {mpd.mpdhost}"}
			on:click|preventDefault={() => {}}
			>{#if mpd.mpdconnected}Online{:else}No MPD{/if}</a>
	{:else}
	<a href="#reconnect"
		class="status offline"
		title="offline. Click to reconnect"
		on:click|preventDefault={() => conn.connect()}
		>Offline</a>
	{/if}
</nav>
{#if view === 'playlist'}
	<Playlist
		playlist={mpd.playlist}
		conn={conn}
		playback_state={mpd.playback_state}
		playback_songid={mpd.playback_songid}
		playback_elapsed={mpd.playback_elapsed}
	/>
{:else if view === 'files'}
	<!-- FIXME -->
	<Artists artists={mpd.filePanes} conn={conn}/>
{:else if view === 'artists'}
	<Artists artists={mpd.artistPanes} conn={conn}/>
{/if}
</div>
