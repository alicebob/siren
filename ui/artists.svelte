<script>
	import Pane from './pane.svelte';
	import Endpane from './endpane.svelte';

	export let artists = [];
	export let conn = undefined;
</script>

<div class="mc">
	{#each artists as pane}
		{#if pane.endpane}
			<Endpane id={pane.id} content={pane.html} end={pane.endpane}>
				<div slot="footer">
					<button on:click={() => pane.play(conn)}>PLAY</button>
				</div>
			</Endpane>
		{:else}
			<Pane id={pane.id} title={pane.title} onclick={pane.onclick} items={pane.items}>
				<div slot="footer">
					{#if pane.playlist}
					<button class="add" on:click={() => {
							pane.addtoplaylist(conn);
					}}>ADD TO PLAYLIST</button>
					<button class="play" on:click={() => {
							conn.sendCmd("clear");
							pane.addtoplaylist(conn);
							conn.sendCmd("play");
					}}>PLAY</button>
					{/if}
				</div>
			</Pane>
		{/if}
	{/each}
</div>
