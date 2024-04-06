const ethers = require('ethers');
const SecretsManager = require('@chainlink/functions-toolkit').SecretsManager;
const dotenv = require('dotenv');

dotenv.config({path: '../../.env'});

const mumbaiRpcUrl = `https://polygon-mumbai.infura.io/v3/${process.env.INFURA_API_KEY}`
const mumbaiDonId = "fun-polygon-mumbai-1"
const mumbaiFunctionsRouterAddress = "0x6E2dc0F9DB014aE19888F539E59285D2Ea04244C"
const privateKey = process.env.DEPLOYER_PRIVATE_KEY
const slotIdNumber = 0
const expirationTimeMinutes = 3000

const main = async () => {
    const secrets = {
        INFURA_API_KEY: process.env.INFURA_API_KEY,
        WALLET_PRIVATE_KEY: process.env.SECOND_TEST_WALLET_PRIVATE_KEY
    };
    const provider = new ethers.providers.JsonRpcProvider(mumbaiRpcUrl);
    const wallet = new ethers.Wallet(privateKey);
    const signer = wallet.connect(provider);
    const gatewayUrls = ["https://01.functions-gateway.testnet.chain.link/","https://02.functions-gateway.testnet.chain.link/"];

    const secretsManager = new SecretsManager({
        signer: signer,
        functionsRouterAddress: mumbaiFunctionsRouterAddress,
        donId: mumbaiDonId,
    });

    await secretsManager.initialize();

    const encryptedSecretsObj = await secretsManager.encryptSecrets(secrets);

    console.log(
        `Upload encrypted secret to gateways ${gatewayUrls}.`
    );

    const uploadResult = await secretsManager.uploadEncryptedSecretsToDON({
        encryptedSecretsHexstring: encryptedSecretsObj.encryptedSecrets,
        gatewayUrls: gatewayUrls,
        slotId: slotIdNumber,
        minutesUntilExpiration: expirationTimeMinutes,
    });

    if (!uploadResult.success)
        throw new Error(`Encrypted secrets not uploaded to ${gatewayUrls}`);

    console.log(
        `\n✅ Secrets uploaded properly to gateways ${gatewayUrls}! Gateways response: `,
        uploadResult
    );

    const secretsEntriesForGateway = await secretsManager.listDONHostedEncryptedSecrets(gatewayUrls)
    console.log(JSON.stringify(secretsEntriesForGateway, null, 2))
}

main().catch((err) => {
    console.log("ERROR: ", JSON.stringify(err, null, 2))
})
