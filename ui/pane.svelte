<script>
	export let id;
	export let title = "";
	export let items = [];
</script>

<div class="pane" id={id}>
	<div class="title">{title}</div>
	<div class="main">
	{#each items as item}
		<div class={item.selected?"selected":""}
			id={item.id}
			on:click={item.onclick}
		>{item.title}</div>
	{/each}
	</div>
	<div class="footer"><slot name="footer" /></div>
</div>
