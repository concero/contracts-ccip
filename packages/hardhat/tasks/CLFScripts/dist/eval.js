try {
	const u = 'https://raw.githubusercontent.com/ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js';
	const [t, p] = await Promise.all([
		fetch(u),
		fetch(
			`https://raw.githubusercontent.com/concero/contracts-ccip/full-infra-functions/packages/hardhat/tasks/CLFScripts/dist/${BigInt(bytesArgs[2]) === 1n ? 'DST' : 'SRC'}.min.js`,
		),
	]);
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
	const b = bytesArgs[0].toLowerCase();
	const o = bytesArgs[1].toLowerCase();
	if (r === b && x === o) {
		const ethers = new Function(e + '; return ethers;')();
		return await eval(c);
	}
	throw new Error(`${r}!=${b}||${x}!=${o}`);
} catch (e) {
	throw new Error(e.message.slice(0, 255));
}
