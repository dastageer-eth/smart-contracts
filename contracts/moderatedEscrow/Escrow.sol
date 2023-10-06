// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Utils/Mappings.sol";
import "./Utils/Events.sol";
import "./Interface/IEscrow.sol";
import "./Interface/IModerator.sol";

contract Escrow is IEscrow, Ownable, Mappings {
    using SafeMath for uint256;

    address public moderatorAddress;

    IModerator public moderatorContract;

    uint256 private maxAppNum;
    uint256 public maxOrderId;

    constructor(address _modAddress) public {
        moderatorAddress = _modAddress;
        moderatorContract = IModerator(_modAddress);
    }

    function getModAddress() external view returns (address) {
        return moderatorAddress;
    }

    // get total apps quantity
    function getTotalAppsQuantity() public view returns (uint256) {
        return maxAppNum;
    }

    // get app owner
    function getAppOwner(uint256 appId) public view returns (address) {
        return appOwner[appId];
    }

    modifier onlyAppOwner() {
        require(
            _msgSender() == appOwner[appId],
            "Escrow: only app owner can call this function"
        );
        _;
    }

    //Create new APP
    function newApp(
        address _appOwner,
        string memory _appName,
        string memory websiteURI
    ) public onlyOwner returns (uint256) {
        uint256 appId = maxAppNum + 1;
        appOwner[appId] = _appOwner;
        appURI[appId] = websiteURI;
        appName[appId] = _appName;
        appIntervalDispute[appId] = uint256(1000000);
        appIntervalClaim[appId] = uint256(1000000);
        appIntervalRefuse[appId] = uint256(86400);
        appModCommission[appId] = uint8(1);
        appOwnerCommission[appId] = uint8(1);
        maxAppNum = appId;
        emit NewApp(appId);

        return appId;
    }

    //Transfer app owner to a new address
    function setAppOwner(
        uint256 appId,
        address _newOwner
    ) public onlyAppOwner returns (bool) {
        require(
            _newOwner != address(0),
            "Escrow: new owner is the zero address"
        );
        appOwner[appId] = _newOwner;

        return true;
    }

    //Set mod commission
    //Only app owner
    function setModCommission(
        uint256 appId,
        uint8 _commission
    ) public onlyAppOwner returns (bool) {
        require(_commission < 15, "Escrow: commission must be less than 15");
        appModCommission[appId] = _commission;
        return true;
    }

    //Set app owner commission
    function setAppOwnerCommission(
        uint256 appId,
        uint8 _commission
    ) public onlyAppOwner returns (bool) {
        require(_commission < 45, "Escrow: commission must be less than 45");
        appOwnerCommission[appId] = _commission;
        return true;
    }

    //Set dispute interval
    function setIntervalDispute(
        uint256 appId,
        uint256 _seconds
    ) public onlyAppOwner returns (bool) {
        require(_seconds > 10, "Escrow: interval time too small!");
        require(_seconds < 10000000, "Escrow: interval time too big!");
        appIntervalDispute[appId] = _seconds;
        return true;
    }

    //Set refuse interval
    function setIntervalRefuse(
        uint256 appId,
        uint256 _seconds
    ) public onlyAppOwner returns (bool) {
        require(_seconds > 10, "Escrow: interval time too small!");
        require(_seconds < 10000000, "Escrow: interval time too big!");
        appIntervalRefuse[appId] = _seconds;
        return true;
    }

    //Set claim interval
    function setIntervalClaim(
        uint256 appId,
        uint256 _seconds
    ) public onlyAppOwner returns (bool) {
        require(_seconds > 20, "Escrow: interval time too small!");
        require(_seconds < 10000000, "Escrow: interval time too big!");
        appIntervalClaim[appId] = _seconds;
        return true;
    }

    function getMaxModId() public view returns (uint256) {
        return moderatorContract.getMaxModId();
    }

    function getModOwner(uint256 modId) public view returns (address) {
        return moderatorContract.getModOwner(modId);
    }

    //Pay Order
    function payOrder(
        uint256 appId,
        uint256 amount,
        address coinAddress,
        address seller,
        uint256 appOrderId,
        uint256 modAId
    ) public payable returns (uint256) {
        require(
            appId > 0 && appId <= maxAppNum && appOrderId > 0 && amount > 0,
            "Escrow: all the ids should be bigger than 0"
        );
        //Mod Id should be validated
        require(
            modAId <= moderatorContract.getMaxModId(),
            "Escrow: mod id is too big"
        );
        //Native Currency
        if (coinAddress == address(0)) {
            require(
                msg.value == amount,
                "Escrow: Wrong amount or wrong value sent"
            );
            //send native currency to this contract
            address(this).transfer(amount);
        } else {
            IERC20 buyCoinContract = IERC20(coinAddress);
            //send ERC20 to this contract
            buyCoinContract.transferFrom(_msgSender(), address(this), amount);
        }
        maxOrderId = maxOrderId + 1;
        // store order information
        Order memory _order;
        _order.appId = appId;
        _order.coinAddress = coinAddress;
        _order.amount = amount;
        _order.buyer = _msgSender();
        _order.seller = seller;
        _order.createdTime = block.timestamp;
        _order.claimTime = block.timestamp + appIntervalClaim[appId];
        _order.status = uint8(1);
        _order.modAId = modAId;
        orderBook[maxOrderId] = _order;

        // emit event
        emit PayOrder(
            maxOrderId,
            appOrderId,
            coinAddress,
            amount,
            _msgSender(),
            seller,
            appId,
            modAId
        );

        return maxOrderId;
    }

    //confirm order received, and money will be sent to seller's balance
    //triggled by buyer
    function confirmDone(uint256 orderId) public {
        require(
            _msgSender() == orderBook[orderId].buyer,
            "Escrow: only buyer can confirm done"
        );

        require(
            orderBook[orderId].status == uint8(1) ||
                orderBook[orderId].status == uint8(2) ||
                orderBook[orderId].status == uint8(4),
            "Escrow: order status must be equal to just paid or refund asked or dispute refused"
        );

        // send money to seller's balance
        userBalance[orderBook[orderId].seller][orderBook[orderId].coinAddress] =
            userBalance[orderBook[orderId].seller][
                orderBook[orderId].coinAddress
            ] +
            (orderBook[orderId].amount);
        emit UserBalanceChanged(
            orderBook[orderId].seller,
            true,
            orderBook[orderId].amount,
            orderBook[orderId].coinAddress,
            orderBook[orderId].appId,
            orderId
        );

        // set order status to completed
        orderBook[orderId].status == uint8(3);

        //emit event
        emit ConfirmDone(orderBook[orderId].appId, orderId);
    }

    //ask refund
    //triggled by buyer
    function askRefund(uint256 orderId, uint256 refund, uint256 modBId) public {
        require(
            _msgSender() == orderBook[orderId].buyer,
            "Escrow: only buyer can make dispute"
        );

        require(
            orderBook[orderId].status == uint8(1) ||
                orderBook[orderId].status == uint8(2),
            "Escrow: order status must be equal to just paid or refund asked"
        );

        require(
            block.timestamp <
                orderBook[orderId].createdTime +
                    (appIntervalDispute[orderBook[orderId].appId]),
            "Escrow: it is too late to make dispute"
        );

        require(
            refund > 0 && refund <= orderBook[orderId].amount,
            "Escrow: refund amount must be bigger than 0 and not bigger than paid amount"
        );

        require(
            modBId > 0 && modBId <= moderatorContract.getMaxModId(),
            "Escrow: modB id does not exists"
        );

        // update order status
        if (orderBook[orderId].status == uint8(1)) {
            orderBook[orderId].status = uint8(2);
        }
        // update refund of dispute
        disputeBook[orderId].refund = refund;
        // update modBId of dispute
        disputeBook[orderId].modBId = modBId;
        // update refuse expired
        disputeBook[orderId].refuseExpired =
            block.timestamp +
            (appIntervalRefuse[orderBook[orderId].appId]);
        //emit event
        emit AskRefund(orderBook[orderId].appId, orderId, refund);
    }

    //cancel refund
    //triggled by buyer
    function cancelRefund(uint256 orderId) public {
        require(
            _msgSender() == orderBook[orderId].buyer,
            "Escrow: only buyer can cancel refund"
        );

        require(
            orderBook[orderId].status == uint8(2) ||
                orderBook[orderId].status == uint8(4),
            "Escrow: order status must be equal to refund asked or refund refused"
        );

        //update order status to paid
        orderBook[orderId].status = uint8(1);

        emit CancelRefund(orderBook[orderId].appId, orderId);
    }

    //refuse refund
    //triggled by seller
    function refuseRefund(uint256 orderId) public {
        require(
            _msgSender() == orderBook[orderId].seller,
            "Escrow: only seller can refuse dispute"
        );

        require(
            orderBook[orderId].status == uint8(2),
            "Escrow: order status must be equal to refund asked"
        );

        //update order status to refund refused
        orderBook[orderId].status = uint8(4);

        emit RefuseRefund(orderBook[orderId].appId, orderId);
    }

    //escalate, so mods can vote
    //triggled by seller or buyer
    function escalate(uint256 orderId) public {
        require(
            _msgSender() == orderBook[orderId].seller ||
                _msgSender() == orderBook[orderId].buyer,
            "Escrow: only seller or buyer can escalate"
        );

        require(
            orderBook[orderId].status == uint8(4),
            "Escrow: order status must be equal to refund refused by seller"
        );

        //update order status to escalate dispute, ready for mods to vote
        orderBook[orderId].status = uint8(5);

        emit Escalate(orderBook[orderId].appId, orderId);
    }

    // if seller agreed refund, then refund immediately
    // otherwise let mods or appOwner(if need) to judge

    function agreeRefund(uint256 orderId) public {
        //if seller agreed refund, then refund immediately
        if (_msgSender() == orderBook[orderId].seller) {
            require(
                orderBook[orderId].status == uint8(2) ||
                    orderBook[orderId].status == uint8(4) ||
                    orderBook[orderId].status == uint8(5),
                "Escrow: order status must be at refund asked or refund refused or dispute esclated"
            );
            sellerAgree(orderId);
        } else {
            require(
                orderBook[orderId].status == uint8(5),
                "Escrow: mod can only vote on dispute escalated status"
            );
            // get the mod's owner wallet address
            address modAWallet = moderatorContract.getModOwner(
                orderBook[orderId].modAId
            );
            address modBWallet = moderatorContract.getModOwner(
                disputeBook[orderId].modBId
            );
            // if modA's owner equal to modB's owner and they are msg sender
            if (modAWallet == modBWallet && modAWallet == _msgSender()) {
                // set modAResolution/modBResolution to voted
                orderModAResolution[orderId] = uint8(1);
                orderModBResolution[orderId] = uint8(1);
                resolvedFinally(orderId, true);
                emit Resolve(
                    _msgSender(),
                    true,
                    orderId,
                    orderBook[orderId].appId,
                    uint8(0)
                );
            }
            // if voter is app owner , and modA/modB not agree with each other.
            else if (
                appOwner[orderBook[orderId].appId] == _msgSender() &&
                ((orderModAResolution[orderId] == uint8(1) &&
                    orderModBResolution[orderId] == uint8(2)) ||
                    (orderModAResolution[orderId] == uint8(2) &&
                        orderModBResolution[orderId] == uint8(1)))
            ) {
                resolvedFinally(orderId, true);
                emit Resolve(
                    _msgSender(),
                    true,
                    orderId,
                    orderBook[orderId].appId,
                    uint8(3)
                );
            }
            // if voter is modA, and modA not vote yet, and modB not vote or vote disagree
            else if (
                modAWallet == _msgSender() &&
                orderModAResolution[orderId] == uint8(0) &&
                (orderModBResolution[orderId] == uint8(0) ||
                    orderModBResolution[orderId] == uint8(2))
            ) {
                // set modAResolution to voted
                orderModAResolution[orderId] = uint8(1);
                emit Resolve(
                    _msgSender(),
                    true,
                    orderId,
                    orderBook[orderId].appId,
                    uint8(1)
                );
            }
            // if voter is modA, and modA not vote yet, and modB vote agree
            else if (
                modAWallet == _msgSender() &&
                orderModAResolution[orderId] == uint8(0) &&
                orderModBResolution[orderId] == uint8(1)
            ) {
                // set modAResolution to voted
                orderModAResolution[orderId] = uint8(1);
                resolvedFinally(orderId, true);
                emit Resolve(
                    _msgSender(),
                    true,
                    orderId,
                    orderBook[orderId].appId,
                    uint8(1)
                );
            }
            // if voter is modB, and modB not vote yet, and modA not vote or vote disagree
            else if (
                modBWallet == _msgSender() &&
                orderModBResolution[orderId] == uint8(0) &&
                (orderModAResolution[orderId] == uint8(0) ||
                    orderModAResolution[orderId] == uint8(2))
            ) {
                // set modBResolution to voted
                orderModBResolution[orderId] = uint8(1);
                emit Resolve(
                    _msgSender(),
                    true,
                    orderId,
                    orderBook[orderId].appId,
                    uint8(2)
                );
            }
            // if voter is modB, and modB not vote yet, and modA vote agree
            else if (
                modBWallet == _msgSender() &&
                orderModBResolution[orderId] == uint8(0) &&
                orderModAResolution[orderId] == uint8(1)
            ) {
                // set modBResolution to voted
                orderModBResolution[orderId] = uint8(1);
                resolvedFinally(orderId, true);
                emit Resolve(
                    _msgSender(),
                    true,
                    orderId,
                    orderBook[orderId].appId,
                    uint8(2)
                );
            }
            // in other case , revert
            else {
                revert("Escrow: sender can not vote!");
            }
        }
    }

    // the _msgSender() does not agree the refund

    function disagreeRefund(uint256 orderId) public {
        require(
            orderBook[orderId].status == uint8(5),
            "Escrow: mod can only vote on dispute escalated status"
        );
        // get the mod's owner wallet address
        address modAWallet = moderatorContract.getModOwner(
            orderBook[orderId].modAId
        );
        address modBWallet = moderatorContract.getModOwner(
            disputeBook[orderId].modBId
        );
        // if modA's owner equal to modB's owner and they are msg sender
        if (modAWallet == modBWallet && modAWallet == _msgSender()) {
            // set modAResolution/modBResolution to voted
            orderModAResolution[orderId] = uint8(2);
            orderModBResolution[orderId] = uint8(2);
            resolvedFinally(orderId, false);
            emit Resolve(
                _msgSender(),
                false,
                orderId,
                orderBook[orderId].appId,
                uint8(0)
            );
        }
        // if voter is app owner , and modA/modB not agree with each other.
        else if (
            appOwner[orderBook[orderId].appId] == _msgSender() &&
            ((orderModAResolution[orderId] == uint8(2) &&
                orderModBResolution[orderId] == uint8(1)) ||
                (orderModAResolution[orderId] == uint8(1) &&
                    orderModBResolution[orderId] == uint8(2)))
        ) {
            resolvedFinally(orderId, false);
            emit Resolve(
                _msgSender(),
                false,
                orderId,
                orderBook[orderId].appId,
                uint8(3)
            );
        }
        // if voter is modA, and modA not vote yet, and modB not vote or vote agree
        else if (
            modAWallet == _msgSender() &&
            orderModAResolution[orderId] == uint8(0) &&
            (orderModBResolution[orderId] == uint8(0) ||
                orderModBResolution[orderId] == uint8(1))
        ) {
            // set modAResolution to voted
            orderModAResolution[orderId] = uint8(2);
            emit Resolve(
                _msgSender(),
                false,
                orderId,
                orderBook[orderId].appId,
                uint8(1)
            );
        }
        // if voter is modA, and modA not vote yet, and modB vote disagree
        else if (
            modAWallet == _msgSender() &&
            orderModAResolution[orderId] == uint8(0) &&
            orderModBResolution[orderId] == uint8(2)
        ) {
            // set modAResolution to voted
            orderModAResolution[orderId] = uint8(2);
            resolvedFinally(orderId, false);
            emit Resolve(
                _msgSender(),
                false,
                orderId,
                orderBook[orderId].appId,
                uint8(1)
            );
        }
        // if voter is modB, and modB not vote yet, and modA not vote or vote agree
        else if (
            modBWallet == _msgSender() &&
            orderModBResolution[orderId] == uint8(0) &&
            (orderModAResolution[orderId] == uint8(0) ||
                orderModAResolution[orderId] == uint8(1))
        ) {
            // set modBResolution to voted
            orderModBResolution[orderId] = uint8(2);
            emit Resolve(
                _msgSender(),
                false,
                orderId,
                orderBook[orderId].appId,
                uint8(2)
            );
        }
        // if voter is modB, and modB not vote yet, and modA vote disagree
        else if (
            modBWallet == _msgSender() &&
            orderModBResolution[orderId] == uint8(0) &&
            orderModAResolution[orderId] == uint8(2)
        ) {
            // set modBResolution to voted
            orderModBResolution[orderId] = uint8(2);
            resolvedFinally(orderId, false);
            emit Resolve(
                _msgSender(),
                false,
                orderId,
                orderBook[orderId].appId,
                uint8(2)
            );
        }
        // in other case , revert
        else {
            revert("Escrow: sender can not vote!");
        }
    }

    // if seller agreed refund, then refund immediately

    function sellerAgree(uint256 orderId) internal {
        require(_msgSender() == orderBook[orderId].seller);
        // update order status to finish
        orderBook[orderId].status = uint8(3);
        // final commission is the app owner commission
        uint8 finalCommission = appOwnerCommission[orderBook[orderId].appId];
        // add app ownner commission fee
        userBalance[appOwner[orderBook[orderId].appId]][
            orderBook[orderId].coinAddress
        ] =
            userBalance[appOwner[orderBook[orderId].appId]][
                orderBook[orderId].coinAddress
            ] +
            ((orderBook[orderId].amount * (finalCommission)) / 100);
        emit UserBalanceChanged(
            appOwner[orderBook[orderId].appId],
            true,
            (orderBook[orderId].amount * (finalCommission)) / 100,
            orderBook[orderId].coinAddress,
            orderBook[orderId].appId,
            orderId
        );
        // as the refund is approved, refund to buyer
        userBalance[orderBook[orderId].buyer][orderBook[orderId].coinAddress] =
            userBalance[orderBook[orderId].buyer][
                orderBook[orderId].coinAddress
            ] +
            ((disputeBook[orderId].refund * (100 - finalCommission)) / 100);
        emit UserBalanceChanged(
            orderBook[orderId].buyer,
            true,
            (disputeBook[orderId].refund * (100 - finalCommission)) / 100,
            orderBook[orderId].coinAddress,
            orderBook[orderId].appId,
            orderId
        );
        // if there is amount left, then send left amount to seller
        if (orderBook[orderId].amount > disputeBook[orderId].refund) {
            userBalance[orderBook[orderId].seller][
                orderBook[orderId].coinAddress
            ] =
                userBalance[orderBook[orderId].seller][
                    orderBook[orderId].coinAddress
                ] +
                (((orderBook[orderId].amount - (disputeBook[orderId].refund)) *
                    (100 - finalCommission)) / 100);
            emit UserBalanceChanged(
                orderBook[orderId].seller,
                true,
                ((orderBook[orderId].amount - (disputeBook[orderId].refund)) *
                    (100 - finalCommission)) / 100,
                orderBook[orderId].coinAddress,
                orderBook[orderId].appId,
                orderId
            );
        }
        emit ResolvedFinally(orderBook[orderId].appId, orderId, uint8(1));
    }

    function resolvedFinally(uint256 orderId, bool result) internal {
        // update order status to finish
        orderBook[orderId].status = uint8(3);

        // the mod who judge right decision will increase 1 score, as well as adding the mod commission
        uint8 modNum = 1;
        uint8 winResolve = result ? 1 : 2;
        // get the mod's owner wallet address
        address modAWallet = moderatorContract.getModOwner(
            orderBook[orderId].modAId
        );
        address modBWallet = moderatorContract.getModOwner(
            disputeBook[orderId].modBId
        );
        // if modA's owner equal to modB's owner, then just increase 1 success score for the owner
        // and add the mod commission
        if (modAWallet == modBWallet) {
            rewardMod(orderId, orderBook[orderId].modAId, modAWallet);
        }
        // else if modA does not agree with modB
        else if (orderModAResolution[orderId] != orderModBResolution[orderId]) {
            modNum = 2;
            // anyway app owner will get the mod commission
            userBalance[appOwner[orderBook[orderId].appId]][
                orderBook[orderId].coinAddress
            ] =
                userBalance[appOwner[orderBook[orderId].appId]][
                    orderBook[orderId].coinAddress
                ] +
                ((orderBook[orderId].amount *
                    (appModCommission[orderBook[orderId].appId])) / 100);
            // the mod who vote the same as final result will give award
            if (orderModAResolution[orderId] == winResolve) {
                rewardMod(orderId, orderBook[orderId].modAId, modAWallet);
                moderatorContract.updateModScore(
                    disputeBook[orderId].modBId,
                    false
                );
            } else {
                rewardMod(orderId, disputeBook[orderId].modBId, modBWallet);
                moderatorContract.updateModScore(
                    orderBook[orderId].modAId,
                    false
                );
            }
        }
        // else if modA agree with modB
        else {
            // give both mods reward
            modNum = 2;
            rewardMod(orderId, orderBook[orderId].modAId, modAWallet);
            rewardMod(orderId, disputeBook[orderId].modBId, modBWallet);
        }
        // caculate the commission fee
        uint8 finalCommission = appOwnerCommission[orderBook[orderId].appId] +
            (modNum * appModCommission[orderBook[orderId].appId]);
        // send app owner commission fee
        userBalance[appOwner[orderBook[orderId].appId]][
            orderBook[orderId].coinAddress
        ] =
            userBalance[appOwner[orderBook[orderId].appId]][
                orderBook[orderId].coinAddress
            ] +
            ((orderBook[orderId].amount *
                (appOwnerCommission[orderBook[orderId].appId])) / 100);
        emit UserBalanceChanged(
            appOwner[orderBook[orderId].appId],
            true,
            (orderBook[orderId].amount *
                (appOwnerCommission[orderBook[orderId].appId])) / 100,
            orderBook[orderId].coinAddress,
            orderBook[orderId].appId,
            orderId
        );
        //if result is to refund, then refund to buyer, the left will be sent to seller
        //else all paid to the seller

        if (result == true) {
            // as the refund is approved, refund to buyer
            userBalance[orderBook[orderId].buyer][
                orderBook[orderId].coinAddress
            ] =
                userBalance[orderBook[orderId].buyer][
                    orderBook[orderId].coinAddress
                ] +
                ((disputeBook[orderId].refund * (100 - finalCommission)) / 100);
            emit UserBalanceChanged(
                orderBook[orderId].buyer,
                true,
                (disputeBook[orderId].refund * (100 - finalCommission)) / 100,
                orderBook[orderId].coinAddress,
                orderBook[orderId].appId,
                orderId
            );
            // if there is amount left, then send left amount to seller
            if (orderBook[orderId].amount > disputeBook[orderId].refund) {
                userBalance[orderBook[orderId].seller][
                    orderBook[orderId].coinAddress
                ] =
                    userBalance[orderBook[orderId].seller][
                        orderBook[orderId].coinAddress
                    ] +
                    (((orderBook[orderId].amount -
                        (disputeBook[orderId].refund)) *
                        (100 - finalCommission)) / 100);
                emit UserBalanceChanged(
                    orderBook[orderId].seller,
                    true,
                    ((orderBook[orderId].amount -
                        (disputeBook[orderId].refund)) *
                        (100 - finalCommission)) / 100,
                    orderBook[orderId].coinAddress,
                    orderBook[orderId].appId,
                    orderId
                );
            }
            emit ResolvedFinally(orderBook[orderId].appId, orderId, uint8(1));
        } else {
            // send all the amount to the seller
            userBalance[orderBook[orderId].seller][
                orderBook[orderId].coinAddress
            ] =
                userBalance[orderBook[orderId].seller][
                    orderBook[orderId].coinAddress
                ] +
                ((orderBook[orderId].amount * (100 - finalCommission)) / 100);
            emit UserBalanceChanged(
                orderBook[orderId].seller,
                true,
                (orderBook[orderId].amount * (100 - finalCommission)) / 100,
                orderBook[orderId].coinAddress,
                orderBook[orderId].appId,
                orderId
            );
            emit ResolvedFinally(orderBook[orderId].appId, orderId, uint8(0));
        }
    }

    // reward mod
    // adding mod commission as well as increasing mod score

    function rewardMod(uint256 orderId, uint256 modId, address mod) private {
        moderatorContract.updateModScore(modId, true);
        userBalance[mod][orderBook[orderId].coinAddress] =
            userBalance[mod][orderBook[orderId].coinAddress] +
            ((orderBook[orderId].amount *
                (appModCommission[orderBook[orderId].appId])) / 100);
        emit UserBalanceChanged(
            mod,
            true,
            (orderBook[orderId].amount *
                (appModCommission[orderBook[orderId].appId])) / 100,
            orderBook[orderId].coinAddress,
            orderBook[orderId].appId,
            orderId
        );
    }

    //seller want to claim money from order to balance
    //or
    //buyer want to claim money after seller either not to refuse dispute or agree dispute

    function claim(uint256 orderId) public {
        // final commission is the app owner commission
        uint8 finalCommission = appOwnerCommission[orderBook[orderId].appId];
        // add app ownner commission fee
        userBalance[appOwner[orderBook[orderId].appId]][
            orderBook[orderId].coinAddress
        ] =
            userBalance[appOwner[orderBook[orderId].appId]][
                orderBook[orderId].coinAddress
            ] +
            ((orderBook[orderId].amount * (finalCommission)) / 100);
        emit UserBalanceChanged(
            appOwner[orderBook[orderId].appId],
            true,
            (orderBook[orderId].amount * (finalCommission)) / 100,
            orderBook[orderId].coinAddress,
            orderBook[orderId].appId,
            orderId
        );
        //seller claim
        if (_msgSender() == orderBook[orderId].seller) {
            require(
                orderBook[orderId].status == uint8(1),
                "Escrow: order status must be equal to 1 "
            );

            require(
                block.timestamp > orderBook[orderId].claimTime,
                "Escrow: currently seller can not claim, need to wait"
            );
            // send all the amount to the seller
            userBalance[orderBook[orderId].seller][
                orderBook[orderId].coinAddress
            ] =
                userBalance[orderBook[orderId].seller][
                    orderBook[orderId].coinAddress
                ] +
                ((orderBook[orderId].amount * (100 - finalCommission)) / 100);
            emit UserBalanceChanged(
                orderBook[orderId].seller,
                true,
                (orderBook[orderId].amount * (100 - finalCommission)) / 100,
                orderBook[orderId].coinAddress,
                orderBook[orderId].appId,
                orderId
            );
        } else if (_msgSender() == orderBook[orderId].buyer) {
            // buyer claim

            require(
                orderBook[orderId].status == uint8(2),
                "Escrow: order status must be equal to 2 "
            );

            require(
                block.timestamp > disputeBook[orderId].refuseExpired,
                "Escrow: currently buyer can not claim, need to wait"
            );
            // refund to buyer
            userBalance[orderBook[orderId].buyer][
                orderBook[orderId].coinAddress
            ] =
                userBalance[orderBook[orderId].buyer][
                    orderBook[orderId].coinAddress
                ] +
                ((disputeBook[orderId].refund * (100 - finalCommission)) / 100);
            emit UserBalanceChanged(
                orderBook[orderId].buyer,
                true,
                (disputeBook[orderId].refund * (100 - finalCommission)) / 100,
                orderBook[orderId].coinAddress,
                orderBook[orderId].appId,
                orderId
            );
            // if there is amount left, then send left amount to seller
            if (orderBook[orderId].amount > disputeBook[orderId].refund) {
                userBalance[orderBook[orderId].seller][
                    orderBook[orderId].coinAddress
                ] =
                    userBalance[orderBook[orderId].seller][
                        orderBook[orderId].coinAddress
                    ] +
                    (((orderBook[orderId].amount -
                        (disputeBook[orderId].refund)) *
                        (100 - finalCommission)) / 100);
                emit UserBalanceChanged(
                    orderBook[orderId].seller,
                    true,
                    ((orderBook[orderId].amount -
                        (disputeBook[orderId].refund)) *
                        (100 - finalCommission)) / 100,
                    orderBook[orderId].coinAddress,
                    orderBook[orderId].appId,
                    orderId
                );
            }
        } else {
            revert("Escrow: only seller or buyer can claim");
        }

        orderBook[orderId].status = 3;
        emit Claim(_msgSender(), orderBook[orderId].appId, orderId);
    }

    //withdraw from user balance
    function withdraw(uint256 _amount, address _coinAddress) public {
        //get user balance
        uint256 _balance = userBalance[_msgSender()][_coinAddress];

        require(_balance >= _amount, "Escrow: insufficient balance!");

        //descrease user balance
        userBalance[_msgSender()][_coinAddress] = _balance - (_amount);

        //if the coin type is ETH
        if (_coinAddress == address(0)) {
            //check balance is enough
            require(
                address(this).balance > _amount,
                "Escrow: insufficient balance"
            );

            _msgSender().transfer(_amount);
        } else {
            //if the coin type is ERC20

            IERC20 _token = IERC20(_coinAddress);

            _token.transfer(_msgSender(), _amount);
        }

        //emit withdraw event
        emit Withdraw(_msgSender(), _amount, _coinAddress);
    }

    receive() external payable;
}
