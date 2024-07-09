import load from '../../../../utils/load';
try {
	const u = 'https://raw.githubusercontent.com/ethers-io/ethers.js/v6.10.0/dist/ethers.umd.min.js';
	const [t, p] = await Promise.all([fetch(u), load('./dist/SRC.min.js')]);
	console.log(p);
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
	const ethers = new Function(e + '; return ethers;')();
	return await eval(c);
} catch (e) {
	throw new Error(e.message.slice(0, 255));
}
