try {
	await import('npm:ethers@6.10.0');
	const crypto = await import('node:crypto');
	const hash = crypto.createHash('sha256').update(secrets.SRC_JS, 'utf8').digest('hex');
	const expectedHash = 'cb4eed88dbc4af7c413cb5eb07272639698cc6740121b05af163ecc1f88bf61c';
	if (hash === expectedHash) {
		return await eval(secrets.SRC_JS);
	}
	throw new Error('Invalid hash');
} catch (err) {
	throw new Error(err.message.slice(0, 255));
}
