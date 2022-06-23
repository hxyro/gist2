//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
error NotOwner();
contract place{
    enum _Status {created,approved, rejected}
    // _Status private _status;
    uint256 private ID;
    struct Property{
        string Details;
        address Owner; //
        uint256 Price; //
        _Status Status;
        uint CreatedAt;
        uint UpdatedAt;
        uint256 Id;
    }

    mapping(uint256 => Property[]) internal History;
    mapping(uint256 => Property) internal currentProperty;
    constructor(){
        ID = 0;
    }
    modifier onlyOwner(uint256 Id){
        if(msg.sender != currentProperty[Id].Owner){
            revert NotOwner();
        }
        _;
    }
    modifier isPropertyExist(uint256 Id){

    }
    function createProperty(string calldata details, uint256 price) public returns(uint256) {
        _Status status = _Status.created;
        ID += 1;
        Property memory newProperty = Property({
                Details: details,
                Owner: msg.sender,
                Price: price,
                Status: status,
                CreatedAt: block.timestamp,
                UpdatedAt: block.timestamp,
                Id: ID
        });
        currentProperty[ID] = newProperty;
        History[ID].push(newProperty);
        return ID;
    }
    function updatePrice(uint256 Id, uint256 updatedprice) onlyOwner(Id) public {
        currentProperty[Id].Price = updatedprice;
        currentProperty[Id].UpdatedAt = block.timestamp; 
        History[ID].push(currentProperty[Id]);
    }

}
