// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LootBox is Ownable {
    using SafeERC20 for IERC20;
    
    struct Reward { 
        //@notice Type of reward
        Type rwdType;

        //@notice In case of ERC20 token reward, this field represents the amount of tokens. In case of NFT reward, it represents the token ID. 
        uint256 amountOrId;
    }

    enum Type { TOKEN0, NFT0, NFT1 }

    uint256 public fee;
    uint88 private _salt;
    address private _provider;
    bool public paused = false; 

    IERC20 private constant _FEE_TOKEN = IERC20(0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
    IERC20 private constant _TOKEN0 = IERC20(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
    
    IERC721 private constant _NFT0 = IERC721(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db);
    IERC721 private constant _NFT1 = IERC721(0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB);

    mapping(address => Reward) private _ownedRewards;
    Reward[] private _rewardList;
    
    modifier notPaused() {
        require(paused == false, "LootBox: contract paused");
        _;
    }
    
    /**
     * @param provider_ address which will provide the rewards
     * @param salt_ used to generate random index for reward
     * @param _fee fee amount per spin
     * @param initRewardList list of rewards available on contract deployment 
     * NOTE: Provider must approve this contract for every reward before they can be claimed
     */
    constructor(
        address provider_, 
        uint88 salt_,
        uint256 _fee,
        Reward[] memory initRewardList
    ) {
        _provider = provider_;
        _salt = salt_;
        fee = _fee;
        
        for(uint256 i; i < initRewardList.length; i++) 
            _rewardList.push(initRewardList[i]);
    }
    
    /**
     * @notice Spin once and win a reward
     * Caller must not have any unclaimed rewards
     * Contract must have rewards available
     */
    function spin() external notPaused {
        require(_ownedRewards[msg.sender].amountOrId == 0, "LootBox: claim existing reward first"); 
        require(_rewardList.length > 0, "LootBox: no rewards left");
        uint256 idx = _random();
        _ownedRewards[msg.sender] = _rewardList[idx];
        _removeReward(idx);

        _FEE_TOKEN.safeTransferFrom(msg.sender, address(this), fee);
    }

    /**
     * @notice Claim available reward
     * @dev Reward transferred from provider to caller. 
     * NOTE: Provider has to approve this contract to transfer the reward beforehand.
     */
    function claim() external notPaused {
        Reward memory reward = _ownedRewards[msg.sender];
        require(reward.amountOrId != 0, "LootBox: no reward available");
        delete _ownedRewards[msg.sender];

        if(reward.rwdType == Type.TOKEN0)
            _TOKEN0.transferFrom(_provider, msg.sender, reward.amountOrId);
        else if(reward.rwdType == Type.NFT0)
            _NFT0.safeTransferFrom(_provider, msg.sender, reward.amountOrId);
        else 
            _NFT1.safeTransferFrom(_provider, msg.sender, reward.amountOrId);
    }

    /**
     * @notice Retrieves information about currently won yet unclaimed reward
     */
    function getPendingRewardInfo() external view returns (Reward memory) {
        return _ownedRewards[msg.sender];
    }

    /**
     * @notice Get total amount of rewards available to win
     */
    function getRewardsLeft() external view returns (uint) {
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
    function _removeReward(uint idx) private {
        require(idx < _rewardList.length);
        uint256 length = _rewardList.length;
        if(1 < _rewardList.length && idx < length-1) 
            _rewardList[idx] = _rewardList[length-1];
        
        delete _rewardList[length-1];
        _rewardList.pop();
    }

    /* |--- OWNER ONLY ---| */
    
    /**
     * @notice Adds a new reward to the list of available rewards
     */
    function addReward(Reward calldata reward) external onlyOwner {
        _rewardList.push(reward);
    }

    /**
     * @notice Removes the reward at specified index
     * @param index Index of reward to remove
     */
    function removeReward(uint256 index) external onlyOwner {
        _removeReward(index);
    }
    
    /**
     * @notice Changes seed to be used for random index creation
     * @param salt_ New seed to be used
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
     * @notice Transfers tokens accumulated from fees to the contract owner
     */
    function withdraw() external onlyOwner {
        _FEE_TOKEN.transfer(owner(), _FEE_TOKEN.balanceOf(address(this)));
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
