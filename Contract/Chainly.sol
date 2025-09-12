// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Chainly
 * @dev A decentralized chain-of-custody tracking system for supply chain management
 * @author Chainly Team
 */
contract Chainly {
    
    // Struct to represent an item in the supply chain
    struct Item {
        uint256 id;
        string name;
        string description;
        address currentOwner;
        address creator;
        uint256 createdAt;
        bool isActive;
        uint256 transferCount;
    }
    
    // Struct to represent a transfer record
    struct Transfer {
        uint256 itemId;
        address from;
        address to;
        uint256 timestamp;
        string notes;
        bytes32 transferHash;
    }
    
    // State variables
    mapping(uint256 => Item) public items;
    mapping(uint256 => Transfer[]) public itemTransfers;
    mapping(address => uint256[]) public ownerItems;
    
    uint256 public nextItemId;
    uint256 public totalItems;
    
    // Events
    event ItemCreated(uint256 indexed itemId, string name, address indexed creator);
    event ItemTransferred(uint256 indexed itemId, address indexed from, address indexed to, bytes32 transferHash);
    event ItemVerified(uint256 indexed itemId, address indexed verifier);
    
    // Modifiers
    modifier onlyItemOwner(uint256 _itemId) {
        require(items[_itemId].currentOwner == msg.sender, "Only item owner can perform this action");
        _;
    }
    
    modifier itemExists(uint256 _itemId) {
        require(items[_itemId].isActive, "Item does not exist or is inactive");
        _;
    }
    
    /**
     * @dev Creates a new item in the supply chain
     * @param _name Name of the item
     * @param _description Description of the item
     * @return itemId The ID of the newly created item
     */
    function createItem(string memory _name, string memory _description) 
        external 
        returns (uint256 itemId) 
    {
        require(bytes(_name).length > 0, "Item name cannot be empty");
        
        itemId = nextItemId++;
        
        items[itemId] = Item({
            id: itemId,
            name: _name,
            description: _description,
            currentOwner: msg.sender,
            creator: msg.sender,
            createdAt: block.timestamp,
            isActive: true,
            transferCount: 0
        });
        
        ownerItems[msg.sender].push(itemId);
        totalItems++;
        
        // Create initial transfer record
        Transfer memory initialTransfer = Transfer({
            itemId: itemId,
            from: address(0),
            to: msg.sender,
            timestamp: block.timestamp,
            notes: "Item created",
            transferHash: keccak256(abi.encodePacked(itemId, address(0), msg.sender, block.timestamp))
        });
        
        itemTransfers[itemId].push(initialTransfer);
        
        emit ItemCreated(itemId, _name, msg.sender);
        
        return itemId;
    }
    
    /**
     * @dev Transfers ownership of an item to another address
     * @param _itemId ID of the item to transfer
     * @param _to Address to transfer the item to
     * @param _notes Optional notes about the transfer
     */
    function transferItem(uint256 _itemId, address _to, string memory _notes) 
        external 
        onlyItemOwner(_itemId) 
        itemExists(_itemId) 
    {
        require(_to != address(0), "Cannot transfer to zero address");
        require(_to != msg.sender, "Cannot transfer to yourself");
        
        address previousOwner = items[_itemId].currentOwner;
        
        // Update item owner
        items[_itemId].currentOwner = _to;
        items[_itemId].transferCount++;
        
        // Update owner mappings
        ownerItems[_to].push(_itemId);
        _removeItemFromOwner(previousOwner, _itemId);
        
        // Create transfer hash for integrity
        bytes32 transferHash = keccak256(
            abi.encodePacked(_itemId, previousOwner, _to, block.timestamp, _notes)
        );
        
        // Record transfer
        Transfer memory newTransfer = Transfer({
            itemId: _itemId,
            from: previousOwner,
            to: _to,
            timestamp: block.timestamp,
            notes: _notes,
            transferHash: transferHash
        });
        
        itemTransfers[_itemId].push(newTransfer);
        
        emit ItemTransferred(_itemId, previousOwner, _to, transferHash);
    }
    
    /**
     * @dev Verifies the authenticity and integrity of an item's chain of custody
     * @param _itemId ID of the item to verify
     * @return isValid True if the item's chain of custody is valid
     * @return transferCount Number of transfers the item has undergone
     * @return creator Original creator of the item
     */
    function verifyItem(uint256 _itemId) 
        external 
        itemExists(_itemId) 
        returns (bool isValid, uint256 transferCount, address creator) 
    {
        Item memory item = items[_itemId];
        Transfer[] memory transfers = itemTransfers[_itemId];
        
        // Basic validation
        if (transfers.length == 0) {
            return (false, 0, address(0));
        }
        
        // Verify chain integrity
        for (uint256 i = 0; i < transfers.length; i++) {
            Transfer memory transfer = transfers[i];
            
            // Verify transfer hash
            bytes32 expectedHash;
            if (i == 0) {
                // First transfer (creation)
                expectedHash = keccak256(
                    abi.encodePacked(transfer.itemId, address(0), transfer.to, transfer.timestamp)
                );
            } else {
                expectedHash = keccak256(
                    abi.encodePacked(transfer.itemId, transfer.from, transfer.to, transfer.timestamp, transfer.notes)
                );
            }
            
            if (transfer.transferHash != expectedHash) {
                return (false, item.transferCount, item.creator);
            }
        }
        
        emit ItemVerified(_itemId, msg.sender);
        
        return (true, item.transferCount, item.creator);
    }
    
    // View functions
    
    /**
     * @dev Get item details
     */
    function getItem(uint256 _itemId) 
        external 
        view 
        itemExists(_itemId) 
        returns (Item memory) 
    {
        return items[_itemId];
    }
    
    /**
     * @dev Get transfer history of an item
     */
    function getItemHistory(uint256 _itemId) 
        external 
        view 
        itemExists(_itemId) 
        returns (Transfer[] memory) 
    {
        return itemTransfers[_itemId];
    }
    
    /**
     * @dev Get all items owned by an address
     */
    function getOwnerItems(address _owner) 
        external 
        view 
        returns (uint256[] memory) 
    {
        return ownerItems[_owner];
    }
    
    // Internal functions
    
    /**
     * @dev Remove item from previous owner's list
     */
    function _removeItemFromOwner(address _owner, uint256 _itemId) internal {
        uint256[] storage items_list = ownerItems[_owner];
        for (uint256 i = 0; i < items_list.length; i++) {
            if (items_list[i] == _itemId) {
                items_list[i] = items_list[items_list.length - 1];
                items_list.pop();
                break;
            }
        }
    }
}
