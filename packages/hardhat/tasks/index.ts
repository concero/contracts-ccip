import * as concero from "./concero";
import * as clf from "./CLF";
import * as clfScripts from "./CLFScripts";
import deleteDepositsOTWIds from "./concero/deleteDepositsOTWIds";

export default {
  ...concero,
  ...clf,
  ...clfScripts,
  deleteDepositsOTWIds,
};
