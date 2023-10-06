//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract HotelReservation {
    struct Registry {
        string guestName;
        uint256 roomAllocated;
        uint256 checkInDate;
        uint256 checkOutDate;
        bytes signature;
    }

    struct UserInformation {
        address registrantAddress;
        string registrantName;
        string[] guestNames;
        uint256[] guestAges;
        string[] homeAddress;
        bytes32[] signatures;
    }

    struct Room {
        uint256 roomId;
        uint256 roomNumber;
        uint256 price;
        string name;
        string hotelName;
        string location;
        bool status;
    }

    address public owner;

    mapping(uint256 => Room) public roomDetails;
    mapping(uint256 => Registry) public registryDetails;
    mapping(uint256 => UserInformation) public customerDetails;

    event RoomAdded(
        uint256 id,
        uint256 number,
        uint256 price,
        string name,
        string hotelName,
        string location,
        bool status
    );

    event ReservationConfirmed(
        address registrantAddress,
        string registrantName
    );

    event ConfirmCheckIn(
        string guestName,
        uint256 checkInDate,
        uint256 checkOutDate
    );

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setRoomDetails(
        uint256 roomId_,
        uint256 roomNumber_,
        uint256 price_,
        string memory name_,
        string memory hotelName_,
        string memory location_
    ) external onlyOwner returns (bool) {
        roomDetails[roomId_].roomId = roomId_;
        roomDetails[roomId_].roomNumber = roomNumber_;
        roomDetails[roomId_].price = price_;
        roomDetails[roomId_].name = name_;
        roomDetails[roomId_].hotelName = hotelName_;
        roomDetails[roomId_].location = location_;
        emit RoomAdded(
            roomId_,
            roomNumber_,
            price_,
            name_,
            hotelName_,
            location_,
            false
        );
        return true;
    }

    function initateBooking(
        uint256 roomId_,
        string memory registrantName_,
        string[] memory guestNames_,
        uint256[] memory guestAges_,
        string[] memory homeAddress_,
        bytes32[] memory signatures_
    ) external payable returns (bool) {
        uint256 cost = (roomDetails[roomId_].price * 10) / 100;
        require(cost != 0, "HR: Price not set");
        require(msg.value == cost, "HR: Didn't send complete amount require");
        require(roomId_ != 0, "HR: RoomId cannot be null or zero");
        require(
            roomDetails[roomId_].status == false,
            "HR: Room already reserved"
        );
        customerDetails[roomId_].registrantAddress = msg.sender;
        customerDetails[roomId_].registrantName = registrantName_;
        customerDetails[roomId_].guestNames = guestNames_;
        customerDetails[roomId_].guestAges = guestAges_;
        customerDetails[roomId_].homeAddress = homeAddress_;
        customerDetails[roomId_].signatures = signatures_;
        payable(address(this)).transfer(msg.value);
        emit ReservationConfirmed(msg.sender, registrantName_);
        return true;
    }

    function checkIn(
        uint256 roomId_,
        uint256 startDate_,
        uint256 durationOfStay_,
        bytes memory signature
    ) external payable onlyOwner returns (bool) {
        address signer = customerDetails[roomId_].registrantAddress;
        uint256 amount = roomDetails[roomId_].price -
            (roomDetails[roomId_].price * 10) /
            100;
        uint256 endDate = startDate_ + (durationOfStay_ * 86400);
        string memory guestName = customerDetails[roomId_].registrantName;
        require(
            verify(roomId_, signer, signature) == true,
            "HR: You are not the registrant of this Room"
        );
        require(
            msg.value == amount,
            "HR: Didn't pay complete amount for registration"
        );
        registryDetails[roomId_].guestName = customerDetails[roomId_]
            .registrantName;
        registryDetails[roomId_].checkInDate = startDate_;
        registryDetails[roomId_].checkOutDate = endDate;
        registryDetails[roomId_].signature = signature;
        roomDetails[roomId_].status = true;
        payable(address(this)).transfer(msg.value);
        emit ConfirmCheckIn(guestName, startDate_, endDate);
        return true;
    }

    function checkOut(
        uint256 roomId_,
        bytes memory signature
    ) external onlyOwner returns (bool) {
        address signer = customerDetails[roomId_].registrantAddress;
        require(
            verify(roomId_, signer, signature) == true,
            "HR: You are not the registrant of this Room"
        );
        roomDetails[roomId_].status = false;
        return true;
    }

    function getMessageHash(uint256 roomId_) internal view returns (bytes32) {
        address registrantAddress = customerDetails[roomId_].registrantAddress;
        string memory name = customerDetails[roomId_].registrantName;
        string[] memory guestName = customerDetails[roomId_].guestNames;
        uint256[] memory guestAge = customerDetails[roomId_].guestAges;
        string[] memory homeAddress = customerDetails[roomId_].homeAddress;
        return
            keccak256(
                abi.encodePacked(
                    registrantAddress,
                    name,
                    guestName[0],
                    guestAge[0],
                    homeAddress[0]
                )
            );
    }

    function getEthSignedMessageHash(
        uint256 roomId_
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    getMessageHash(roomId_)
                )
            );
    }

    function splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function verify(
        uint256 roomId_,
        address _signer,
        bytes memory signature
    ) internal view returns (bool) {
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(roomId_);
        return recoverSigner(ethSignedMessageHash, signature) == _signer;
    }

    function withdraw() external payable onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}
