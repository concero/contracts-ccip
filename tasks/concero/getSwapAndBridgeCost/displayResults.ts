import { formatEther } from "viem";

export function displayResults({
  srcClfFeeTaken,
  dstClfFeeTaken,
  srcClfFeePaid,
  dstClfFeePaid,
  srcMessengerGasFeeTaken,
  dstMessengerGasFeeTaken,
  dstGasPaid,
}) {
  const fees = [
    {
      feeType: "clfFee_src",
      feeTaken: formatEther(srcClfFeeTaken),
      feePaid: formatEther(srcClfFeePaid),
      feeDifference: formatEther(BigInt(srcClfFeeTaken) - BigInt(srcClfFeePaid)),
    },
    {
      feeType: "clfFee_dst",
      feeTaken: formatEther(dstClfFeeTaken),
      feePaid: formatEther(dstClfFeePaid),
      feeDifference: formatEther(BigInt(dstClfFeeTaken) - BigInt(dstClfFeePaid)),
    },
    {
      feeType: "messageGas_dst",
      feeTaken: formatEther(dstMessengerGasFeeTaken),
      feePaid: formatEther(dstGasPaid),
      feeDifference: formatEther(BigInt(dstMessengerGasFeeTaken) - BigInt(dstGasPaid)),
    },
    {
      feeType: "messageGas_src",
      feeTaken: formatEther(srcMessengerGasFeeTaken),
      feePaid: "N/A",
      feeDifference: "N/A",
    },
  ];

  console.table(fees);
}
