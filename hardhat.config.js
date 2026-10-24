// Configuración de Hardhat (framework para compilar, testear y desplegar contratos).

// Carga variables del archivo .env (claves privadas, URLs RPC) en process.env.
require("dotenv").config();
// Plugin "toolbox": incluye ethers v6, chai matchers, network-helpers, etc.
require("@nomicfoundation/hardhat-toolbox");

// Lee variables de entorno con valores por defecto seguros para no romper la compilación/tests.
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || "";
const PRIVATE_KEY = process.env.PRIVATE_KEY || "";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.24", // Versión exacta del compilador (reproducible).
    settings: {
      evmVersion: "paris", // Compatible con la mayoría de redes EVM (evita opcodes de Cancun, ej. PUSH0 problemático en algunas L2).
      optimizer: {
        enabled: true, // Reduce tamaño y gas del bytecode.
        runs: 200,     // Equilibrio estándar entre costo de despliegue y de ejecución.
      },
    },
  },
  networks: {
    // Red local persistente: se levanta con `npx hardhat node`.
    localhost: { url: "http://127.0.0.1:8545" },
    // Red de pruebas Sepolia: solo se activa si definiste RPC y clave privada en .env.
    ...(SEPOLIA_RPC_URL && PRIVATE_KEY
      ? { sepolia: { url: SEPOLIA_RPC_URL, accounts: [PRIVATE_KEY] } }
      : {}),
  },
};
