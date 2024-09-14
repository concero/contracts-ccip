try {
	const [b, o, f] = bytesArgs[2];
	const u = 'https://raw.githubusercontent.com/ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js';
	const q =
		'https://raw.githubusercontent.com/concero/contracts-ccip/' +
		'${CLF_JS_CODE_BRANCH}' +
		`/packages/hardhat/tasks/CLFScripts/dist/pool/${f === '0x2' ? 'collectLiquidity' : f === '0x1' ? 'distributeLiquidity' : 'getTotalBalance'}.min.js`;
	const [t, p] = await Promise.all([fetch(u), fetch(q)]);
	const [e, c] = await Promise.all([t.text(), p.text()]);
	const g = async s => {
		return (
			'0x' +
			Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s))))
				.map(v => ('0' + v.toString(16)).slice(-2).toLowerCase())
				.join('')
		);
	};
	const r = await g(c);
	const x = await g(e);
	if (r === b.toLowerCase() && x === o.toLowerCase()) {
		const ethers = new Function(e + '; return ethers;')();
		return await eval(c);
	}
	throw new Error(`${r}!=${b}||${x}!=${o}`);
} catch (e) {
	throw new Error(e.message.slice(0, 255));
}
