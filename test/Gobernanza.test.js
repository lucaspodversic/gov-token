// Tests del sistema: token, delegación y ciclo completo de una propuesta.

const { expect } = require("chai");
const { ethers } = require("hardhat");
// Helpers de Hardhat para avanzar bloques y tiempo en la red de pruebas.
const { mine, time } = require("@nomicfoundation/hardhat-network-helpers");

describe("GovToken + MyGovernor + Timelock", function () {
  // Prepara un entorno limpio y completo para cada test.
  async function desplegar() {
    const [owner, votante, receptor] = await ethers.getSigners();
    const supply = ethers.parseEther("1000000");

    const token = await ethers.deployContract("GovToken", [owner.address, supply]);
    const timelock = await ethers.deployContract("GovTimelock", [3600, [], [], owner.address]);
    const governor = await ethers.deployContract("MyGovernor", [
      await token.getAddress(),
      await timelock.getAddress(),
    ]);

    // Configuración de roles (igual que en scripts/deploy.js).
    await timelock.grantRole(await timelock.PROPOSER_ROLE(), await governor.getAddress());
    await timelock.grantRole(await timelock.CANCELLER_ROLE(), await governor.getAddress());
    await timelock.grantRole(await timelock.EXECUTOR_ROLE(), ethers.ZeroAddress);
    await timelock.renounceRole(await timelock.DEFAULT_ADMIN_ROLE(), owner.address);

    // El Timelock pasa a ser dueño del token (mint solo por gobernanza).
    await token.transferOwnership(await timelock.getAddress());

    return { token, timelock, governor, owner, votante, receptor, supply };
  }

  it("asigna el suministro inicial al owner", async function () {
    const { token, owner, supply } = await desplegar();
    expect(await token.balanceOf(owner.address)).to.equal(supply);
    expect(await token.symbol()).to.equal("GOV");
  });

  it("no da poder de voto hasta delegar", async function () {
    const { token, owner } = await desplegar();
    expect(await token.getVotes(owner.address)).to.equal(0n);
    await token.delegate(owner.address); // Auto-delegación.
    expect(await token.getVotes(owner.address)).to.equal(await token.balanceOf(owner.address));
  });

  it("solo el owner (Timelock) puede acuñar directamente", async function () {
    const { token, votante } = await desplegar();
    await expect(token.connect(votante).mint(votante.address, 1n)).to.be.reverted;
  });

  it("ejecuta el ciclo completo: proponer, votar, encolar y ejecutar un mint", async function () {
    const { token, governor, owner, receptor } = await desplegar();

    // 1) Activar votos del owner.
    await token.delegate(owner.address);
    await mine(1);

    // 2) Definir la propuesta: acuñar 500 GOV al receptor (lo ejecutará el Timelock).
    const monto = ethers.parseEther("500");
    const targets = [await token.getAddress()];
    const values = [0n];
    const calldatas = [token.interface.encodeFunctionData("mint", [receptor.address, monto])];
    const descripcion = "Propuesta #1: acuñar 500 GOV al receptor";
    const descHash = ethers.id(descripcion);

    await governor.propose(targets, values, calldatas, descripcion);
    const id = await governor.hashProposal(targets, values, calldatas, descHash);

    // 3) Esperar el votingDelay (7200 bloques) y votar a favor (1 = A favor).
    await mine(7201);
    await governor.castVote(id, 1);

    // 4) Esperar el votingPeriod (50400 bloques); la propuesta debe quedar Succeeded (4).
    await mine(50401);
    expect(await governor.state(id)).to.equal(4n);

    // 5) Encolar en el Timelock, esperar su retardo (1 hora) y ejecutar.
    await governor.queue(targets, values, calldatas, descHash);
    await time.increase(3601);
    await governor.execute(targets, values, calldatas, descHash);

    // 6) Verificar el efecto: el receptor recibió los tokens y la propuesta está Executed (7).
    expect(await token.balanceOf(receptor.address)).to.equal(monto);
    expect(await governor.state(id)).to.equal(7n);
  });
});
