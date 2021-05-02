<script>
	export const id = '';
	export let content = "loading...";
</script>

<div class="endpane">
	<div class="main">
		{@html content}
	</div>
	<div class="footer"><slot name="footer" /></div>
</div>
