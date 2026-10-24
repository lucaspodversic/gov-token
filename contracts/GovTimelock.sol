// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// TimelockController de OpenZeppelin: cola de operaciones con retardo mínimo obligatorio.
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title GovTimelock
 * @notice Timelock del DAO: es quien REALMENTE ejecuta las propuestas aprobadas.
 * @dev Flujo: Governor (aprueba) -> Timelock (espera `minDelay`) -> ejecución del llamado.
 *      El retardo da tiempo a la comunidad para reaccionar (p. ej. salir del protocolo)
 *      si se aprueba algo que no les gusta.
 *
 * Roles del TimelockController:
 *  - PROPOSER_ROLE : quién puede encolar operaciones (debe ser SOLO el Governor).
 *  - EXECUTOR_ROLE : quién puede ejecutarlas tras el retardo (address(0) = cualquiera).
 *  - CANCELLER_ROLE: quién puede cancelar operaciones encoladas (el Governor).
 *  - DEFAULT_ADMIN_ROLE: administra roles; se recomienda renunciarlo tras configurar.
 */
contract GovTimelock is TimelockController {
    /**
     * @param minDelay  Segundos mínimos entre encolar y ejecutar (ej: 3600 = 1 hora).
     * @param proposers Direcciones con PROPOSER_ROLE (y CANCELLER_ROLE). Puede ir vacío y asignarse luego.
     * @param executors Direcciones con EXECUTOR_ROLE. Usar [address(0)] para permitir a cualquiera.
     * @param admin     Admin temporal para configurar roles. Después debe renunciar al rol.
     */
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}
}
