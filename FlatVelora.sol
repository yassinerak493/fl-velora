// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// -------------------- BEGIN OpenZeppelin ERC20.sol --------------------
/**
 * @dev Implementation of the {IERC20} interface.
 * Simplified and flattened for Velora contract.
 */
// OpenZeppelin contracts v4.8.0 ERC20 + Ownable simplified flattening
// --- IERC20 interface ---
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// --- Context ---
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// --- Ownable ---
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() { _transferOwnership(_msgSender()); }
    function owner() public view virtual returns (address) { return _owner; }
    modifier onlyOwner() { require(owner() == _msgSender(), "Ownable: caller is not the owner"); _; }
    function renounceOwnership() public virtual onlyOwner { _transferOwnership(address(0)); }
    function transferOwnership(address newOwner) public virtual onlyOwner { require(newOwner != address(0), "Ownable: new owner is the zero address"); _transferOwnership(newOwner); }
    function _transferOwnership(address newOwner) internal virtual { address oldOwner = _owner; _owner = newOwner; emit OwnershipTransferred(oldOwner, newOwner); }
}

// --- ERC20 Implementation ---
contract ERC20 is Context, IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_){
        _name = name_;
        _symbol = symbol_;
    }

    function name() public view virtual returns (string memory){ return _name; }
    function symbol() public view virtual returns (string memory){ return _symbol; }
    function decimals() public view virtual returns (uint8){ return 18; }
    function totalSupply() public view virtual override returns (uint256){ return _totalSupply; }
    function balanceOf(address account) public view virtual override returns (uint256){ return _balances[account]; }
    function transfer(address to, uint256 amount) public virtual override returns (bool){
        _transfer(_msgSender(), to, amount);
        return true;
    }
    function allowance(address owner_, address spender) public view virtual override returns (uint256){
        return _allowances[owner_][spender];
    }
    function approve(address spender, uint256 amount) public virtual override returns (bool){
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool){
        _spendAllowance(from, _msgSender(), amount);
        _transfer(from, to, amount);
        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool){
        _approve(_msgSender(), spender, allowance(_msgSender(), spender) + addedValue);
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool){
        uint256 currentAllowance = allowance(_msgSender(), spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal virtual{
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        _balances[from] = fromBalance - amount;
        _balances[to] += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal virtual{
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual{
        require(account != address(0), "ERC20: burn from the zero address");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner_, address spender, uint256 amount) internal virtual{
        require(owner_ != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
    }

    function _spendAllowance(address owner_, address spender, uint256 amount) internal virtual{
        uint256 currentAllowance = allowance(owner_, spender);
        if(currentAllowance != type(uint256).max){
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            _approve(owner_, spender, currentAllowance - amount);
        }
    }
}
// -------------------- END OpenZeppelin Flatten --------------------

// -------------------- BEGIN Velora Contract --------------------
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
// -------------------- END Velora Contract --------------------
