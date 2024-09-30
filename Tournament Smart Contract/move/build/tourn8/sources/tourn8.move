module tourn8_addr::tourn8 {
    use aptos_framework::coin::{Coin, merge, extract, extract_all, destroy_zero};
    use aptos_framework::timestamp;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_std::table::{Self, Table}; 
    use std::vector;
    use std::signer;
    use std::option;
    use std::error;

    // Constants
    const APT_DECIMALS: u64 = 8;
    const OCTA_PER_APT: u64 = 100_000_000; // 1 APT = 100,000,000 octas

    // Reward distribution in basis points (out of 10,000)
    const REWARD_DISTRIBUTION_BASIS_POINTS: vector<u64> = vector[
        5000, 3000, 2000
    ];

    // Error codes for clarity
    const E_TOURNAMENT_EXISTS: u64 = 1;
    const E_PARTICIPANT_ALREADY_JOINED: u64 = 2;
    const E_PARTICIPANT_NOT_FOUND: u64 = 3;
    const E_TOURNAMENT_NOT_ENDED: u64 = 4;
    const E_CREATOR_NOT_REGISTERED: u64 = 5;
    const E_TOURNAMENT_DOES_NOT_EXIST: u64 = 6;
    const E_TOURNAMENT_ALREADY_ENDED: u64 = 7;
    const E_TOURNAMENT_NOT_STARTED: u64 = 8;

    // Struct for Participant
    struct Participant has copy, drop, store {
        account: address,
        userId: u64,
        score: u64,
    }

    // Struct for Tournament
    struct Tournament has store, drop {
        tournamentId: u64,
        participants: vector<Participant>,
        start_time: u64,
        end_time: u64,
        creator: address,
        entry_fee: u64,
        status: u8, // 0 = Not Started, 1 = Active, 2 = Ended
    }

    // Struct for TournamentData (now without PrizePool)
    struct TournamentData has store, drop {
        tournament: Tournament,
    }

    // Struct for PrizePool
    struct PrizePool has store {
        pool: Coin<AptosCoin>,
    }

    // TournamentManager holds separate tables for tournaments and prize pools
    struct TournamentManager has key {
        tournaments: Table<u64, TournamentData>,
        prize_pools: Table<u64, PrizePool>,
    }

    const TOURNAMENT_MANAGER_ADDRESS: address = @tourn8_addr;


    // Initialize the TournamentManager
    
    public entry fun initialize(account: &signer) {
        let addr = signer::address_of(account);
        assert!(addr == TOURNAMENT_MANAGER_ADDRESS, error::permission_denied(100)); // Only module address can initialize
        if (!exists<TournamentManager>(addr)) {
            let tournaments = table::new<u64, TournamentData>();
            let prize_pools = table::new<u64, PrizePool>();  // Initialize the prize pool table
            let manager = TournamentManager { tournaments, prize_pools };
            move_to(account, manager);
        }
    }

    // Start a new tournament
    public entry fun start_new_tournament(
        account: &signer,
        tournamentId: u64,
        prize_pool_amount: u64,
        entry_fee: u64,
        startDate: u64,
        endDate: u64,
        startTime: u64,
        endTime: u64
    ) acquires TournamentManager {
        let manager = borrow_global_mut<TournamentManager>(TOURNAMENT_MANAGER_ADDRESS);

        // Ensure the tournamentId does not already exist
        if (table::contains(&manager.tournaments, tournamentId)) {
            abort(error::invalid_argument(E_TOURNAMENT_EXISTS)) // Tournament ID already exists
        };

        // Parse dates and times
        let (start_year, start_month, start_day) = parse_date(startDate);
        let (start_hour, start_minute) = parse_time(startTime);
        let start_time = date_time_to_timestamp_microseconds(start_year, start_month, start_day, start_hour, start_minute);

        let (end_year, end_month, end_day) = parse_date(endDate);
        let (end_hour, end_minute) = parse_time(endTime);
        let end_time = date_time_to_timestamp_microseconds(end_year, end_month, end_day, end_hour, end_minute);

        // Ensure end time is after start time
        assert!(end_time > start_time, error::invalid_argument(9)); // End time must be after start time

        // Initialize empty participants vector
        let participants = vector::empty<Participant>();

        // Create Tournament
        let tournament = Tournament {
            tournamentId: tournamentId,
            participants: participants,
            start_time: start_time,
            end_time: end_time,
            creator: signer::address_of(account),
            entry_fee: entry_fee,
            status: 0, // Not Started
        };

        // Create TournamentData and add it to the table
        let tournament_data = TournamentData { tournament };
        table::add(&mut manager.tournaments, tournamentId, tournament_data);

        // Create and store the PrizePool separately
        let prize_pool_coin = aptos_framework::coin::withdraw<AptosCoin>(account, prize_pool_amount);
        let prize_pool = PrizePool { pool: prize_pool_coin };
        table::add(&mut manager.prize_pools, tournamentId, prize_pool);
    }



        // Allow a participant to enter a tournament with an entry fee
    public entry fun enter_tournament(
        participant: &signer,
        tournamentId: u64,
        userId: u64
    ) acquires TournamentManager {
        let manager = borrow_global_mut<TournamentManager>(TOURNAMENT_MANAGER_ADDRESS);

        // Check if the tournament exists
        if (!table::contains(&manager.tournaments, tournamentId)) {
            abort(error::not_found(E_TOURNAMENT_DOES_NOT_EXIST)) // Tournament does not exist
        };

        let tournament_data = table::borrow_mut(&mut manager.tournaments, tournamentId);
        let tournament = &mut tournament_data.tournament;
        let prize_pool = table::borrow_mut(&mut manager.prize_pools, tournamentId);

        let current_time = timestamp::now_microseconds();

        // Ensure the tournament has not ended
        assert!(current_time < tournament.end_time, error::invalid_state(E_TOURNAMENT_ALREADY_ENDED));

        // Ensure the tournament has started
        if (current_time < tournament.start_time) {
            abort(error::invalid_state(E_TOURNAMENT_NOT_STARTED)) // Tournament has not started yet
        };

        // Ensure the tournament is active
        if (tournament.status == 0 && current_time >= tournament.start_time) {
            tournament.status = 1; // Set to Active
        };
        assert!(tournament.status == 1, error::invalid_state(E_TOURNAMENT_ALREADY_ENDED));

        // Check if participant is already in the tournament
        let participant_addr = signer::address_of(participant);
        let existing_index = find_participant(tournament, participant_addr);
        assert!(!option::is_some(&existing_index), error::already_exists(E_PARTICIPANT_ALREADY_JOINED));

        // Withdraw entry fee from participant
        let entry_fee_coin = aptos_framework::coin::withdraw<AptosCoin>(participant, tournament.entry_fee);

        // Add entry fee to prize pool
        merge(&mut prize_pool.pool, entry_fee_coin);

        // Add the new participant to the tournament
        let new_participant: Participant = Participant {
            account: participant_addr,
            userId: userId,
            score: 0,
        };
        vector::push_back(&mut tournament.participants, new_participant);
    }

    // Record a participant's score in the tournament
    public entry fun record_score(
        participant: &signer, 
        tournamentId: u64, 
        score: u64
    ) acquires TournamentManager {
        let manager = borrow_global_mut<TournamentManager>(TOURNAMENT_MANAGER_ADDRESS);

        // Check if the tournament exists
        if (!table::contains(&manager.tournaments, tournamentId)) {
            abort(error::not_found(E_TOURNAMENT_DOES_NOT_EXIST)) // Tournament does not exist
        };

        let tournament_data = table::borrow_mut(&mut manager.tournaments, tournamentId);
        let tournament = &mut tournament_data.tournament;

        let current_time = timestamp::now_microseconds();

        // Ensure the tournament is active
        assert!(tournament.status == 1, error::invalid_state(E_TOURNAMENT_ALREADY_ENDED));

        // Ensure the tournament has not ended
        assert!(current_time < tournament.end_time, error::invalid_state(E_TOURNAMENT_ALREADY_ENDED));

        let participant_addr: address = signer::address_of(participant);

        // Find the index of the participant in the participants list
        let index: option::Option<u64> = find_participant(tournament, participant_addr);
        assert!(option::is_some(&index), error::not_found(E_PARTICIPANT_NOT_FOUND)); // Ensure the participant is in the tournament

        // Update the participant's score and userId
        let idx: u64 = *option::borrow(&index);
        let participant_record: &mut Participant = vector::borrow_mut(&mut tournament.participants, idx);
        participant_record.score = participant_record.score + score;
        //participant_record.userId = userId; // Update userId if necessary
    }


        // End the tournament and distribute rewards
    public entry fun end_tournament(tournamentId: u64) acquires TournamentManager {
        let manager = borrow_global_mut<TournamentManager>(TOURNAMENT_MANAGER_ADDRESS);

        // Check if the tournament exists
        if (!table::contains(&manager.tournaments, tournamentId)) {
            abort(error::not_found(E_TOURNAMENT_DOES_NOT_EXIST)) // Tournament does not exist
        };

        let tournament_data = table::borrow_mut(&mut manager.tournaments, tournamentId);
        let tournament = &mut tournament_data.tournament;
        let prize_pool = table::borrow_mut(&mut manager.prize_pools, tournamentId);

        let current_time = timestamp::now_microseconds();

        // Ensure the tournament has ended
        assert!(current_time >= tournament.end_time, error::invalid_state(E_TOURNAMENT_NOT_ENDED));

        // Ensure the tournament is active
        assert!(tournament.status != 2, error::invalid_state(E_TOURNAMENT_ALREADY_ENDED));

        // Set tournament status to ended
        tournament.status = 2;

        // Sort the participants by score
        let sorted_participants: vector<Participant> = sort_participants(&tournament.participants);

        let total_prize_pool: u64 = aptos_framework::coin::value(&prize_pool.pool);
        let rewards: vector<u64> = calculate_rewards(total_prize_pool);

        // Distribute rewards to participants
        let i: u64 = 0;
        while (i < vector::length(&sorted_participants) && i < vector::length(&rewards)) {
            let participant: &Participant = vector::borrow(&sorted_participants, i);
            let reward_amount: u64 = *vector::borrow(&rewards, i);

            // Check if participant has registered CoinStore
            if (!aptos_framework::coin::is_account_registered<aptos_framework::aptos_coin::AptosCoin>(participant.account)) {
                i = i + 1;
                continue
            };

            // Extract the reward from the prize pool and deposit it into the participant's account
            let reward_coin: Coin<AptosCoin> = extract(&mut prize_pool.pool, reward_amount);
            aptos_framework::coin::deposit(participant.account, reward_coin);
            i = i + 1;
        };

        // Handle remaining coins after distributing rewards
        let remaining_coin: Coin<AptosCoin> = extract_all(&mut prize_pool.pool);

        // Return remaining prize pool to the tournament creator
        if (aptos_framework::coin::value(&remaining_coin) > 0) {
            if (!aptos_framework::coin::is_account_registered<aptos_framework::aptos_coin::AptosCoin>(tournament.creator)) {
                abort(error::invalid_state(E_CREATOR_NOT_REGISTERED)) // Creator has not registered CoinStore
            };
            aptos_framework::coin::deposit(tournament.creator, remaining_coin);
        } else {
            destroy_zero(remaining_coin);
        };

        // At this point, the prize pool is emptied, and we don't need to remove it from the table
        // because we have handled the internal Coin<AptosCoin>. The data is simply left in place.

        // Remove the tournament from the manager
        table::remove(&mut manager.tournaments, tournamentId);
    }



    // View function to get the leaderboard of a tournament
    #[view]
    public fun get_leaderboard(tournamentId: u64): vector<Participant> acquires TournamentManager {
        let manager = borrow_global<TournamentManager>(TOURNAMENT_MANAGER_ADDRESS);

        // Check if the tournament exists
        if (!table::contains(&manager.tournaments, tournamentId)) {
            return vector::empty<Participant>() // Tournament does not exist
        };

        let tournament_data = table::borrow(&manager.tournaments, tournamentId);
        let tournament = &tournament_data.tournament;

        // Return sorted participants
        let sorted_participants = sort_participants(&tournament.participants);
        sorted_participants
    }


    // View function to get tournament information
    #[view]
    public fun get_tournament_info(tournamentId: u64): (u64, u64, u64, address, u64, u64, u8) acquires TournamentManager {
        let manager = borrow_global<TournamentManager>(TOURNAMENT_MANAGER_ADDRESS);

        // Check if the tournament exists
        if (!table::contains(&manager.tournaments, tournamentId)) {
            abort(error::not_found(E_TOURNAMENT_DOES_NOT_EXIST)) // Tournament does not exist
        };

        let tournament_data = table::borrow(&manager.tournaments, tournamentId);
        let tournament = &tournament_data.tournament;
        let prize_pool = table::borrow(&manager.prize_pools, tournamentId);

        let num_participants = vector::length(&tournament.participants);
        let start_time = tournament.start_time;
        let end_time = tournament.end_time;
        let creator = tournament.creator;
        let entry_fee = tournament.entry_fee;
        let prize_pool_amount = aptos_framework::coin::value(&prize_pool.pool);
        let status = tournament.status;

        (start_time, end_time, num_participants, creator, entry_fee, prize_pool_amount, status)
    }

    // View function to get a participant's score given userId and tournamentId
    #[view]
    public fun get_participant_score(tournamentId: u64, userId: u64): u64 acquires TournamentManager {
        let manager = borrow_global<TournamentManager>(TOURNAMENT_MANAGER_ADDRESS);

        // Check if the tournament exists
        if (!table::contains(&manager.tournaments, tournamentId)) {
            return 0 // Tournament does not exist
        };

        let tournament_data = table::borrow(&manager.tournaments, tournamentId);
        let tournament = &tournament_data.tournament;

        let participants = &tournament.participants;
        let length = vector::length(participants);
        let i: u64 = 0;

        while (i < length) {
            let participant = vector::borrow(participants, i);
            if (participant.userId == userId) {
                return participant.score
            };
            i = i + 1;
        };

        0 // Participant not found
    }

    // Calculate rewards based on the total prize pool
    fun calculate_rewards(total_prize_pool: u64): vector<u64> {
        let rewards: vector<u64> = vector::empty<u64>();
        let i: u64 = 0;
        while (i < vector::length(&REWARD_DISTRIBUTION_BASIS_POINTS)) {
            let basis_points: u64 = *vector::borrow(&REWARD_DISTRIBUTION_BASIS_POINTS, i);
            let reward: u64 = (total_prize_pool * basis_points) / 10_000;
            vector::push_back(&mut rewards, reward);
            i = i + 1;
        };
        rewards
    }

    // Sort participants by score in descending order
    fun sort_participants(participants: &vector<Participant>): vector<Participant> {
        let sorted: vector<Participant> = vector::empty<Participant>();
        let len: u64 = vector::length(participants);
        let i: u64 = 0;
        while (i < len) {
            let item: &Participant = vector::borrow(participants, i);
            vector::push_back(&mut sorted, *item);
            i = i + 1;
        };

        // Simple bubble sort
        let i: u64 = 0;
        while (i < vector::length(&sorted)) {
            let j: u64 = i + 1;
            while (j < vector::length(&sorted)) {
                if (vector::borrow(&sorted, j).score > vector::borrow(&sorted, i).score) {
                    let temp: Participant = *vector::borrow(&sorted, i);
                    *vector::borrow_mut(&mut sorted, i) = *vector::borrow(&sorted, j);
                    *vector::borrow_mut(&mut sorted, j) = temp;
                };
                j = j + 1;
            };
            i = i + 1;
        };

        sorted
    }

    // Helper function to find a participant by address in the tournament
    fun find_participant(tournament: &Tournament, addr: address): option::Option<u64> {
        let participants = &tournament.participants;
        let length = vector::length(participants);
        let i: u64 = 0;

        while (i < length) {
            let participant: &Participant = vector::borrow(participants, i);
            if (participant.account == addr) {
                return option::some(i)  // Return the index of the participant
            };
            i = i + 1;
        };

        option::none<u64>() // Return none if the participant is not found
    }

    // Function to parse date in "yyyyMMdd" format
    fun parse_date(date_int: u64): (u64, u64, u64) {
        let year: u64 = date_int / 10_000;
        let month_day: u64 = date_int % 10_000;
        let month: u64 = month_day / 100;
        let day: u64 = month_day % 100;
        (year, month, day)
    }

    // Function to parse time in "HHmm" format
    fun parse_time(time_int: u64): (u64, u64) {
        let hour: u64 = time_int / 100;
        let minute: u64 = time_int % 100;
        (hour, minute)
    }

    // Check if a year is a leap year
    fun is_leap_year(year: u64): bool {
        ((year % 4 == 0) && (year % 100 != 0)) || (year % 400 == 0)
    }

    // Get the number of days in a month
    fun days_in_month(year: u64, month: u64): u64 {
        if (month == 2) {
            if (is_leap_year(year)) { 29 } else { 28 }
        } else if (month == 4 || month == 6 || month == 9 || month == 11) {
            30
        } else {
            31
        }
    }

    // Calculate total days since epoch (1970-01-01)
    fun total_days_since_epoch(year: u64, month: u64, day: u64): u64 {
        let total_days: u64 = 0;
        let y: u64 = 1970;
        while (y < year) {
            total_days = total_days + if (is_leap_year(y)) { 366 } else { 365 };
            y = y + 1;
        };

        let m: u64 = 1;
        while (m < month) {
            total_days = total_days + days_in_month(year, m);
            m = m + 1;
        };

        total_days = total_days + (day - 1);
        total_days
    }

    // Convert date and time to timestamp in microseconds since epoch
    fun date_time_to_timestamp_microseconds(year: u64, month: u64, day: u64, hour: u64, minute: u64): u64 {
        let total_days: u64 = total_days_since_epoch(year, month, day);
        let total_seconds: u64 = total_days * 86_400 + hour * 3600 + minute * 60;
        let timestamp_microseconds: u64 = total_seconds * 1_000_000;
        timestamp_microseconds
    }
}


