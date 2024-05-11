try {
	const script = secrets.test;
	const res = eval(script);
	return res;
} catch (error) {
	console.log(error);
	return Functions.encodeString(error);
}
