import { getEnvVar } from "../utils/getEnvVar";

export const messengers: string[] = [getEnvVar("MESSENGER_0_ADDRESS"), getEnvVar("MESSENGER_1_ADDRESS"), getEnvVar("MESSENGER_2_ADDRESS")];
// The address is the same on 4 chains: ARB,POL,BASE,AVAX. Can be deployed to others later using Lifi's Create3 Factory.
export const initialProxyImplementationAddress = getEnvVar("CONCERO_PAUSE_ARBITRUM");
