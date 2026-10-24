// Script de despliegue completo del sistema de gobernanza.
// Orden: Token -> Timelock -> Governor -> configuración de roles -> traspaso de propiedad.

const { ethers } = require("hardhat");

async function main() {
  // La primera cuenta configurada en la red es quien despliega (deployer).
  const [deployer] = await ethers.getSigners();
  console.log("Desplegando con la cuenta:", deployer.address);

  // ---------------------------------------------------------------
  // 1) TOKEN: suministro inicial de 1.000.000 GOV (18 decimales) al deployer.
  // ---------------------------------------------------------------
  const supplyInicial = ethers.parseEther("1000000");
  const token = await ethers.deployContract("GovToken", [deployer.address, supplyInicial]);
  await token.waitForDeployment();
  console.log("GovToken:      ", await token.getAddress());

  // ---------------------------------------------------------------
  // 2) TIMELOCK: retardo mínimo de 1 hora (3600 s) entre encolar y ejecutar.
  //    Proposers y executors vacíos: se asignan después. Admin = deployer (temporal).
  //    En producción usá un retardo mayor (ej. 2 días = 172800).
  // ---------------------------------------------------------------
  const minDelay = 3600;
  const timelock = await ethers.deployContract("GovTimelock", [minDelay, [], [], deployer.address]);
  await timelock.waitForDeployment();
  console.log("GovTimelock:   ", await timelock.getAddress());

  // ---------------------------------------------------------------
  // 3) GOVERNOR: recibe la dirección del token (votos) y del timelock (ejecución).
  // ---------------------------------------------------------------
  const governor = await ethers.deployContract("MyGovernor", [
    await token.getAddress(),
    await timelock.getAddress(),
  ]);
  await governor.waitForDeployment();
  console.log("MyGovernor:    ", await governor.getAddress());

  // ---------------------------------------------------------------
  // 4) ROLES DEL TIMELOCK
  // ---------------------------------------------------------------
  const PROPOSER_ROLE = await timelock.PROPOSER_ROLE();
  const EXECUTOR_ROLE = await timelock.EXECUTOR_ROLE();
  const CANCELLER_ROLE = await timelock.CANCELLER_ROLE();
  const ADMIN_ROLE = await timelock.DEFAULT_ADMIN_ROLE();

  // Solo el Governor puede encolar y cancelar operaciones.
  await (await timelock.grantRole(PROPOSER_ROLE, await governor.getAddress())).wait();
  await (await timelock.grantRole(CANCELLER_ROLE, await governor.getAddress())).wait();
  // address(0) como executor = cualquiera puede ejecutar una propuesta ya madura.
  await (await timelock.grantRole(EXECUTOR_ROLE, ethers.ZeroAddress)).wait();
  // El deployer renuncia al rol admin: desde ahora SOLO la gobernanza puede cambiar roles.
  await (await timelock.renounceRole(ADMIN_ROLE, deployer.address)).wait();

  // ---------------------------------------------------------------
  // 5) PROPIEDAD DEL TOKEN -> TIMELOCK
  //    Así acuñar nuevos tokens (mint) requiere una propuesta aprobada.
  // ---------------------------------------------------------------
  await (await token.transferOwnership(await timelock.getAddress())).wait();

  console.log("\nListo. Recordá: cada holder debe llamar token.delegate(suDireccion) para activar sus votos.");
}

// Punto de entrada con manejo de errores: sale con código 1 si algo falla.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
