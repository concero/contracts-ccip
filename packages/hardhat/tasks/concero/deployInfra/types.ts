import { CNetwork } from "../../../types/CNetwork";
import { NetworkType } from "../../../constants/CNetworks";

export interface DeployInfraParams {
  hre: any;
  liveChains: CNetwork[];
  deployableChains: CNetwork[];
  networkType: NetworkType;
  deployProxy: boolean;
  deployImplementation: boolean;
  setVars: boolean;
  uploadSecrets: boolean;
  slotId: number;
}
