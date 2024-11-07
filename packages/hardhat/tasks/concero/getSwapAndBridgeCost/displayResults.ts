import { formatEther } from "viem";

export function displayResults({
  srcClfFee,
  dstClfFee,
  totalCostJuels,
  dstRequestProcessedArgs,
  srcMessengerGasFee,
  dstMessengerGasFee,
  gasPaid,
}) {
  const fees = [
    {
      feeType: "clfFee_src",
      feeTaken: formatEther(srcClfFee),
      feePaid: formatEther(totalCostJuels),
      feeDifference: formatEther(BigInt(srcClfFee) - BigInt(totalCostJuels)),
    },
    {
      feeType: "clfFee_dst",
      feeTaken: formatEther(dstClfFee),
      feePaid: formatEther(dstRequestProcessedArgs.totalCostJuels),
      feeDifference: formatEther(BigInt(dstClfFee) - BigInt(dstRequestProcessedArgs.totalCostJuels)),
    },
    {
      feeType: "messageGas_dst",
      feeTaken: formatEther(dstMessengerGasFee),
      feePaid: formatEther(gasPaid),
      feeDifference: formatEther(BigInt(dstMessengerGasFee) - BigInt(gasPaid)),
    },
    {
      feeType: "messageGas_src",
      feeTaken: formatEther(srcMessengerGasFee),
      feePaid: "N/A",
      feeDifference: "N/A",
    },
  ];

  console.table(fees);
}
