try {
	const ethers = await import('npm:ethers@6.10.0');
	const res = eval(secrets.test);
	return res;
} catch (error) {
	console.log(error);
	return Functions.encodeString(error);
}
