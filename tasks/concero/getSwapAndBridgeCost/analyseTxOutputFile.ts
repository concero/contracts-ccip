import fs from "fs";
import { formatEther } from "viem";
import asciichart from "asciichart";

/**
 * Reads and parses the JSON file containing transaction records.
 * @param {string} filePath - The path to the JSON file.
 * @returns {Array<Object>} - An array of transaction records.
 */
function readRecords(filePath) {
  const data = fs.readFileSync(filePath, "utf8");
  const records = JSON.parse(data);
  return records;
}

/**
 * Computes various statistics from the transaction records.
 * @param {Array<Object>} records - The transaction records.
 * @returns {Object} - An object containing computed statistics.
 */
function computeStatistics(records) {
  let feeDifferences = [];
  let srcMessengerGasFeeTakenValues = [];
  let clfFeePaidValues = [];

  let totalPositiveFeeDifference = BigInt(0);
  let totalNegativeFeeDifference = BigInt(0);
  let countPositiveFeeDifference = 0;
  let countNegativeFeeDifference = 0;
  let totalFeeDifference = BigInt(0);

  let totalSrcFeePaid = BigInt(0);
  let totalDstFeePaid = BigInt(0);

  let highestSrcFeePaid = null;
  let lowestSrcFeePaid = null;

  let highestDstFeePaid = null;
  let lowestDstFeePaid = null;

  let highestFeeDifference = null;
  let lowestFeeDifference = null;

  let totalSrcClfFeeTaken = BigInt(0);
  let totalDstClfFeeTaken = BigInt(0);

  let highestSrcClfFeeTaken = null;
  let lowestSrcClfFeeTaken = null;

  let highestDstClfFeeTaken = null;
  let lowestDstClfFeeTaken = null;

  let totalSrcMessengerGasFeeTaken = BigInt(0);
  let totalDstMessengerGasFeeTaken = BigInt(0);

  records.forEach(record => {
    const feeDifference = BigInt(record.totalFeeDifference);
    totalFeeDifference += feeDifference;

    feeDifferences.push(Number(formatEther(feeDifference)));

    if (feeDifference >= BigInt(0)) {
      totalPositiveFeeDifference += feeDifference;
      countPositiveFeeDifference++;
    } else {
      totalNegativeFeeDifference += feeDifference;
      countNegativeFeeDifference++;
    }

    const srcFeePaid = BigInt(record.srcClfFeePaid);
    const dstFeePaid = BigInt(record.dstClfFeePaid);

    // Collect clfFeePaid (src + dst) for plotting
    const totalClfFeePaid = srcFeePaid + dstFeePaid;
    clfFeePaidValues.push(Number(formatEther(totalClfFeePaid)));

    totalSrcFeePaid += srcFeePaid;
    totalDstFeePaid += dstFeePaid;

    highestSrcFeePaid = highestSrcFeePaid === null || srcFeePaid > highestSrcFeePaid ? srcFeePaid : highestSrcFeePaid;
    lowestSrcFeePaid = lowestSrcFeePaid === null || srcFeePaid < lowestSrcFeePaid ? srcFeePaid : lowestSrcFeePaid;

    highestDstFeePaid = highestDstFeePaid === null || dstFeePaid > highestDstFeePaid ? dstFeePaid : highestDstFeePaid;
    lowestDstFeePaid = lowestDstFeePaid === null || dstFeePaid < lowestDstFeePaid ? dstFeePaid : lowestDstFeePaid;

    highestFeeDifference =
      highestFeeDifference === null || feeDifference > highestFeeDifference ? feeDifference : highestFeeDifference;
    lowestFeeDifference =
      lowestFeeDifference === null || feeDifference < lowestFeeDifference ? feeDifference : lowestFeeDifference;

    const srcClfFeeTaken = BigInt(record.srcClfFeeTaken);
    const dstClfFeeTaken = BigInt(record.dstClfFeeTaken);

    totalSrcClfFeeTaken += srcClfFeeTaken;
    totalDstClfFeeTaken += dstClfFeeTaken;

    highestSrcClfFeeTaken =
      highestSrcClfFeeTaken === null || srcClfFeeTaken > highestSrcClfFeeTaken ? srcClfFeeTaken : highestSrcClfFeeTaken;
    lowestSrcClfFeeTaken =
      lowestSrcClfFeeTaken === null || srcClfFeeTaken < lowestSrcClfFeeTaken ? srcClfFeeTaken : lowestSrcClfFeeTaken;

    highestDstClfFeeTaken =
      highestDstClfFeeTaken === null || dstClfFeeTaken > highestDstClfFeeTaken ? dstClfFeeTaken : highestDstClfFeeTaken;
    lowestDstClfFeeTaken =
      lowestDstClfFeeTaken === null || dstClfFeeTaken < lowestDstClfFeeTaken ? dstClfFeeTaken : lowestDstClfFeeTaken;

    const srcMessengerGasFeeTaken = BigInt(record.srcMessengerGasFeeTaken);
    srcMessengerGasFeeTakenValues.push(Number(formatEther(srcMessengerGasFeeTaken)));

    totalSrcMessengerGasFeeTaken += srcMessengerGasFeeTaken;
    totalDstMessengerGasFeeTaken += BigInt(record.dstMessengerGasFeeTaken);
  });

  const totalRecords = records.length;

  const averagePositiveFeeDifference =
    countPositiveFeeDifference > 0 ? totalPositiveFeeDifference / BigInt(countPositiveFeeDifference) : BigInt(0);
  const averageNegativeFeeDifference =
    countNegativeFeeDifference > 0 ? totalNegativeFeeDifference / BigInt(countNegativeFeeDifference) : BigInt(0);
  const averageFeeDifference = totalRecords > 0 ? totalFeeDifference / BigInt(totalRecords) : BigInt(0);

  const averageSrcFeePaid = totalRecords > 0 ? totalSrcFeePaid / BigInt(totalRecords) : BigInt(0);
  const averageDstFeePaid = totalRecords > 0 ? totalDstFeePaid / BigInt(totalRecords) : BigInt(0);

  const averageSrcClfFeeTaken = totalRecords > 0 ? totalSrcClfFeeTaken / BigInt(totalRecords) : BigInt(0);
  const averageDstClfFeeTaken = totalRecords > 0 ? totalDstClfFeeTaken / BigInt(totalRecords) : BigInt(0);

  const averageSrcMessengerGasFeeTaken =
    totalRecords > 0 ? totalSrcMessengerGasFeeTaken / BigInt(totalRecords) : BigInt(0);
  const averageDstMessengerGasFeeTaken =
    totalRecords > 0 ? totalDstMessengerGasFeeTaken / BigInt(totalRecords) : BigInt(0);

  const percentagePositiveFeeDifferences = (countPositiveFeeDifference / totalRecords) * 100;
  const percentageNegativeFeeDifferences = (countNegativeFeeDifference / totalRecords) * 100;

  // Difference between highest and lowest clfFeePaid (src and dst)
  const differenceSrcClfFeePaid = highestSrcFeePaid - lowestSrcFeePaid;
  const differenceDstClfFeePaid = highestDstFeePaid - lowestDstFeePaid;

  return {
    feeDifferences,
    srcMessengerGasFeeTakenValues,
    clfFeePaidValues,
    totalPositiveFeeDifference,
    totalNegativeFeeDifference,
    countPositiveFeeDifference,
    countNegativeFeeDifference,
    totalFeeDifference,
    totalSrcFeePaid,
    totalDstFeePaid,
    highestSrcFeePaid,
    lowestSrcFeePaid,
    highestDstFeePaid,
    lowestDstFeePaid,
    differenceSrcClfFeePaid,
    differenceDstClfFeePaid,
    highestFeeDifference,
    lowestFeeDifference,
    totalSrcClfFeeTaken,
    totalDstClfFeeTaken,
    highestSrcClfFeeTaken,
    lowestSrcClfFeeTaken,
    highestDstClfFeeTaken,
    lowestDstClfFeeTaken,
    totalSrcMessengerGasFeeTaken,
    totalDstMessengerGasFeeTaken,
    totalRecords,
    averagePositiveFeeDifference,
    averageNegativeFeeDifference,
    averageFeeDifference,
    averageSrcFeePaid,
    averageDstFeePaid,
    averageSrcClfFeeTaken,
    averageDstClfFeeTaken,
    averageSrcMessengerGasFeeTaken,
    averageDstMessengerGasFeeTaken,
    percentagePositiveFeeDifferences,
    percentageNegativeFeeDifferences,
  };
}

/**
 * Prepares the data for table output, grouped by categories.
 * @param {Object} stats - The computed statistics.
 * @returns {Object} - An object containing arrays of table data for each category.
 */
function prepareTableData(stats) {
  const overviewData = [
    { Metric: "Total records", Value: stats.totalRecords },
    { Metric: "Positive feeDifferences", Value: stats.countPositiveFeeDifference },
    { Metric: "Negative feeDifferences", Value: stats.countNegativeFeeDifference },
    {
      Metric: "Percentage Positive feeDifferences",
      Value: stats.percentagePositiveFeeDifferences.toFixed(2) + "%",
    },
    {
      Metric: "Percentage Negative feeDifferences",
      Value: stats.percentageNegativeFeeDifferences.toFixed(2) + "%",
    },
  ];

  const feeDifferenceData = [
    {
      Metric: "Average positive feeDifference",
      Value: formatEther(stats.averagePositiveFeeDifference),
    },
    {
      Metric: "Average negative feeDifference",
      Value: formatEther(stats.averageNegativeFeeDifference),
    },
    {
      Metric: "Average feeDifference",
      Value: formatEther(stats.averageFeeDifference),
    },
    { Metric: "Total fee difference", Value: formatEther(stats.totalFeeDifference) },
    {
      Metric: "Highest feeDifference",
      Value: stats.highestFeeDifference !== null ? formatEther(stats.highestFeeDifference) : "N/A",
    },
    {
      Metric: "Lowest feeDifference",
      Value: stats.lowestFeeDifference !== null ? formatEther(stats.lowestFeeDifference) : "N/A",
    },
  ];

  const feePaidData = [
    { Metric: "Total clfFeePaid", Value: formatEther(stats.totalSrcFeePaid + stats.totalDstFeePaid) },
    { Metric: "Average srcClfFeePaid", Value: formatEther(stats.averageSrcFeePaid) },
    { Metric: "Average dstClfFeePaid", Value: formatEther(stats.averageDstFeePaid) },
    {
      Metric: "Highest srcClfFeePaid",
      Value: stats.highestSrcFeePaid !== null ? formatEther(stats.highestSrcFeePaid) : "N/A",
    },
    {
      Metric: "Lowest srcClfFeePaid",
      Value: stats.lowestSrcFeePaid !== null ? formatEther(stats.lowestSrcFeePaid) : "N/A",
    },
    {
      Metric: "Difference between highest and lowest srcClfFeePaid",
      Value: formatEther(stats.differenceSrcClfFeePaid),
    },
    {
      Metric: "Highest dstClfFeePaid",
      Value: stats.highestDstFeePaid !== null ? formatEther(stats.highestDstFeePaid) : "N/A",
    },
    {
      Metric: "Lowest dstClfFeePaid",
      Value: stats.lowestDstFeePaid !== null ? formatEther(stats.lowestDstFeePaid) : "N/A",
    },
    {
      Metric: "Difference between highest and lowest dstClfFeePaid",
      Value: formatEther(stats.differenceDstClfFeePaid),
    },
  ];

  const feeTakenData = [
    {
      Metric: "Average srcClfFeeTaken",
      Value: formatEther(stats.averageSrcClfFeeTaken),
    },
    {
      Metric: "Average dstClfFeeTaken",
      Value: formatEther(stats.averageDstClfFeeTaken),
    },
    {
      Metric: "Highest srcClfFeeTaken",
      Value: stats.highestSrcClfFeeTaken !== null ? formatEther(stats.highestSrcClfFeeTaken) : "N/A",
    },
    {
      Metric: "Lowest srcClfFeeTaken",
      Value: stats.lowestSrcClfFeeTaken !== null ? formatEther(stats.lowestSrcClfFeeTaken) : "N/A",
    },
    {
      Metric: "Highest dstClfFeeTaken",
      Value: stats.highestDstClfFeeTaken !== null ? formatEther(stats.highestDstClfFeeTaken) : "N/A",
    },
    {
      Metric: "Lowest dstClfFeeTaken",
      Value: stats.lowestDstClfFeeTaken !== null ? formatEther(stats.lowestDstClfFeeTaken) : "N/A",
    },
    {
      Metric: "Average srcMessengerGasFeeTaken",
      Value: formatEther(stats.averageSrcMessengerGasFeeTaken),
    },
    {
      Metric: "Average dstMessengerGasFeeTaken",
      Value: formatEther(stats.averageDstMessengerGasFeeTaken),
    },
  ];

  return {
    overviewData,
    feeDifferenceData,
    feePaidData,
    feeTakenData,
  };
}

/**
 * Downsamples the data array for plotting.
 * @param {Array<number>} data - The data array to downsample.
 * @param {number} maxPoints - The maximum number of points to plot.
 * @returns {Array<number>} - The downsampled data array.
 */
function downsampleData(data, maxPoints) {
  const totalRecords = data.length;
  if (totalRecords <= maxPoints) {
    return data;
  }

  const binSize = Math.floor(totalRecords / maxPoints);
  const sampledData = [];

  for (let i = 0; i < totalRecords; i += binSize) {
    const binValues = data.slice(i, i + binSize);
    const binAverage = binValues.reduce((sum, val) => sum + val, 0) / binValues.length;
    sampledData.push(binAverage);
  }

  return sampledData;
}

/**
 * Plots the fee difference chart.
 * @param {Array<number>} data - The fee difference data to plot.
 */
function plotChart(data) {
  console.log("\nFee Difference (Downsampled):\n");
  const config = {
    height: 24,
    colors: [asciichart.blue],
    format: function (x, i) {
      return x.toFixed(6);
    },
  };
  console.log(asciichart.plot(data, config));
}

/**
 * Analyzes the transaction output file and displays analytics.
 * @param {string} filePath - The path to the JSON file.
 * @param {number} maxChartPoints - Maximum points to plot on the chart.
 */
export function analyseTxOutputFile(filePath, maxChartPoints = 180) {
  const records = readRecords(filePath);
  const stats = computeStatistics(records);
  const { overviewData, feeDifferenceData, feePaidData, feeTakenData } = prepareTableData(stats);
  const sampledFeeDifferences = downsampleData(stats.feeDifferences, maxChartPoints);
  console.log("\n=== Overview ===");
  console.table(overviewData);

  console.log("\n=== Fee Differences ===");
  console.table(feeDifferenceData);

  console.log("\n=== Fees Paid ===");
  console.table(feePaidData);

  console.log("\n=== Fees Taken ===");
  console.table(feeTakenData);

  plotChart(sampledFeeDifferences);
}
