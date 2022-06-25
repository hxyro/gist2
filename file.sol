//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

error NotOwner();
error PropertyDoesNotExist();
error NotContractOwner();
error PropertyNotApproved();

contract PropertyContract{
    // enum for property status
    enum propertyStatus {Created, Approved, Rejected}

    uint256 private ID;
    address immutable contractOwner;

    struct Property{
        uint256 id;
        address propertyOwner;
        uint256 Price;
        propertyStatus Status;
        string Details;
        uint256 CreatedAt;
        uint256 UpdatedAt;
    }
    event propertyCreated(Property);
    event propertySold(Property, address indexed newOwner);


    mapping(uint256 => Property[]) private propertyHistory;
    mapping(uint256 => Property) private currentProperty;

    mapping(uint256 => address) private maxBid; // Maximum bid on property (bid = bidder[Id][maxBid[Id]])
    mapping(uint256 => address[]) private biddersArray; // Stores all the bidders for a specific property
    mapping(uint256 => mapping(address => uint256)) private bidder; // (property Id => (bidder's address => bid))

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
    // check if the property is approved for sale or bidding
    modifier isApproved(uint256 Id){
        if(currentProperty[Id].Status != propertyStatus.Approved){
            revert PropertyNotApproved();
        }
        _;
    }
    // update the property timestamp and history
    modifier updateProperty(uint256 Id){
        _;
        currentProperty[Id].UpdatedAt = block.timestamp; 
        propertyHistory[Id].push(currentProperty[Id]);
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
        emit propertyCreated(newProperty);
        return ID;
    }
    // only the Owner of the property can update the price 
    function updatePrice(uint256 Id, uint256 updatedprice) isPropertyExist(Id) onlyOwner(Id) updateProperty(Id) public{
        currentProperty[Id].Price = updatedprice;
    }
    // only the Owner of the contract can approve the property status
    // Approved property can be re-approved. 
    // I can use the "require" statement to check if the property is already approved, but that would just be a waste of gas(same for rejectProperty() function)
    function approveProperty(uint256 Id) onlyContractOwner updateProperty(Id) external{
        currentProperty[Id].Status = propertyStatus.Approved;
    }
    // only the Owner of the contract can reject the property status
    // I am not sure about it, if the property has been rejected so it can be tradable or not and users can get their refund
    function rejectProperty(uint256 Id) onlyContractOwner updateProperty(Id) external {
        currentProperty[Id].Status = propertyStatus.Rejected;
        
        // not sure about the following block
        // rejection of the property will automatically issue a refund to the bidders(if any)
        // uint256 biddingAmount = bidder[Id][maxBid[Id]];
        // if(biddingAmount > 0){
        //     uint256 length = biddersArray[Id].length;
        //     for(uint256 i = 0; i < length; i++){
        //         payable(biddersArray[Id][i]/*<-- bidder's address*/).transfer(bidder[Id][biddersArray[Id][i]]/*<-- bid*/);
        //         bidder[Id][biddersArray[Id][i]] = 0;
        //     }
        //     delete biddersArray[Id];
        // }
    }
    // only the Owner of the property can delete the property
    function deleteProperty(uint256 Id) onlyOwner(Id) external {
        delete propertyHistory[Id];
        delete currentProperty[Id];

        // removal of the property will automatically issue a refund to the bidders 
        uint256 biddingAmount = bidder[Id][maxBid[Id]];
        if(biddingAmount > 0){
            uint256 length = biddersArray[Id].length;
            for(uint256 i = 0; i < length; i++){
                payable(biddersArray[Id][i]/*<-- bidder's address*/).transfer(bidder[Id][biddersArray[Id][i]]/*<-- bid*/);
                bidder[Id][biddersArray[Id][i]] = 0;
            }
            delete biddersArray[Id];
        }

    }
    // only approved properties are available for bidding
    function bidOnProperty(uint256 Id) isPropertyExist(Id) isApproved(Id) external payable {
        //required! bidding price > actual price
        require(msg.value > 0,"value must be higher than actual price");
        require(msg.value + bidder[Id][msg.sender] > currentProperty[Id].Price,"value must be higher than actual price");
        bidder[Id][msg.sender] += msg.value; //user cat bid multiple times to increase the bid amount
        biddersArray[Id].push(msg.sender);
        if(bidder[Id][msg.sender] > bidder[Id][maxBid[Id]]){
            maxBid[Id] = msg.sender;
        }
    }
    //only those properties are available for sale on which users have bid on
    //only the Owner of the property can sell the property
    function sellProperty(uint256 Id) onlyOwner(Id) isPropertyExist(Id) external {
        uint256 biddingAmount = bidder[Id][maxBid[Id]];
        require(biddingAmount > 0,"no bids yet");
        
        bidder[Id][maxBid[Id]] = 0;
        payable(currentProperty[Id].propertyOwner).transfer(biddingAmount);
        
        //update the property
        currentProperty[Id].propertyOwner = maxBid[Id];
        currentProperty[Id].UpdatedAt = block.timestamp; 
        propertyHistory[Id].push(currentProperty[Id]);
        
        //users can get their refund once the property is sold
        uint256 length = biddersArray[Id].length;// accessing memory data will be cheaper than accessing storage data
        for(uint256 i = 0; i < length; i++){
            payable(biddersArray[Id][i]/*<-- bidder's address*/).transfer(bidder[Id][biddersArray[Id][i]]/*<-- bid*/);
            bidder[Id][biddersArray[Id][i]] = 0;
        }
        delete biddersArray[Id];
        emit propertySold(currentProperty[Id], currentProperty[Id].propertyOwner);
    }

    // retrieve property struct by Id
    function getProperty(uint256 Id) view external isPropertyExist(Id) returns(Property memory){
        return currentProperty[Id];
    }
    // retrieve property history array by Id
    function getPropertyHistory(uint256 Id) view external isPropertyExist(Id) returns(Property[] memory){
        return propertyHistory[Id];
    }
    // get maximum bid amount
    function getMaxBid(uint256 Id) view external isPropertyExist(Id) returns(uint256){
        return bidder[Id][maxBid[Id]];
    }
    // get bidders list
    function getBiddersList(uint256 Id) view external isPropertyExist(Id) returns(address[] memory){
        return biddersArray[Id];
    }

}
