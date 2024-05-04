import ora from "ora";

function spin(config = {}) {
  const spinner = ora({ spinner: "dots2", ...config });
  spinner.start();
  return spinner;
}

export default spin;
