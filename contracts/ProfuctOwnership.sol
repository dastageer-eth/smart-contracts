// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
pragma experimental ABIEncoderV2;

contract ProductOwnership {
    address owner;
   
    struct codeObj {
        uint256 status;
        string brand;
        string model;
        string description;
        string manufactuerName;
        string manufactuerLocation;
        string manufactuerTimestamp;
        string retailer;
        string[] customers;
    }

    // A struct which helps create a new customer
    struct customerObj {
        string name;
        string phone;
        string[] code;
        bool isValue;
    }

    struct retailerObj {
        string name;
        string location;
    }

    mapping(string => codeObj) codeArr;
    mapping(string => customerObj) customerArr;
    mapping(string => retailerObj) retailerArr;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function whoIsOwner() public view returns (address) {
        return owner;
    }

    // Function to create a new code for the product
    function createCode(
        string memory _code,
        string memory _brand,
        string memory _model,
        uint256 _status,
        string memory _description,
        string memory _manufactuerName,
        string memory _manufactuerLocation,
        string memory _manufactuerTimestamp
    ) public payable onlyOwner returns (uint256) {
        codeObj memory newCode;
        newCode.brand = _brand;
        newCode.model = _model;
        newCode.status = _status;
        newCode.description = _description;
        newCode.manufactuerName = _manufactuerName;
        newCode.manufactuerLocation = _manufactuerLocation;
        newCode.manufactuerTimestamp = _manufactuerTimestamp;
        codeArr[_code] = newCode;
        return 1;
    }

    // Function for showing product details if the person scanning the product is not the owner
    function getNotOwnedCodeDetails(
        string memory _code
    )
        public
        view
        returns (
            string memory,
            string memory,
            uint256,
            string memory,
            string memory,
            string memory,
            string memory
        )
    {
        return (
            codeArr[_code].brand,
            codeArr[_code].model,
            codeArr[_code].status,
            codeArr[_code].description,
            codeArr[_code].manufactuerName,
            codeArr[_code].manufactuerLocation,
            codeArr[_code].manufactuerTimestamp
        );
    }

    // Function for showing product details if the person scanning the product is the owner
    function getOwnedCodeDetails(
        string memory _code
    ) public view returns (string memory, string memory) {
        return (
            retailerArr[codeArr[_code].retailer].name,
            retailerArr[codeArr[_code].retailer].location
        );
    }

    // Function for creating a new retailer
    function addRetailerToCode(
        string memory _code,
        string memory _hashedEmailRetailer
    ) public payable returns (uint256) {
        codeArr[_code].retailer = _hashedEmailRetailer;
        return 1;
    }

    // Function for creating a new customer
    function createCustomer(
        string memory _hashedEmail,
        string memory _name,
        string memory _phone
    ) public payable returns (bool) {
        if (customerArr[_hashedEmail].isValue) {
            return false;
        }
        customerObj memory newCustomer;
        newCustomer.name = _name;
        newCustomer.phone = _phone;
        newCustomer.isValue = true;
        customerArr[_hashedEmail] = newCustomer;
        return true;
    }

    function getCustomerDetails(
        string memory _code
    ) public view returns (string memory, string memory) {
        return (customerArr[_code].name, customerArr[_code].phone);
    }

    function createRetailer(
        string memory _hashedEmail,
        string memory _retailerName,
        string memory _retailerLocation
    ) public payable returns (uint256) {
        retailerObj memory newRetailer;
        newRetailer.name = _retailerName;
        newRetailer.location = _retailerLocation;
        retailerArr[_hashedEmail] = newRetailer;
        return 1;
    }

    function getRetailerDetails(
        string memory _code
    ) public view returns (string memory, string memory) {
        return (retailerArr[_code].name, retailerArr[_code].location);
    }

    // Function to report stolen
    function reportStolen(
        string memory _code,
        string memory _customer
    ) public payable returns (bool) {
        uint256 i;
        // Checking if the customer exists
        if (customerArr[_customer].isValue) {
            // Checking if the customer owns the product
            for (i = 0; i < customerArr[_customer].code.length; i++) {
                if (compareStrings(customerArr[_customer].code[i], _code)) {
                    codeArr[_code].status = 2; // Changing the status to stolen
                }
                return true;
            }
        }
        return false;
    }

    function changeOwner(
        string memory _code,
        string memory _oldCustomer,
        string memory _newCustomer
    ) public payable returns (bool) {
        uint256 i;
        bool flag = false;
        //Creating objects for code,oldCustomer,newCustomer
        codeObj memory product = codeArr[_code];
        uint256 len_product_customer = product.customers.length;
        customerObj memory oldCustomer = customerArr[_oldCustomer];
        uint256 len_oldCustomer_code = customerArr[_oldCustomer].code.length;
        customerObj memory newCustomer = customerArr[_newCustomer];

        //Check if oldCustomer and newCustomer have an account
        if (oldCustomer.isValue && newCustomer.isValue) {
            //Check if oldCustomer is owner
            for (i = 0; i < len_oldCustomer_code; i++) {
                if (compareStrings(oldCustomer.code[i], _code)) {
                    flag = true;
                    break;
                }
            }

            if (flag == true) {
                //Swaping oldCustomer with newCustomer in product
                for (i = 0; i < len_product_customer; i++) {
                    if (compareStrings(product.customers[i], _oldCustomer)) {
                        codeArr[_code].customers[i] = _newCustomer;
                        break;
                    }
                }

                // Removing product from oldCustomer
                for (i = 0; i < len_oldCustomer_code; i++) {
                    if (
                        compareStrings(customerArr[_oldCustomer].code[i], _code)
                    ) {
                        remove(i, customerArr[_oldCustomer].code);
                        // Adding product to newCustomer
                        uint256 len = customerArr[_newCustomer].code.length;
                        if (len == 0) {
                            customerArr[_newCustomer].code.push(_code);
                            customerArr[_newCustomer].code.push("hack");
                        } else {
                            customerArr[_newCustomer].code[len - 1] = _code;
                            customerArr[_newCustomer].code.push("hack");
                        }
                        return true;
                    }
                }
            }
        }
        return false;
    }

    function initialOwner(
        string memory _code,
        string memory _retailer,
        string memory _customer
    ) public payable returns (bool) {
        uint256 i;
        if (compareStrings(codeArr[_code].retailer, _retailer)) {
            // Check if retailer owns the prodct
            if (customerArr[_customer].isValue) {
                // Check if Customer has an account
                codeArr[_code].customers.push(_customer); // Adding customer in code
                codeArr[_code].status = 1;
                uint256 len = customerArr[_customer].code.length;
                if (len == 0) {
                    customerArr[_customer].code.push(_code);
                    customerArr[_customer].code.push("hack");
                } else {
                    customerArr[_customer].code[len - 1] = _code;
                    customerArr[_customer].code.push("hack");
                }
                return true;
            }
        }
        return false;
    }

    // Given a customer returns all the product codes he owwns
    function getCodes(
        string memory _customer
    ) public view returns (string[] memory) {
        return customerArr[_customer].code;
    }

    // Cannot directly compare strings in Solidity
    // This function hashes the 2 strings and then compares the 2 hashes
    function compareStrings(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }

    // Function to delete an element from an array
    function remove(
        uint256 index,
        string[] storage array
    ) internal returns (bool) {
        if (index >= array.length) return false;

        for (uint256 i = index; i < array.length - 1; i++) {
            array[i] = array[i + 1];
        }
        delete array[array.length - 1];
        array.pop();
        return true;
    }

    // Function to convert string to bytes32
    function stringToBytes32(
        string memory source
    ) internal pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }
        assembly {
            result := mload(add(source, 32))
        }
    }
}
