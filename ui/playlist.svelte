<script>
	import {duration} from './duration.js';

	export let playlist = [];
	export let playback_state = 'stop';
	export let playback_songid = 'stop';
	export let playback_elapsed = 0;
	export let conn = undefined;
</script>

<div id="pageplaylist" class="playlistwrap">
	<div class="playlist">
		<div class="commands"> 
			<button on:click={() => conn.sendCmd('clear') }>CLEAR PLAYLIST</button>
		</div>
		<div class="header">
			<div class="track">Track</div>
			<div class="title">Title</div>
			<div class="artist">Artist</div>
			<div class="album">Album</div>
			<div class="dur"></div>
		</div>
	</div>
	<div id="playlist" class="entries">
	{#each playlist as entry}
		<div class="entry {playback_songid === entry.id ? "playing" : ""}"
			on:click={() => {conn.sendCmd("playid", {"id": entry.id})}}
		>
			<div class="track">{entry.track.track}</div>
			<div class="title">{entry.track.title}</div>
			<div class="artist">{entry.track.artist}</div> <!-- FIXME -->
			<div class="album">{entry.track.album}</div>
			<div class="dur">{duration(entry.track.duration)}</div>
		</div>
	{/each}
	</div>
	<div class="player">
		<div class="buttons">
			<a id="playprevious" class={playback_state === "play" ? "enabled" : ""} on:click={() => conn.sendCmd('previous')}>
				<div style="color: white; width: 42px; display: inline-block">
					<!-- chevron-circle-left.svg + 'fill="currentColor"' -->
					<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><!-- Font Awesome Free 5.15.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) --><path fill="currentColor" d="M256 504C119 504 8 393 8 256S119 8 256 8s248 111 248 248-111 248-248 248zM142.1 273l135.5 135.5c9.4 9.4 24.6 9.4 33.9 0l17-17c9.4-9.4 9.4-24.6 0-33.9L226.9 256l101.6-101.6c9.4-9.4 9.4-24.6 0-33.9l-17-17c-9.4-9.4-24.6-9.4-33.9 0L142.1 239c-9.4 9.4-9.4 24.6 0 34z"/></svg>
				</div>
			</a>

			{#if playback_state === 'play'}
				<a id="playpause" class="enabled" on:click={() => conn.sendCmd('pause')}>
					<div style="color: white; width: 42px; display: inline-block">
						<!-- play-circle.svg + 'fill="currentColor"' -->
						<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><!-- Font Awesome Free 5.15.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) --><path fill="currentColor" d="M256 8C119 8 8 119 8 256s111 248 248 248 248-111 248-248S393 8 256 8zm-16 328c0 8.8-7.2 16-16 16h-48c-8.8 0-16-7.2-16-16V176c0-8.8 7.2-16 16-16h48c8.8 0 16 7.2 16 16v160zm112 0c0 8.8-7.2 16-16 16h-48c-8.8 0-16-7.2-16-16V176c0-8.8 7.2-16 16-16h48c8.8 0 16 7.2 16 16v160z"/></svg>
					</div>
				</a>
			{:else}
				<a id="playplay" class="enabled" on:click={() => conn.sendCmd('play')}>
					<div style="color: white; width: 42px; display: inline-block">
						<!-- play-circle.svg + 'fill="currentColor"' -->
						<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><!-- Font Awesome Free 5.15.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) --><path fill="currentColor" d="M256 8C119 8 8 119 8 256s111 248 248 248 248-111 248-248S393 8 256 8zm115.7 272l-176 101c-15.8 8.8-35.7-2.5-35.7-21V152c0-18.4 19.8-29.8 35.7-21l176 107c16.4 9.2 16.4 32.9 0 42z"/></svg>
					</div>
				</a>
			{/if}
			<a id="playstop" class="enabled" on:click={() => conn.sendCmd('stop')}>
				<div style="color: white; width: 42px; display: inline-block">
					<!-- stop-circle.svg + 'fill="currentColor"' -->
					<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><!-- Font Awesome Free 5.15.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) --><path fill="currentColor" d="M256 8C119 8 8 119 8 256s111 248 248 248 248-111 248-248S393 8 256 8zm96 328c0 8.8-7.2 16-16 16H176c-8.8 0-16-7.2-16-16V176c0-8.8 7.2-16 16-16h160c8.8 0 16 7.2 16 16v160z"/></svg>
				</div>
			</a>
			<a id="playnext" class="enabled" on:click={() => conn.sendCmd('next')}>
				<div style="color: white; width: 42px; display: inline-block">
					<!-- chevron-circle-right.svg + 'fill="currentColor"' -->
					<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><!-- Font Awesome Free 5.15.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) --><path fill="currentColor" d="M256 8c137 0 248 111 248 248S393 504 256 504 8 393 8 256 119 8 256 8zm113.9 231L234.4 103.5c-9.4-9.4-24.6-9.4-33.9 0l-17 17c-9.4 9.4-9.4 24.6 0 33.9L285.1 256 183.5 357.6c-9.4 9.4-9.4 24.6 0 33.9l17 17c9.4 9.4 24.6 9.4 33.9 0L369.9 273c9.4-9.4 9.4-24.6 0-34z"/></svg>
				</div>
			</a>
		</div>
		{#if playback_state === 'play' || playback_state === 'pause'}
		{#each playlist as track}
		{#if track.id === playback_songid}	
			<div class="title">{track.track.title}</div>
			<div class="artist">{track.track.artist}</div>
			<div class="time">
				<input id="progress" type="range"
					min="0"
					max="{track.track.duration}"
					value={playback_elapsed}
					on:change={(e) => {
						conn.sendCmd("seek", {"seconds": parseFloat(e.srcElement.value), "song": track.id})
					}}
				/>
				<div id="progresstxt">{duration(playback_elapsed)}/{duration(track.track.duration)}</div>
			</div>
		{/if}
		{/each}
		{/if}
	</div>
</div>
