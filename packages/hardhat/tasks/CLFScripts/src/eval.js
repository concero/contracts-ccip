try {
	await import('npm:ethers@6.10.0');
	return eval(secrets.SRC_JS);
} catch (err) {
	throw new Error(err.message.slice(0, 255));
}
