// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "./IERC20.sol";
import "./ERC20Internal.sol";
import "./ERC2612.sol";
import "./Recover.sol";

contract Leverix is IERC20, ERC20Internal, ERC2612, Recover {
    // private data structures
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;

    string private constant ERR_BTL = "Balance to low";
    string private constant ERR_ATL = "Allowance to low";

    /**
        @notice Contract constructor
        @param name_ name of the token
        @param symbol_ symbol of the token
        @param supply_ initial supply of the token mint to deployer
     */
    constructor(
        string memory name_,
        string memory symbol_,
        string memory contractVersion,
        uint256 supply_
    ) {
        _name = name_;
        _symbol = symbol_;
        generateDomainSeparatorEIP712(contractVersion);
        _balances[msg.sender] = supply_;
        _totalSupply = supply_;
        emit Transfer(ZERO_ADDRESS, msg.sender, supply_);
    }

    function generateDomainSeparatorEIP712(string memory contractVersion) internal{
        uint256 chainId = block.chainid;
        DOMAIN_SEPARATOR = EIP712.makeDomainSeparator(
            _name,
            contractVersion,
            chainId
        );
        CHAINID = chainId;
        EIP712_DOMAIN_TYPEHASH = EIP712.EIP712_DOMAIN_TYPEHASH;
    }

    // modifiers
    modifier notZeroAddress(address user) {
        require(user != ZERO_ADDRESS, "Address 0x0 is not allowed");
        _;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address user) external view override returns (uint256) {
        return _balances[user];
    }

    function allowance(address owner, address sender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[owner][sender];
    }

    function name() external view override returns (string memory) {
        return _name;
    }

    function symbol() external view override returns (string memory) {
        return _symbol;
    }

    function decimals() external pure override returns (uint8) {
        return _decimals;
    }

    function approve(address spender, uint256 amount)
        external
        notZeroAddress(spender)
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 amount
    ) internal override {
        _allowances[_owner][_spender] = amount;
        emit Approval(_owner, _spender, amount);
    }

    function transfer(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        uint256 current = _allowances[sender][msg.sender];
        if (current < type(uint256).max)
        {
            require(current >= amount, ERR_ATL);
            unchecked {
                _allowances[sender][msg.sender] = current - amount;
            }
        }
        _transfer(sender, recipient, amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override notZeroAddress(to) {
        uint256 currentBalance = _balances[from];
        require(currentBalance >= amount, ERR_BTL);
        unchecked {
            _balances[from] = currentBalance - amount;
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function burn(uint256 amount) external returns (bool) {
        _burn(msg.sender, amount);
        return true;
    }

    function burnFrom(address user, uint256 amount) external returns (bool) {
        uint256 current = _allowances[user][msg.sender];
        if (current < type(uint256).max) // respect dex/Uniswap "allow forever"
        {
            require(current >= amount, ERR_ATL);
            // will not overflow
            unchecked {
                _allowances[user][msg.sender] = current - amount;
            }
        }
        _burn(user, amount);
        return true;
    }

    function _burn(address user, uint256 amount) internal {
        uint256 current = _balances[user];
        require(current >= amount, ERR_BTL);
        unchecked {
            _balances[user] = current - amount;
            _totalSupply -= amount;
        }
        emit Transfer(user, ZERO_ADDRESS, amount);
    }
}
