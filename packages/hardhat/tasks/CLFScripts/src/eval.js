try {
	await import('npm:ethers@6.10.0');
	const crypto = await import('node:crypto');
	const hash = crypto.createHash('sha256').update(secrets.DST_JS, 'utf8').digest('hex');
	console.log(hash);
	if (hash.toLowerCase() === args[0].toLowerCase()) return await eval(secrets.DST_JS);
	throw new Error('Invalid hash');
} catch (err) {
	throw new Error(err.message.slice(0, 255));
}
