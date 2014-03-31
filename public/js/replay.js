/*global _, clone*/
var Replay = function () {
    "use strict";
    function indexOfEqual(arr, el) {
        return _.indexOf(arr, _.find(arr, _.partial(_.isEqual, el)));
    }
    var situation = {};
    this.situation = situation;

    function findPlayer(id) {
        return _.find(situation.players, function (player) { return player.id === id; });
    }

    this.initial_situation = [
        function (e) {
            _.extend(situation, clone(e.situation));
        }
    ];

    this.draw_and_discard_infection_card = [
        function (e) {
            var index = indexOfEqual(situation.infection_cards_draw, e.card),
                removed = situation.infection_cards_draw.splice(index, 1);
            situation.infection_cards_discard.unshift(removed[0]);
        }
    ];

    this.infect = [
        function (e) {
            var location, disease;
            location = _.find(situation.locations,
                function (location) { return location.name === e.location; });
            location.infections[e.disease] = location.infections[e.disease] + 1;
            disease = _.find(situation.diseases,
                function (disease) { return disease.name === e.disease; });
            disease.cubes = disease.cubes - 1;
        }
    ];

    this.treat_disease = [
        function (e) {
            var location, disease;
            location = _.find(situation.locations,
                function (location) { return location.name === e.location; });
            location.infections[e.disease] -= e.number;
            disease = _.find(situation.diseases,
                function (disease) { return disease.name === e.disease; });
            disease.cubes += e.number;
        }
    ];

    this.draw_player_card = [
        function (e) {
            var index = indexOfEqual(situation.player_cards_draw, e.card),
                removed = situation.player_cards_draw.splice(index, 1),
                player = findPlayer(e.player);
            if (e.card.type !== "epidemic") {
                player.hand.push(removed[0]);
            }
        }
    ];

    this.discard_player_card = [
        function (e) {
            var player = findPlayer(e.player),
                index = indexOfEqual(player.hand, e.card),
                removed = player.hand.splice(index, 1);
            situation.player_cards_discard.unshift(removed[0]);
        }
    ];

    this.build_research_center = [
        function (e) {
            situation.research_centers.push({ "location": e.location });
            situation.research_centers_available = situation.research_centers_available - 1;
        }
    ];

    this.discard_discarded_city = [
        function (e) {
            situation.infection_cards_discard = _.filter(situation.infection_cards_discard, function (card) {
                return card.location !== e.location;
            });
        }
    ];

    this.state_change = [
        function (e) {
            situation.state = e.state;
        }
    ];

    this.infection_rate_increased = [
        function (e) {
            situation.infection_rate_index = situation.infection_rate_index + 1;
        }
    ];

    this.infection_cards_restack = [
        function (e) {
            situation.infection_cards_discard = [];
            situation.infection_cards_draw = clone(e.cards).concat(situation.infection_cards_draw);
        }
    ];

    this.outbreak = [
        function (e) {
            situation.outbreak_count = situation.outbreak_count + 1;
        }
    ];

    this.move_pawn = [
        function (e) {
            var player = findPlayer(e.player);
            player.location = e.location;
        }
    ];

    this.discover_cure = [
        function (e) {
            var disease = _.find(situation.diseases,
                    function (disease) { return disease.name === e.disease; });
            disease.status = "cure_discovered";
        }
    ];

    this.eradicate_disease = [
        function (e) {
            var disease = _.find(situation.diseases,
                    function (disease) { return disease.name === e.disease; });
            disease.status = "eradicated";
        }
    ];

    this.transfer_player_card = [
        function (e) {
            var from = findPlayer(e.from_player),
                to = findPlayer(e.to_player),
                index = indexOfEqual(from.hand, e.card),
                card = from.hand.splice(index, 1);
            to.hand.push(card[0]);
        }
    ];

    this.approve_action = [
        function (e) {
            situation.state = situation.state.parent;
        }
    ];

    this.one_quiet_night = [
        function (e) {
            situation.quiet_night = true;
        }
    ];

    this.receive = function (e) {
        _.each(this[e.event_type], function (f) {
            f(e);
        });
    };
};
