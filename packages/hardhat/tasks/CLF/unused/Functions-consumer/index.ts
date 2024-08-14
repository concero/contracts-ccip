import readResultAndError from "./readResultAndError";
import request from "./request";
import deployConsumer from "./deployConsumer";
import deployAutoConsumer from "./deployAutoConsumer";
import setDonId from "./setDonId";
import buildOffchainSecrets from "./buildOffchainSecrets";
import checkUpkeep from "./checkUpkeep";
import performUpkeep from "./performManualUpkeep";
import setAutoRequest from "./setAutoRequest";
import uploadSecretsToDon from "../../donSecrets/upload";
import listDonSecrets from "../../donSecrets/list";

export default {
  readResultAndError,
  request,
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
