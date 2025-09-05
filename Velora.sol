// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts@4.8.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.8.0/access/Ownable.sol";

contract Velora is ERC20, Ownable {
    uint8 private _decimals = 8;
    uint256 public feePercent = 3; // 3% fee to owner
    address public feeWallet = 0xFd4E82682563bef6aA1984D1821e8aB225e856A6;

    bool public pausedAll = false;
    uint256 public maxTxAmount;

    mapping(address => bool) public frozen;
    mapping(address => bool) public blocked;
    mapping(address => bool) public whitelist;

    constructor() ERC20("Velora", "VEL") {
        _mint(feeWallet, 420000000000 * 10**_decimals); // mint total supply to owner wallet
        maxTxAmount = 420000000000 * 10**_decimals;
    }

    function decimals() public view override returns (uint8) { 
        return _decimals; 
    }

    // Freeze/block functions
    function freeze(address account) external onlyOwner { frozen[account] = true; }
    function unfreeze(address account) external onlyOwner { frozen[account] = false; }
    function blockWallet(address account) external onlyOwner { blocked[account] = true; }
    function unblockWallet(address account) external onlyOwner { blocked[account] = false; }

    // Whitelist
    function addWhitelist(address account) external onlyOwner { whitelist[account] = true; }
    function removeWhitelist(address account) external onlyOwner { whitelist[account] = false; }

    // Mint & burn
    function mint(address to, uint256 amount) external onlyOwner { _mint(to, amount); }
    function burn(uint256 amount) external { _burn(msg.sender, amount); }

    // Fees
    function setFeePercent(uint256 percent) external onlyOwner { feePercent = percent; }
    function setFeeWallet(address wallet) external onlyOwner { feeWallet = wallet; }

    // Pause all transfers
    function pauseAll() external onlyOwner { pausedAll = true; }
    function unpauseAll() external onlyOwner { pausedAll = false; }

    // Max tx amount
    function setMaxTxAmount(uint256 amount) external onlyOwner { maxTxAmount = amount; }

    // Airdrop
    function airdrop(address[] calldata recipients, uint256 amount) external onlyOwner {
        for(uint i = 0; i < recipients.length; i++){
            _transfer(feeWallet, recipients[i], amount * 10**_decimals);
        }
    }

    // Internal transfer with fee, freeze/block, whitelist, anti-whale
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(!pausedAll, "All transfers are paused");
        require(!frozen[sender], "Sender wallet frozen");
        require(!blocked[sender], "Sender wallet blocked");
        require(amount <= maxTxAmount, "Exceeds max tx amount");

        uint256 fee = 0;

        if(!whitelist[sender] && !whitelist[recipient]) {
            fee = (amount * feePercent) / 100;
        }

        uint256 amountAfterFee = amount - fee;

        // Send fee to owner wallet
        if(fee > 0) super._transfer(sender, feeWallet, fee);

        super._transfer(sender, recipient, amountAfterFee);
    }
}
