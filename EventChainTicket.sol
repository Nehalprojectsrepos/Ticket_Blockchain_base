// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract EventChainTickets is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _eventIdCounter;

    struct EventInfo {
        address host;
        string title;
        uint256 date;
        uint256 priceInWei;
        uint256 totalTickets;
        uint256 ticketsSold;
        bool active;
    }

    mapping(uint256 => EventInfo) public events;         // eventId => EventInfo
    mapping(uint256 => uint256) public ticketToEvent;    // tokenId => eventId

    // 🔔 Events
    event EventCreated(uint256 indexed eventId, address indexed host, string title, uint256 totalTickets);
    event TicketPurchased(uint256 indexed eventId, uint256 indexed tokenId, address indexed buyer);

    constructor() ERC721("EventChainTicket", "ECT") {}

    /**
     * @dev Create a new event with a given title, date, price, and ticket count.
     */
    function createEvent(
        string memory _title,
        uint256 _date,
        uint256 _priceInWei,
        uint256 _totalTickets
    ) external {
        require(_date > block.timestamp, "Event date must be in the future");
        require(_priceInWei > 0, "Price must be greater than 0");
        require(_totalTickets > 0, "Total tickets must be > 0");

        _eventIdCounter.increment();
        uint256 newEventId = _eventIdCounter.current();

        events[newEventId] = EventInfo({
            host: msg.sender,
            title: _title,
            date: _date,
            priceInWei: _priceInWei,
            totalTickets: _totalTickets,
            ticketsSold: 0,
            active: true
        });

        emit EventCreated(newEventId, msg.sender, _title, _totalTickets);
    }

    /**
     * @dev Buy 1 ticket for a specific event by paying ETH.
     */
    function buyTicket(uint256 _eventId) external payable {
        EventInfo storage e = events[_eventId];

        require(e.active, "Event not active");
        require(block.timestamp < e.date, "Event has already occurred");
        require(e.ticketsSold < e.totalTickets, "No tickets left");
        require(msg.value == e.priceInWei, "Incorrect ETH amount");

        // Mint a new NFT as a ticket
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();

        _safeMint(msg.sender, newTokenId);
        ticketToEvent[newTokenId] = _eventId;

        e.ticketsSold++;

        // Pay the event host
        payable(e.host).transfer(msg.value);

        emit TicketPurchased(_eventId, newTokenId, msg.sender);
    }

    /**
     * @dev Transfer a ticket (token) to another address.
     * This calls the standard safeTransferFrom internally.
     */
    function transferTicket(address from, address to, uint256 tokenId) external {
        require(_isApprovedOrOwner(msg.sender, tokenId), "Not authorized");
        safeTransferFrom(from, to, tokenId);
    }

    /**
     * @dev Return total number of events created.
     */
    function _eventIdCounterValue() external view returns (uint256) {
        return _eventIdCounter.current();
    }

    /**
     * @dev Helper to get details of an event (used by frontend).
     */
    function getEventDetails(uint256 _eventId)
        external
        view
        returns (
            address host,
            string memory title,
            uint256 date,
            uint256 price,
            uint256 total,
            uint256 sold,
            bool active
        )
    {
        EventInfo memory e = events[_eventId];
        return (e.host, e.title, e.date, e.priceInWei, e.totalTickets, e.ticketsSold, e.active);
    }

    /**
     * @dev Host can deactivate an event (e.g. cancel).
     */
    function deactivateEvent(uint256 _eventId) external {
        EventInfo storage e = events[_eventId];
        require(msg.sender == e.host, "Only host can deactivate");
        e.active = false;
    }
}
