// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";

contract RPSLS is CommitReveal, TimeUnit {
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping(address => bytes32) public player_commit;
    mapping(address => uint) public player_choice;
    mapping(address => bool) public hasRevealed;
    address[] public players;
    uint public numRevealed = 0;
    uint public gameStartTime;

    address[4] private allowedPlayers = [
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db,
        0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB
    ];

    modifier onlyAllowedPlayers() {
        bool isAllowed = false;
        for (uint i = 0; i < allowedPlayers.length; i++) {
            if (msg.sender == allowedPlayers[i]) {
                isAllowed = true;
                break;
            }
        }
        require(isAllowed, "Not an allowed player");
        _;
    }

    function addPlayer(bytes32 commitHash) public payable onlyAllowedPlayers {
        require(numPlayer < 2, "Game already full");
        require(msg.value == 1 ether, "Must send 1 ether");
        require(player_commit[msg.sender] == bytes32(0), "Already joined");
        
        reward += msg.value;
        player_commit[msg.sender] = commitHash;
        players.push(msg.sender);
        numPlayer++;

        if (numPlayer == 2) {
            setStartTime();
            gameStartTime = block.timestamp;
        }
    }

    function reveal(uint choice, string memory secret) public {
        require(numPlayer == 2, "Not enough players");
        require(!hasRevealed[msg.sender], "Already revealed");
        require(choice >= 0 && choice <= 4, "Invalid choice");
        require(player_commit[msg.sender] == keccak256(abi.encodePacked(choice, secret)), "Invalid reveal");
        
        player_choice[msg.sender] = choice;
        hasRevealed[msg.sender] = true;
        numRevealed++;

        if (numRevealed == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
        uint c0 = player_choice[players[0]];
        uint c1 = player_choice[players[1]];
        address payable a0 = payable(players[0]);
        address payable a1 = payable(players[1]);

        if ((c0 + 1) % 5 == c1 || (c0 + 3) % 5 == c1) {
            a1.transfer(reward);
        } else if ((c1 + 1) % 5 == c0 || (c1 + 3) % 5 == c0) {
            a0.transfer(reward);
        } else {
            a0.transfer(reward / 2);
            a1.transfer(reward / 2);
        }

        _resetGame();
    }

    function _resetGame() private {
        numPlayer = 0;
        reward = 0;
        numRevealed = 0;
        delete players;
    }

    function withdrawIfTimeout() public {
        require(numPlayer == 2, "Game not started");
        require(block.timestamp > gameStartTime + 10 minutes, "Wait 10 minutes");
        
        for (uint i = 0; i < players.length; i++) {
            if (!hasRevealed[players[i]]) {
                payable(players[i]).transfer(1 ether);
            }
        }

        _resetGame();
    }
}
