// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LootBox is Ownable {
    using SafeERC20 for IERC20;
    
    struct Reward { 
        //@notice Type of reward
        Type rewardType;

        //@notice In case of ERC20 token reward, this field represents the amount of tokens. In case of NFT reward, it represents the token ID. 
        uint256 specifier;
    }

    enum Type { TOKEN0, NFT0, NFT1 }

    uint256 public fee;

    uint88 private _salt;
    address private _provider;
    bool public paused = false; 

    IERC20 private constant _TOKEN0 = IERC20(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
    IERC20 private constant _FEE_TOKEN = IERC20(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
    
    IERC721 private constant _NFT0 = IERC721(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db);
    IERC721 private constant _NFT1 = IERC721(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB);

    mapping(address => Reward) private _ownedRewards;
    Reward[] private _rewardList;
    
    modifier notPaused() {
        require(paused == false, "LootBox: contract paused");
        _;
    }
    
    /**
     * @param _fee amount of fee tokens taken per spin
     * @param salt_ used to generate random index for reward
     * @param provider_ address which will provide the rewards
     * @param initRewardList list of rewards available on contract deployment 
     */
    constructor(
        uint256 _fee,
        uint88 salt_,
        address provider_, 
        Reward[] memory initRewardList
    ) {
        fee = _fee;
        _provider = provider_;
        _salt = salt_;
        
        for(uint256 i; i < initRewardList.length; i++) 
            _rewardList.push(initRewardList[i]);
    }
    
    /**
     * @notice Spin once and win a reward
     * Caller must not have any unredeemed rewards
     * Contract must have rewards available
     */
    function spin() external notPaused {
        require(_ownedRewards[msg.sender].specifier == 0, "LootBox: redeem existing reward first"); 
        require(_rewardList.length > 0, "LootBox: no rewards left");
        
        uint256 rewardIndex = _random();
        _ownedRewards[msg.sender] = _rewardList[rewardIndex];
        _removeReward(rewardIndex);

        _FEE_TOKEN.safeTransferFrom(msg.sender, address(this), fee);
    }

    /**
     * @notice Redeem available reward
     * @dev Reward transferred from _provider to caller. 
     * NOTE: _provider must have approved this contract beforehand to transfer the reward.
     */
    function redeem() external notPaused {
        Reward memory reward = _ownedRewards[msg.sender];
        require(reward.specifier != 0, "LootBox: no reward available");
        delete _ownedRewards[msg.sender];

        if(reward.rewardType == Type.TOKEN0)
            _TOKEN0.safeTransferFrom(_provider, msg.sender, reward.specifier);
        else if(reward.rewardType == Type.NFT0)
            _NFT0.safeTransferFrom(_provider, msg.sender, reward.specifier);
        else 
            _NFT1.safeTransferFrom(_provider, msg.sender, reward.specifier);
    }

    /**
     * @notice Retrieves information about unredeemed reward of caller
     */
    function getMyRewardInfo() external view returns (Reward memory) {
        return _ownedRewards[msg.sender];
    }

    /**
     * @notice Retrieves total amount of rewards available to win
     */
    function getTotalRewardsLeft() external view returns (uint256) {
        return _rewardList.length;
    }

    /* |--- Private functions ---| */

    /**
     * @dev Generates and returns a random index within the range of available rewards
     */
    function _random() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _salt))) % _rewardList.length; 
    }

    /**
     * @dev Removes the reward at specified index and resizes reward list
     */
    function _removeReward(uint index) private {
        uint256 length = _rewardList.length;
        if(1 < _rewardList.length && index < length-1) 
            _rewardList[index] = _rewardList[length-1];
        
        delete _rewardList[length-1];
        _rewardList.pop();
    }

    /* |--- OWNER ONLY ---| */

    /**
     * @notice Adds new rewards to the list of available rewards
     * @param rewards list of new rewards to add
     */
    function addRewards(Reward[] calldata rewards) external onlyOwner {
        for(uint i; i < rewards.length; i++)
            _rewardList.push(rewards[i]);
    }

    /**
     * @notice Removes the reward at specified index
     * @param index Index of reward to remove
     */
    function removeReward(uint256 index) external onlyOwner {
        require(index < _rewardList.length, "LootBox: invalid index");
        _removeReward(index);
    }

    /**
     * @notice Changes fee token
     * @param feeToken_ New fee token address
     */
    function setFeeToken(address feeToken_) external onlyOwner {
        _FEE_TOKEN = IERC20(feeToken_);
    }
    
    /**
     * @notice Changes salt to be used for random index generation
     * @param salt_ New salt to be used
     */
    function setSalt(uint88 salt_) external onlyOwner {
        _salt = salt_;
    }
    
    /**
     * @notice Changes provider address for rewards
     * @param provider_ New provider address
     */
    function setProvider(address provider_) external onlyOwner {
        _provider = provider_;
    }

    /**
     * @notice Changes fee amount taken per spin
     * @param _fee New fee per spin
     */
    function setFee(uint256 _fee) external onlyOwner {
        fee = _fee;
    }

    /**
     * @notice Retrieve list of available rewards
     */
    function getRewardList() external view onlyOwner returns (Reward[] memory) {
        return _rewardList;
    }

    /**
     * @notice Transfers accumulated fee tokens to the treasury
     */
    function withdraw() external onlyOwner {
        _FEE_TOKEN.safeTransfer(owner(), _FEE_TOKEN.balanceOf(address(this)));
    }

    /**
     * @notice Pauses contract functionality
     */
    function pause() external onlyOwner {
        paused = true;
    }

    /**
     * @notice Unpauses contract functionality
     */
    function unpause() external onlyOwner {
        paused = false;
    }

}
