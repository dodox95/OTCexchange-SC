// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract OTCMarket is ReentrancyGuard {
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

	function purchaseTokenWithListing(
		uint256 _ethListingId,
		uint256 _tokenListingId
	) external nonReentrant {
		EthListing memory ethListing = ethListings[_ethListingId];
		TokenListing memory tokenListing = tokenListings[_tokenListingId];
		require(ethListing.buyer == msg.sender, "Not the eth listing buyer");
		require(
			ethListing.tokenAddress == tokenListing.tokenAddress,
			"Different token addresses"
		);
		require(
			ethListing.tokenAmountWanted == tokenListing.amount,
			"Token amount mismatch"
		);
		require(
			ethListing.amountEth == tokenListing.price,
			"ETH amount mismatch"
		);
		// Transfer tokens to the ETH listing's buyer
		IERC20(tokenListing.tokenAddress).transfer(
			ethListing.buyer,
			tokenListing.amount
		);
		// Transfer ETH to the token listing's seller
		payable(tokenListing.seller).transfer(ethListing.amountEth);

		emit PurchasedWithEth(
			_ethListingId,
			tokenListing.seller,
			ethListing.amountEth
		);

		// Clean up the listings after the purchase
		delete ethListings[_ethListingId];
		delete tokenListings[_tokenListingId];
	}

	// Function to view active token listings
	function getActiveTokenListings()
		external
		view
		returns (TokenListing[] memory)
	{
		uint256 activeCount = 0;
		for (uint256 i = 0; i < nextTokenListingId; i++) {
			if (tokenListings[i].seller != address(0)) {
				activeCount++;
			}
		}

		TokenListing[] memory activeListings = new TokenListing[](activeCount);
		uint256 currentIndex = 0;
		for (uint256 i = 0; i < nextTokenListingId; i++) {
			if (tokenListings[i].seller != address(0)) {
				activeListings[currentIndex] = tokenListings[i];
				currentIndex++;
			}
		}

		return activeListings;
	}

	// Function to view active ETH listings
	function getActiveEthListings()
		external
		view
		returns (EthListing[] memory)
	{
		uint256 activeCount = 0;
		for (uint256 i = 0; i < nextEthListingId; i++) {
			if (ethListings[i].buyer != address(0)) {
				activeCount++;
			}
		}

		EthListing[] memory activeListings = new EthListing[](activeCount);
		uint256 currentIndex = 0;
		for (uint256 i = 0; i < nextEthListingId; i++) {
			if (ethListings[i].buyer != address(0)) {
				activeListings[currentIndex] = ethListings[i];
				currentIndex++;
			}
		}

		return activeListings;
	}
}
