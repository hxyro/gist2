//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

error NotOwner();
error PropertyDoesNotExist();
error NotContractOwner();
error PropertyNotApproved();

contract PropertyContract{

    enum propertyStatus {Created, Approved, Rejected}    
    uint256 private ID;
    address immutable contractOwner;
    //
    // Property[] private emptyPropertyArray;
    // Property private emptyProperty;

    struct Property{
        uint256 id;
        address propertyOwner;
        uint256 Price;
        propertyStatus Status;
        string Details;
        uint256 CreatedAt;
        uint256 UpdatedAt;
    }

    mapping(uint256 => Property[]) private propertyHistory;
    mapping(uint256 => Property) private currentProperty;

    mapping(uint256 => address) private maxBid;
    mapping(uint256 => address[]) private biddersArray;
    mapping(uint256 => mapping(address => uint256)) private bidder;

    constructor(){
        ID = 0;
        contractOwner = msg.sender;
    }

    //auto increment Id by one
    modifier autoIncrementId(){
        ID += 1;
        _;
    }
    // check if the caller is the property owner
    modifier onlyOwner(uint256 Id){
        if(msg.sender != currentProperty[Id].propertyOwner){
            revert NotOwner();
        }
        _;
    }
    // check if the caller is the contract owner
    modifier onlyContractOwner(){
        if(msg.sender != contractOwner){
            revert NotContractOwner();
        }
        _;
    }
    // check if property exists
    modifier isPropertyExist(uint256 Id){
        if(currentProperty[Id].id == 0){ // Each attribute in the default initialize property must be equal to zero
            revert PropertyDoesNotExist();
        }
        _;
    }
    modifier isApproved(uint256 Id){
        if(currentProperty[Id].Status != propertyStatus.Approved){
            revert PropertyNotApproved();
        }
        _;
    }

    function createProperty(string calldata details, uint256 price) autoIncrementId external returns(uint256){
        Property memory newProperty = Property({
            id: ID,
            propertyOwner: msg.sender,
            Price: price,
            Status: propertyStatus.Created,
            Details: details,
            CreatedAt: block.timestamp,
            UpdatedAt: block.timestamp
        });
        currentProperty[ID] = newProperty;
        propertyHistory[ID].push(newProperty);
        return ID;
    }
    
    function updatePrice(uint256 Id, uint256 updatedprice) isPropertyExist(Id) onlyOwner(Id) public{
        currentProperty[Id].Price = updatedprice;
        currentProperty[Id].UpdatedAt = block.timestamp; 
        propertyHistory[Id].push(currentProperty[Id]);
    }

    function approveProperty(uint256 Id) onlyContractOwner external{
        currentProperty[Id].Status = propertyStatus.Approved;
        currentProperty[Id].UpdatedAt = block.timestamp; 
        propertyHistory[Id].push(currentProperty[Id]);
    }

    function rejectProperty(uint256 Id) onlyContractOwner private {
        currentProperty[Id].Status = propertyStatus.Approved;
        currentProperty[Id].UpdatedAt = block.timestamp; 
        propertyHistory[Id].push(currentProperty[Id]);
    }

    function deleteProperty(uint256 Id) onlyOwner(Id) external {
        Property memory emptyProperty;
        delete propertyHistory[Id];
        // delete currentProperty[Id];
        currentProperty[Id] = emptyProperty;
    }

    function bidOnProperty(uint256 Id) isPropertyExist(Id) isApproved(Id) external payable {
        require(msg.value > currentProperty[Id].Price);
        bidder[Id][msg.sender] += msg.value;
        biddersArray[Id].push(msg.sender);
        if(bidder[Id][msg.sender] > bidder[Id][maxBid[Id]]){
            maxBid[Id] = msg.sender;
        }
    }

    function sellProperty(uint256 Id) onlyOwner(Id) external {
        uint256 biddingAmount = bidder[Id][maxBid[Id]];
        require(biddingAmount > 0);
        bidder[Id][maxBid[Id]] = 0;
        payable(currentProperty[Id].propertyOwner).transfer(biddingAmount);
        currentProperty[Id].propertyOwner = maxBid[Id];
        currentProperty[Id].UpdatedAt = block.timestamp; 
        propertyHistory[Id].push(currentProperty[Id]);

        for(uint256 i = 0; i < biddersArray[Id].length; i++){
            payable(biddersArray[Id][i]).transfer(bidder[Id][biddersArray[Id][i]]);
            bidder[Id][biddersArray[Id][i]] = 0;
        }

    }

    // retrieve property struct by Id
    function getProperty(uint256 Id) view external isPropertyExist(Id) returns(Property memory){
        return currentProperty[Id];
    }
    // retrieve property history array by Id
    function getPropertyHistory(uint256 Id) view external isPropertyExist(Id) returns(Property[] memory){
        return propertyHistory[Id];
    }

}
