import readResultAndError from "./readResultAndError";
import requestData from "./request";
import deployConsumer from "./deployConsumer";
import deployAutoConsumer from "./deployAutoConsumer";
import setDonId from "./setDonId";
import buildOffchainSecrets from "./buildOffchainSecrets";
import checkUpkeep from "./checkUpkeep";
import performUpkeep from "./performManualUpkeep";
import setAutoRequest from "./setAutoRequest";
import uploadSecretsToDon from "./uploadSecretsToDon";
import listDonSecrets from "./listDonSecrets";

export default {
  readResultAndError,
  requestData,
  deployConsumer,
  deployAutoConsumer,
  setDonId,
  buildOffchainSecrets,
  checkUpkeep,
  performUpkeep,
  setAutoRequest,
  uploadSecretsToDon,
  listDonSecrets,
};
