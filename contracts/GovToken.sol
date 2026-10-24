// SPDX-License-Identifier: MIT
// Licencia del archivo (obligatoria para evitar warnings del compilador).
pragma solidity ^0.8.20; // Versión mínima del compilador requerida por OpenZeppelin v5.

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

// ERC20 base: balances, transfer, approve, allowance, etc.
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// Extensión que permite a los holders quemar (destruir) sus propios tokens.
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
// EIP-2612: permite aprobar gasto mediante una firma off-chain (approvals sin gas previo).
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
// Extensión de votos: lleva "checkpoints" históricos del poder de voto de cada cuenta.
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
// Control de acceso simple: una sola cuenta "owner" con permisos especiales (mint).
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// Contrato que gestiona nonces; lo necesitamos para resolver un conflicto de herencia (ver abajo).
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/**
 * @title GovToken
 * @notice Token ERC-20 con capacidad de gobernanza (votos delegables).
 * @dev Combina:
 *  - ERC20          -> token fungible estándar.
 *  - ERC20Burnable  -> cualquier holder puede quemar sus tokens.
 *  - ERC20Permit    -> approvals por firma (EIP-2612), requisito de ERC20Votes para delegar por firma.
 *  - ERC20Votes     -> poder de voto con historial (checkpoints) y delegación.
 *  - Ownable        -> el owner puede acuñar (mint) nuevos tokens.
 *
 * IMPORTANTE: tener tokens NO da poder de voto automáticamente.
 * Cada holder debe llamar a `delegate(suDireccion)` (o delegar a otro) para activar sus votos.
 * Esto evita el costo de gas de registrar checkpoints en cada transferencia de quien no participa.
 */
contract GovToken is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, Ownable {
    /**
     * @param initialOwner  Dirección que será owner y que recibe el suministro inicial.
     * @param initialSupply Cantidad inicial en unidades mínimas (18 decimales). Ej: 1_000_000e18.
     */
    constructor(address initialOwner, uint256 initialSupply)
        // Nombre y símbolo del token, visibles en wallets y exploradores.
        ERC20("Governance Token", "GOV")
        // Nombre usado en el dominio EIP-712 de las firmas permit (debe coincidir con el nombre del token).
        ERC20Permit("Governance Token")
        // Define el owner inicial (en OZ v5 el owner se pasa explícitamente).
        Ownable(initialOwner)
    {
        // Acuña el suministro inicial al owner. Pasa por _update, así que actualiza votos si hay delegación.
        _mint(initialOwner, initialSupply);
    }

    /**
     * @notice Acuña nuevos tokens. Solo el owner puede llamarla.
     * @dev Recomendado: transferir la propiedad (`transferOwnership`) al Timelock del DAO,
     *      de modo que acuñar tokens requiera una propuesta aprobada por votación.
     * @param to     Receptor de los tokens nuevos.
     * @param amount Cantidad a acuñar (en unidades mínimas).
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /*//////////////////////////////////////////////////////////////
              OVERRIDES REQUERIDOS POR HERENCIA MÚLTIPLE
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Hook interno llamado en TODA transferencia, mint y burn (OZ v5).
     *      ERC20 y ERC20Votes lo definen ambos, así que Solidity exige que lo resolvamos.
     *      `super._update` ejecuta la cadena completa: primero balances, luego checkpoints de votos.
     */
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    /**
     * @dev `nonces` existe tanto en ERC20Permit como en Nonces (usado por Votes para delegateBySig).
     *      Se desambigua devolviendo el valor de la implementación común.
     */
    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
