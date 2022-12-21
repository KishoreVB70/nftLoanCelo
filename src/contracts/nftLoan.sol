//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NftLoan is ReentrancyGuard, IERC721Receiver {
    /// @param amountToBeRepayed is the amount after interest
    /// @param loanDuration in minutes for testing purpose
    struct Loan {
        //Amount in celo
        uint256 loanAmount;
        uint256 interest;
        uint256 amountToBeRepayed;
        uint256 nftId;
        uint256 loanDuration;
        uint256 loanDurationEndTimestamp;
        address nftAddress;
        address payable borrower;
        address payable lender;
        Status status;
    }

    enum Status {
        Open,
        Loaned,
        Closed
    }

    mapping(uint256 => Loan) private loanList;

    using Counters for Counters.Counter;

    Counters.Counter private loanId;

    //Modifiers

    modifier exists(uint256 _loanId) {
        require(_loanId < loanId.current(), "loan does not exist");
        _;
    }

    modifier onlyBorrower(uint256 _loanId) {
        require(
            msg.sender == loanList[_loanId].borrower,
            "Only the borrower can access this function"
        );
        _;
    }

    modifier isOpen(uint256 _loanId) {
        require(loanList[_loanId].status == Status.Open, "Loan is not Open");
        _;
    }

    modifier isLoaned(uint256 _loanId) {
        require(
            loanList[_loanId].status == Status.Loaned,
            "The loan is not in loaned state"
        );
        _;
    }

    //Events
    event newLoan(address borrower, uint256 indexed loanId);

    event loaned(
        address borrower,
        address lender,
        uint256 indexed loanId,
        uint256 loanAmount
    );

    event requestClosed(address borrower, uint256 indexed loanId);

    event loanRepayed(
        address borrower,
        address lender,
        uint256 indexed loanId,
        uint256 loanAmount
    );

    event nftCeased(address borrower, address lender, uint256 indexed loanId);

    //----------------------------------------------------------------------------------------------------------------------

    /// @dev users makes a loan request by transferring his nft to the contract
    /// @param _loanDuration in minutes for testing purpose
    function askForLoan(
        uint256 _nftId,
        address _nft,
        uint256 _amount,
        uint256 _loanDuration,
        uint256 _interest
    ) public nonReentrant {
        require(
            _loanDuration > 0,
            "Loan duration needs to be at least one minute"
        );
        require(
            _nft != address(0),
            "Address zero is not a valid contract's address"
        );
        IERC721(_nft).transferFrom(msg.sender, address(this), _nftId);
        uint256 amountToBeRepayed = _amount +
            calculateInterestAmount(_amount, _interest);
        uint256 _loanId = loanId.current();
        loanId.increment();
        loanList[_loanId] = Loan(
            _amount,
            _interest,
            amountToBeRepayed,
            _nftId,
            _loanDuration,
            0, // loanDurationEndTimestamp initialized as zero
            _nft,
            payable(msg.sender),
            payable(address(0)), // loan's lender initialized as the zero address
            Status.Open
        );
        emit newLoan(msg.sender, _loanId);
    }

    /// @dev Other users can view the request details and lend money
    function lendMoney(uint256 _loanId)
        public
        payable
        exists(_loanId)
        isOpen(_loanId)
    {
        Loan storage loan = loanList[_loanId];
        require(msg.sender != loan.borrower, "You cannot loan yourself");
        require(msg.value == loan.loanAmount, "send correct loanAmount");
        loan.loanDurationEndTimestamp =
            block.timestamp +
            loan.loanDuration *
            1 minutes;
        loan.lender = payable(msg.sender);
        loan.status = Status.Loaned;
        (bool success, ) = loan.borrower.call{value: msg.value}("");
        require(success, "Payment to buy lot failed");
        emit loaned(loan.borrower, loan.lender, _loanId, loan.loanAmount);
    }

    /// @dev If no user lends money, the borrower can close the request and get their NFT back
    function closeBorrowRequest(uint256 _loanId)
        public
        exists(_loanId)
        onlyBorrower(_loanId)
        isOpen(_loanId)
        nonReentrant
    {
        Loan storage loan = loanList[_loanId];
        IERC721(loan.nftAddress).transferFrom(
            address(this),
            msg.sender,
            loan.nftId
        );
        loan.status = Status.Closed;
        emit requestClosed(msg.sender, _loanId);
    }

    /// @dev  borrower can return the money and get his NFT back
    function repayLoan(uint256 _loanId)
        public
        payable
        exists(_loanId)
        onlyBorrower(_loanId)
        isLoaned(_loanId)
        nonReentrant
    {
        Loan storage loan = loanList[_loanId];
        require(
            loan.loanDurationEndTimestamp > block.timestamp,
            "Loan duration Ended"
        );
        require(msg.value == loan.amountToBeRepayed, "send correct loanAmount");
        (bool success, ) = loan.lender.call{value: msg.value}("");
        require(success, "Payment to buy lot failed");
        IERC721(loan.nftAddress).transferFrom(
            address(this),
            msg.sender,
            loan.nftId
        );
        loan.status = Status.Closed;
        emit loanRepayed(msg.sender, loan.lender, _loanId, loan.loanAmount);
    }

    /// @dev If the borrower fails to pay back the money, after the loan duration ends, the nft is transfered the lender
    function ceaseNft(uint256 _loanId)
        public
        exists(_loanId)
        isLoaned(_loanId)
    {
        Loan storage loan = loanList[_loanId];
        require(msg.sender == loan.lender, "Only the lender can cease the NFT");
        require(
            loan.loanDurationEndTimestamp < block.timestamp,
            "Loan duration not over"
        );
        loan.status = Status.Closed;
        IERC721(loan.nftAddress).transferFrom(
            address(this),
            msg.sender,
            loan.nftId
        );
        emit nftCeased(loan.borrower, loan.lender, _loanId);
    }

    /// @dev helper function to calculate the percentage interest
    function calculateInterestAmount(uint256 x, uint256 y)
        public
        pure
        returns (uint256)
    {
        require(x >= 1 ether, "Loan amount needs to be at least one CUSD");
        uint256 a = x / 100;
        return a * y;
    }

    /// @dev View funciton that returns the required details of the loan
    function getDetails(uint256 _loanId)
        public
        view
        exists(_loanId)
        returns (
            uint256 loanAmount,
            uint256 interest,
            uint256 amountToBeRepayed,
            uint256 nftId,
            uint256 loanDuration,
            uint256 loanDurationEndTimestamp,
            address nftAddress,
            address payable borrowerAddress,
            address payable lenderAddress,
            Status status
        )
    {
        Loan storage loan = loanList[_loanId];
        return (
            loan.loanAmount,
            loan.interest,
            loan.amountToBeRepayed,
            loan.nftId,
            loan.loanDuration,
            loan.loanDurationEndTimestamp,
            loan.nftAddress,
            loan.borrower,
            loan.lender,
            loan.status
        );
    }

    /// @dev View the Id
    function getId() public view returns (uint256 id) {
        return loanId.current();
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return bytes4(this.onERC721Received.selector);
    }
}
