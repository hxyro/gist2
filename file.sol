//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

error NotOwner();
error PropertyDoesNotExist();

contract PropertyContract{

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

    mapping(uint256 => Property[]) private propertyHistory;
    mapping(uint256 => Property) public currentProperty;

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
    // check if property exists
    modifier isPropertyExist(uint256 Id){
        if(currentProperty[Id].id == 0){ // Each attribute in the default initialize property must be equal to zero
            revert PropertyDoesNotExist();
        }
        _;
    }

    function createProperty(string calldata details, uint256 price) autoIncrementId external returns(uint256){
        Property memory newProperty = Property({
            id: ID,
            propertyOwner: contractOwner,
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
        propertyHistory[ID].push(currentProperty[Id]);
    }

}
