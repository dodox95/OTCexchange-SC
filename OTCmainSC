// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OTCMarket is ReentrancyGuard, Ownable {
	struct TokenListing {
		address seller;
		address tokenAddress;
		uint256 amount;
		uint256 price;
	}

	struct EthListing {
		address buyer;
		uint256 amountEth;
		address tokenAddress;
		uint256 tokenAmountWanted;
	}

	struct TokenListingWithId {
		uint256 listingId;
		TokenListing listing;
	}

	struct EthListingWithId {
		uint256 listingId;
		EthListing listing;
	}

	mapping(uint256 => TokenListing) public tokenListings;
	mapping(uint256 => EthListing) public ethListings;

	uint256 public nextTokenListingId;
	uint256 public nextEthListingId;

	event TokenListed(
		uint256 indexed listingId,
		address indexed seller,
		uint256 amount,
		uint256 price
	);
	event EthListed(
		uint256 indexed listingId,
		address indexed buyer,
		uint256 amountEth,
		address tokenAddress,
		uint256 tokenAmountWanted
	);
	event ListingCancelled(uint256 indexed listingId, bool isTokenListing);
	event PurchasedWithToken(
		uint256 indexed listingId,
		address indexed buyer,
		uint256 amount,
		uint256 price
	);
	event PurchasedWithEth(
		uint256 indexed listingId,
		address indexed seller,
		uint256 amountEth
	);

	function listTokenForSale(
		address _tokenAddress,
		uint256 _amount,
		uint256 _price
	) external {
		require(_amount > 0, "Amount must be greater than 0");
		IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
		tokenListings[nextTokenListingId] = TokenListing(
			msg.sender,
			_tokenAddress,
			_amount,
			_price
		);
		emit TokenListed(nextTokenListingId, msg.sender, _amount, _price);
		nextTokenListingId++;
	}

	function listEthForTokens(
		address _tokenAddress,
		uint256 _tokenAmountWanted
	) external payable {
		require(msg.value > 0, "ETH amount must be greater than 0");
		require(_tokenAmountWanted > 0, "Token amount must be greater than 0");
		ethListings[nextEthListingId] = EthListing(
			msg.sender,
			msg.value,
			_tokenAddress,
			_tokenAmountWanted
		);
		emit EthListed(
			nextEthListingId,
			msg.sender,
			msg.value,
			_tokenAddress,
			_tokenAmountWanted
		);
		nextEthListingId++;
	}

	function cancelListing(uint256 _listingId, bool isTokenListing) external {
		if (isTokenListing) {
			TokenListing memory listing = tokenListings[_listingId];
			require(listing.seller == msg.sender, "Not the seller");
			IERC20(listing.tokenAddress).transfer(msg.sender, listing.amount);
			delete tokenListings[_listingId];
		} else {
			EthListing memory listing = ethListings[_listingId];
			require(listing.buyer == msg.sender, "Not the buyer");
			payable(msg.sender).transfer(listing.amountEth);
			delete ethListings[_listingId];
		}
		emit ListingCancelled(_listingId, isTokenListing);
	}

	// Nowa funkcja umożliwiająca właścicielowi anulowanie listingów
	function cancelListingByOwner(
		uint256 _listingId,
		bool isTokenListing
	) external onlyOwner {
		if (isTokenListing) {
			TokenListing storage listing = tokenListings[_listingId];
			require(listing.seller != address(0), "Listing does not exist");
			IERC20(listing.tokenAddress).transfer(
				listing.seller,
				listing.amount
			);
			delete tokenListings[_listingId];
		} else {
			EthListing storage listing = ethListings[_listingId];
			require(listing.buyer != address(0), "Listing does not exist");
			payable(listing.buyer).transfer(listing.amountEth);
			delete ethListings[_listingId];
		}
		emit ListingCancelled(_listingId, isTokenListing);
	}

	function purchaseTokenWithEth(
		uint256 _listingId
	) external payable nonReentrant {
		TokenListing memory listing = tokenListings[_listingId];
		require(msg.value == listing.price, "Incorrect price");
		IERC20(listing.tokenAddress).transfer(msg.sender, listing.amount);
		payable(listing.seller).transfer(msg.value);
		emit PurchasedWithToken(
			_listingId,
			msg.sender,
			listing.amount,
			msg.value
		);
		delete tokenListings[_listingId];
	}

	function purchaseETHWithTokens(
		uint256 ethListingId,
		uint256 tokenAmount
	) external nonReentrant {
		EthListing memory ethListing = ethListings[ethListingId];
		require(
			ethListing.tokenAddress != address(0),
			"ETH listing does not exist"
		);
		require(
			ethListing.tokenAmountWanted <= tokenAmount,
			"Insufficient token amount"
		);

		uint256 ethAmount = ethListing.amountEth;
		address buyer = msg.sender;
		address seller = ethListing.buyer; // W tym kontekście, "kupujący" ETH jest sprzedającym tokeny.

		IERC20(ethListing.tokenAddress).transferFrom(
			buyer,
			seller,
			tokenAmount
		);
		payable(buyer).transfer(ethAmount);

		emit PurchasedWithEth(ethListingId, seller, ethAmount);

		// Usunięcie oferty ETH po zakończeniu transakcji
		delete ethListings[ethListingId];
	}

	// Function to view active token listings
	function getActiveTokenListings()
		external
		view
		returns (TokenListingWithId[] memory)
	{
		uint256 activeCount = 0;
		for (uint256 i = 0; i < nextTokenListingId; i++) {
			if (tokenListings[i].seller != address(0)) {
				activeCount++;
			}
		}

		TokenListingWithId[] memory activeListings = new TokenListingWithId[](
			activeCount
		);
		uint256 currentIndex = 0;
		for (uint256 i = 0; i < nextTokenListingId; i++) {
			if (tokenListings[i].seller != address(0)) {
				activeListings[currentIndex] = TokenListingWithId(
					i,
					tokenListings[i]
				);
				currentIndex++;
			}
		}

		return activeListings;
	}

	// Function to view active ETH listings
	// Zmodyfikowana funkcja w kontrakcie
	function getActiveEthListings()
		external
		view
		returns (EthListingWithId[] memory)
	{
		uint256 activeCount = 0;
		for (uint256 i = 0; i < nextEthListingId; i++) {
			if (ethListings[i].buyer != address(0)) {
				activeCount++;
			}
		}

		EthListingWithId[] memory activeListings = new EthListingWithId[](
			activeCount
		);
		uint256 currentIndex = 0;
		for (uint256 i = 0; i < nextEthListingId; i++) {
			if (ethListings[i].buyer != address(0)) {
				activeListings[currentIndex] = EthListingWithId(
					i,
					ethListings[i]
				);
				currentIndex++;
			}
		}

		return activeListings;
	}
}
