// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Núcleo del Governor: crear propuestas, votar, ejecutar.
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
// Parámetros ajustables por gobernanza: retardo de votación, duración y umbral de propuesta.
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
// Conteo simple de votos: A favor / En contra / Abstención.
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
// Conecta el Governor con un token IVotes (nuestro GovToken) para leer el poder de voto.
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
// Quórum expresado como porcentaje del suministro total del token.
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
// Integra el Governor con el Timelock (las propuestas se ejecutan a través de él).
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
// Interfaz de tokens con votos (la implementa ERC20Votes).
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/**
 * @title MyGovernor
 * @notice Gobernanza on-chain del token GOV (estilo Compound/Uniswap).
 * @dev Ciclo de vida de una propuesta:
 *   1. Pending  : creada; espera `votingDelay` bloques antes de abrir la votación.
 *   2. Active   : se puede votar durante `votingPeriod` bloques.
 *   3. Succeeded/Defeated : según quórum y mayoría de votos a favor.
 *   4. Queued   : encolada en el Timelock (espera `minDelay`).
 *   5. Executed : ejecutada por el Timelock.
 *
 * El poder de voto se mide en un "snapshot" (el bloque de inicio de la votación),
 * por lo que comprar tokens una vez abierta la propuesta no sirve para manipular el resultado.
 */
contract MyGovernor is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl
{
    /**
     * @param _token    Token con votos (GovToken).
     * @param _timelock Timelock que ejecuta las propuestas aprobadas.
     */
    constructor(IVotes _token, TimelockController _timelock)
        // Nombre del Governor (se usa en el dominio EIP-712 de votos por firma).
        Governor("MyGovernor")
        // votingDelay = 7200 bloques (~1 día a 12 s/bloque)
        // votingPeriod = 50400 bloques (~1 semana)
        // proposalThreshold = 0 (cualquiera con >0 votos puede proponer; súbelo para evitar spam)
        GovernorSettings(7200, 50400, 0)
        // Indica de qué token se leen los votos.
        GovernorVotes(_token)
        // Quórum = 4% del suministro total en el snapshot.
        GovernorVotesQuorumFraction(4)
        // Vincula el Timelock.
        GovernorTimelockControl(_timelock)
    {}

    /*//////////////////////////////////////////////////////////////
        OVERRIDES: resuelven conflictos entre extensiones heredadas.
        Todos delegan en `super`, no cambian el comportamiento.
    //////////////////////////////////////////////////////////////*/

    /// @dev Bloques de espera entre crear la propuesta y abrir la votación.
    function votingDelay()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    /// @dev Duración de la votación en bloques.
    function votingPeriod()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    /// @dev Votos mínimos necesarios para que una propuesta sea válida (según snapshot y fracción).
    function quorum(uint256 blockNumber)
        public
        view
        override(Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    /// @dev Estado actual de la propuesta (Pending, Active, Queued, Executed...).
    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    /// @dev Indica que las propuestas deben pasar por la cola del Timelock antes de ejecutarse.
    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    /// @dev Votos mínimos que debe tener quien crea una propuesta.
    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    /// @dev Encola la propuesta en el Timelock tras ser aprobada.
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @dev Ejecuta las operaciones a través del Timelock.
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /// @dev Cancela una propuesta (también la cancela en el Timelock si estaba encolada).
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /// @dev Dirección que ejecuta las llamadas: el Timelock (no el Governor).
    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }
}
