try {
	await import('npm:ethers@6.10.0');
	const crypto = await import('node:crypto');
	const hash = crypto.createHash('sha256').update(secrets.SRC_JS, 'utf8').digest('hex');
	if ('0x' + hash.toLowerCase() === bytesArgs[0].toLowerCase()) {
		return await eval(secrets.SRC_JS);
	} else {
		throw new Error(`0x${hash.toLowerCase()} != ${bytesArgs[0].toLowerCase()}`);
	}
} catch (err) {
	throw new Error(err.message.slice(0, 255));
}
