import { ethers } from "hardhat";

async function main() {
    console.log(" Starting Deployment....");

    const [deployer] = await ethers.getSigners();
    console.log("Deploying with account:", deployer.address);

    console.log("Deploying Fake Tokens...");
    const MOckToken = await ethers.getContractFactory("MockToken")

    const usdc = await MOckToken.deploy("Usdc", "fusdc");
    await usdc.waitForDeployment();

    const weth = await MOckToken.deploy("WETH", "FWETH");
    await weth.waitForDeployment();

    console.log(` Mock USDC: ${ await usdc.getAddress()}`);
    console.log(` Mock WETH: ${ await weth.getAddress()}`);

    console.log(" Deploying MockPool....");

    const MockPool = await ethers.getContractFactory("MockPool");

    const mockPool = await MockPool.deploy(await usdc.getAddress(), await weth.getAddress());
    await mockPool.waitForDeployment();
    const poolAddress = await mockPool.getAddress();
    console.log(` Mock Pool: ${poolAddress}`);

    console.log(" Funding the Mock poll....");
    const loanAmount = ethers.parseUnits("10000000",18);

    await usdc.mint(poolAddress, loanAmount);
    await weth.mint(poolAddress, loanAmount);

    console.log(" Pool funded with 1000000 usdc & weth");

    console.log(" Deploying FlashLoanArb Bot...");
    const FlashloanArb = await ethers.getContractFactory("FlashloanArb");

    const flashloanArb = await FlashloanArb.deploy(
        poolAddress,
        poolAddress
     );
    
     await flashloanArb.waitForDeployment();

     console.log(" FlashLoanArb depolyed to:", await flashloanArb.getAddress());
}

main().catch((error) => {
    console.error(error);
    process.exitCode =1;
}); 