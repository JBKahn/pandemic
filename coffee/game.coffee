Game = (eventSink, randy) ->
  player_actions_state = (player) ->
    name: "player_actions"
    player: player
    actions_remaining: 4
    terminal: false
  "use strict"
  @situation = null
  @findLocation = (locationName) ->
    _.findWhere @situation.locations,
      name: locationName


  @findDisease = (diseaseName) ->
    _.findWhere @situation.diseases,
      name: diseaseName


  @findDiseaseByLocation = (locationName) ->
    diseaseName = @findLocation(locationName).disease
    @findDisease diseaseName

  @findPlayer = (playerId) ->
    _.findWhere @situation.players,
      id: playerId


  @emitStateChange = ->
    eventSink.emit
      event_type: "state_change"
      state: _.clone(@situation.state)

    return

  @enterDrawState = (player, number) ->
    if @situation.player_cards_draw.length is 0
      @situation.state =
        name: "defeat_out_of_player_cards"
        terminal: true
    else
      @situation.state =
        name: "draw_player_cards"
        player: player
        draws_remaining: number
        terminal: false
    @emitStateChange()
    return

  @drawPlayerCard = (player) ->
    card = @situation.player_cards_draw.shift()
    eventSink.emit
      event_type: "draw_player_card"
      player: player
      card: card

    @situation.state.draws_remaining = @situation.state.draws_remaining - 1
    return @handleEpidemic()  if card.type is "epidemic"
    @findPlayer(player).hand.push card
    return @handleHandLimitExceeded(player)  if @findPlayer(player).hand.length > @situation.max_player_cards
    true

  @handleEpidemic = ->
    @situation.infection_rate_index = @situation.infection_rate_index + 1
    eventSink.emit event_type: "infection_rate_increased"
    return false  unless @drawInfection(3, true)
    @situation.state =
      name: "epidemic"
      player: @situation.state.player
      parent: @situation.state
      terminal: false

    @emitStateChange()
    true

  @handleHandLimitExceeded = (player) ->
    @situation.state =
      name: "hand_limit_exceeded"
      player: player
      parent: @situation.state
      terminal: false

    @emitStateChange()
    true

  @infect = (loc, dis, num) ->
    _infect = (locs, dis, out) ->
      disease = self.findDisease(dis)
      return true  if disease.status is "eradicated"
      return true  if _.isEmpty(locs)
      cur_loc = _.first(locs)
      location = self.findLocation(cur_loc)
      
      # If an outbreak already occurred here, skip
      return _infect(_.rest(locs), dis, out)  if _.contains(out, cur_loc)
      
      # Outbreak
      if location.infections[dis] is max_infections
        eventSink.emit
          event_type: "outbreak"
          location: cur_loc
          disease: dis

        self.situation.outbreak_count = self.situation.outbreak_count + 1
        if self.situation.outbreak_count > self.situation.max_outbreaks
          self.situation.state =
            name: "defeat_too_many_outbreaks"
            terminal: true

          self.emitStateChange()
          return false
        return _infect(_.rest(locs).concat(location.adjacent), dis, out.concat([cur_loc]))
      
      # Out of cubes
      if disease.cubes is 0
        self.situation.state =
          name: "defeat_too_many_infections"
          disease: dis
          terminal: true

        self.emitStateChange()
        return false
      
      # Infection
      location.infections[dis] = location.infections[dis] + 1
      disease.cubes = disease.cubes - 1
      eventSink.emit
        event_type: "infect"
        location: cur_loc
        disease: dis

      _infect _.rest(locs), dis, out
    max_infections = 3
    self = this
    _infect _.times(num, ->
      loc
    ), dis, []

  @drawInfection = (n, last) ->
    if last
      card = @situation.infection_cards_draw.pop()
    else
      card = @situation.infection_cards_draw.shift()
    @situation.infection_cards_discard.unshift card
    eventSink.emit
      event_type: "draw_and_discard_infection_card"
      card: card

    location = @findLocation(card.location)
    @infect location.name, location.disease, n

  @startInfectionPhase = (player) ->
    if @situation.quiet_night is true
      @situation.quiet_night = false
      players = @situation.players
      index = _.indexOf(players, _.find(players, (p) ->
        p.id is player
      ))
      nextPlayer = (if index + 1 is players.length then players[0] else players[index + 1])
      @situation.state =
        name: "player_actions"
        player: nextPlayer.id
        actions_remaining: 4
        terminal: false
    else
      rate = @situation.infection_rate_levels[@situation.infection_rate_index].rate
      @situation.state =
        name: "draw_infection_cards"
        player: player
        draws_remaining: rate
        terminal: false
    @emitStateChange()
    return

  @resume = (situation) ->
    throw "Game already initialized!"  unless _.isNull(@situation)
    @situation = clone(situation)
    return

  @setup = (gameDef, players, settings) ->
    
    # assign roles
    
    # create initial research center
    
    # shuffle infection cards
    
    # shuffle player cards and insert epidemic cards
    setupPlayerCards = ->
 
 
 
 
 
 
 
 
 
 
      cards = randy.shuffle(gameDef.player_cards_draw)
      nEpidemics = settings.number_of_epidemics
      if nEpidemics > 0
        initialDeal = gameDef.initial_player_cards[players.length]
        nReserved = initialDeal * players.length
        nCards = gameDef.player_cards_draw.length
        n = nCards - nReserved
        chunkSize = Math.floor(n / nEpidemics)
        larger = n - (nEpidemics * chunkSize)
        counts = _.times(nEpidemics, (index) ->
          chunkSize + ((if index < larger then 1 else 0))
        )
        chunks = _.map(counts, (count) ->
          chunk = [
            this.index
            @index + count
          ]
          @index += count
          chunk
        ,
          index: nReserved
        )
        return _.reduce(chunks, (memo, chunk, index) ->
          where = randy.randInt(chunk[0], chunk[1])
          memo.concat(cards.slice(chunk[0], where)).concat([
            type: "epidemic"
            number: index
          ]).concat cards.slice(where, chunk[1])
        , cards.slice(0, nReserved))
      cards
    throw "Game already initialized!"  unless _.isNull(@situation)
    initialState = _.extend(clone(gameDef), settings)
    roles = _.map(gameDef.roles, (role) ->
      role.name
    )
    roles = randy.sample(roles, players.length)
    initialState.players = _.map(_.zip(players, roles), (arr) ->
      player = _.object([
        "id"
        "role"
      ], arr)
      player.location = gameDef.starting_location
      player.hand = []
      player
    )
    initialState.research_centers.push location: gameDef.starting_location
    initialState.research_centers_available = initialState.research_centers_available - 1
    initialState.infection_cards_draw = randy.shuffle(gameDef.infection_cards_draw)
    initialState.player_cards_draw = setupPlayerCards()
    initialState.state =
      name: "setup"
      terminal: false

    
    # Make the initial state known
    eventSink.emit
      event_type: "initial_situation"
      situation: initialState

    @situation = clone(initialState)
    self = this
    
    # Initial infections
    _.each initialState.initial_infections, (n) ->
      self.drawInfection n
      return

    
    # Initial draws
    nDraw = gameDef.initial_player_cards[players.length]
    _.each _.range(nDraw), ->
      _.each self.situation.players, (player) ->
        self.drawPlayerCard player.id
        return

      return

    
    # Give turn to first player
    @situation.state = player_actions_state(self.situation.players[0].id)
    @emitStateChange()
    return

  @resumeDrawPlayerCards = ->
    parent = @situation.state.parent
    throw "invalid state"  if parent.name isnt "draw_player_cards"
    if parent.draws_remaining > 0
      @enterDrawState parent.player, parent.draws_remaining
    else
      @startInfectionPhase parent.player
    return

  @resumePlayerActions = ->
    throw "invalid state"  if @situation.state.parent.name isnt "player_actions"
    @situation.state = @situation.state.parent
    @situation.state.actions_remaining = @situation.state.actions_remaining - 1
    if @situation.state.actions_remaining is 0
      @enterDrawState @situation.state.player, 2
    else
      @emitStateChange()
    return

  @discardPlayerCard = (player, card) ->
    thePlayer = @findPlayer(player)
    eventSink.emit
      event_type: "discard_player_card"
      player: player
      card: card

    thePlayer.hand.splice _.indexOf(thePlayer.hand, card), 1
    @situation.player_cards_discard.unshift card
    return

  @requestApproval = (player, other, action) ->
    @situation.state =
      name: "approve_action"
      player: player
      approve_player: other
      approve_action: action
      parent: @situation.state
      terminal: false

    @emitStateChange()
    return

  @is_not_dispatcher_and_other_player_selected = (player, action) ->
    thePlayer = @findPlayer(player)
    return true  if player isnt action.player and thePlayer.role isnt "Dispatcher"
    false

  @is_valid_player = (player) ->
    playerObject = @findPlayer(player)
    unless playerObject
      console.log "Invalid player ", player
      return false
    true

  @check_action_prerequisites = (player, action) ->
    if action.name.match(/^action_/)
      return false  if @situation.state.name isnt "player_actions"
      return false  if player isnt @situation.state.player
    switch action.name
      when "refuse_action", "approve_action"
        return false  if (@situation.state.name isnt "approve_action") or (@situation.state.approve_player isnt player)
      when "action_drive"
        return false  if @is_not_dispatcher_and_other_player_selected(player, action) or not @is_valid_player(action.player)
        movedPlayerObject = @findPlayer(action.player)
        source = @findLocation(movedPlayerObject.location)
        return false  unless _.contains(source.adjacent, action.location)
      when "action_charter_flight"
        thePlayer = @findPlayer(player)
        return false  if @is_not_dispatcher_and_other_player_selected(player, action)
        movedPlayerObject = @findPlayer(action.player)
        return false  if movedPlayerObject.location is action.location
        return false  unless @getCard(thePlayer.hand, "location", thePlayer.location)
      when "action_direct_flight"
        thePlayer = @findPlayer(player)
        return false  if @is_not_dispatcher_and_other_player_selected(player, action)
        movedPlayerObject = @findPlayer(action.player)
        return false  if movedPlayerObject.location is action.location
        return false  unless @getCard(thePlayer.hand, "location", action.location)
      when "action_shuttle_flight"
        return false  if @is_not_dispatcher_and_other_player_selected(player, action)
        movedPlayerObject = @findPlayer(action.player)
        origin = movedPlayerObject.location
        destination = action.location
        return false  if origin is destination
        return false  unless _.find(@situation.research_centers, (center) ->
          center.location is origin
        )
        return false  unless _.find(@situation.research_centers, (center) ->
          center.location is destination
        )
      when "action_converge"
        thePlayer = @findPlayer(player)
        return false  if thePlayer.role isnt "Dispatcher"
        movedPlayerObject = @findPlayer(action.player)
        return false  unless @is_valid_player(action.player)
        return false  if movedPlayerObject.location is action.location
        return false  unless _.find(@situation.players, (player) ->
          player.location is action.location
        )
      when "action_treat_disease"
        thePlayer = @findPlayer(player)
        location = @findLocation(thePlayer.location)
        disease = @findDisease(action.disease)
        return false  if _.isUndefined(disease)
        return false  if location.infections[disease.name] is 0
      when "action_build_research_center"
        thePlayer = @findPlayer(player)
        return false  if @situation.research_centers_available is 0
        return false  if _.find(@situation.research_centers, (center) ->
          center.location is thePlayer.location
        )
        return false  if (thePlayer.role isnt "Operations Expert") and (not @getCard(thePlayer.hand, "location", thePlayer.location))
      when "action_discover_cure"
        self = this
        thePlayer = @findPlayer(player)
        return false  if ((thePlayer.role is "Scientist") and (action.cards.length isnt 4)) or ((thePlayer.role isnt "Scientist") and (action.cards.length isnt 5))
        cards = _.map(action.cards, (card) ->
          _.find thePlayer.hand, (handCard) ->
            _.isEqual handCard, card

        )
        return false  if _.some(cards, _.isUndefined)
        disease = self.findDiseaseByLocation(cards[0].location)
        return false  if disease.status isnt "no_cure"
        return false  unless _.every(cards, (card) ->
          self.findDiseaseByLocation(card.location) is disease
        )
      when "action_share_knowledge"
        from = @findPlayer(action.from_player)
        to = @findPlayer(action.to_player)
        return false  if not from or not to or from.id is to.id
        return false  unless @getCard(from.hand, "location", action.location)
        return false  if from.location isnt to.location
        return false  if from.role isnt "Researcher" and (from.location isnt action.location)
        return false  unless player is to.id or player is from.id
      when "special_airlift"
        return false  if @situation.state.name is "epidemic"
        thePlayer = @findPlayer(player)
        return false  unless @is_valid_player(action.player)
        movedPlayerObject = @findPlayer(action.player)
        return false  if movedPlayerObject.location is action.location
        return false  unless @getCard(thePlayer.hand, "special", action.name)
      when "special_government_grant"
        return false  if @situation.state.name is "epidemic"
        thePlayer = @findPlayer(player)
        return false  unless @getCard(thePlayer.hand, "special", action.name)
        return false  if @situation.research_centers_available is 0
        return false  if _.find(@situation.research_centers, (center) ->
          center.location is action.location
        )
      when "special_one_quiet_night"
        return false  if @situation.state.name is "epidemic"
        thePlayer = @findPlayer(player)
        return false  unless @getCard(thePlayer.hand, "special", action.name)
      when "draw_player_card"
        return false  if @situation.state.name isnt (action.name + "s")
        return false  if player isnt @situation.state.player
        # Defeat
        return true  unless @drawPlayerCard(player)
      when "draw_infection_card"
        return false  if @situation.state.name isnt (action.name + "s")
        return false  if player isnt @situation.state.player
        # Defeat
        return true  unless @drawInfection(1)
      when "discard_player_card"
        thePlayer = @findPlayer(player)
        return false  unless _.find(thePlayer.hand, (card) ->
          _.isEqual card, action.card
        )
      when "increase_infection_intensity"
        return false  if @situation.state.name isnt "epidemic"
        return false  if player isnt @situation.state.player
        return true
    true

  @eventRequriesApproval = (eventName) ->
    eventsThatRequireApproval = [
      "action_drive"
      "action_charter_flight"
      "action_direct_flight"
      "action_shuttle_flight"
      "action_converge"
      "special_airlift"
    ]
    _.contains eventsThatRequireApproval, eventName

  @emitMoveEventSink = (event_type, player, location) ->
    eventSink.emit
      event_type: event_type
      player: player
      location: location

    return

  @medicEndMoveSpecialEffect = ->
    
    # Cure all known diseases at this location withotu using a move action
    medic = _.find(@situation.players, (player) ->
      player.role is "Medic"
    )
    if medic
      location = @findLocation(medic.location)
      cured = _.filter(@situation.diseases, (disease) ->
        disease.status is "cure_discovered"
      )
      _.each cured, (disease) ->
        number = location.infections[disease.name]
        if number > 0
          location.infections[disease.name] -= number
          disease.cubes += number
          eventSink.emit
            event_type: "treat_disease"
            location: location.name
            disease: disease.name
            number: number

        return

    return

  @updateEradicatedDiseaseList = ->
    eradicated = _.filter(@situation.diseases, (disease) ->
      disease.status is "cure_discovered" and disease.cubes is disease.cubes_total
    )
    i = 0
    while i < eradicated.length
      disease = eradicated[i]
      disease.status = "eradicated"
      eventSink.emit
        event_type: "eradicate_disease"
        disease: disease.name

      i = i + 1
    return

  @getCard = (hand, attribute, targetToMatch) ->
    _.find hand, (card) ->
      card[attribute] is targetToMatch


  @movePawn = (newLocation, playerSelected, player, card) ->
    @discardPlayerCard player, card  if card and player
    @findPlayer(playerSelected).location = newLocation
    @emitMoveEventSink "move_pawn", playerSelected, newLocation
    return

  @performRegularAction = (thePlayer, playerSelected, approved, player, action) ->
    switch action.name
      when "action_pass"
        break;
      when "action_drive", "action_shuttle_flight", "action_converge"
        @movePawn action.location, playerSelected
      when "action_charter_flight"
        card = @getCard(thePlayer.hand, "location", thePlayer.location)
        @movePawn action.location, playerSelected, player, card
      when "action_direct_flight"
        card = @getCard(thePlayer.hand, "location", action.location)
        @movePawn action.location, playerSelected, player, card
      when "action_treat_disease"
        location = @findLocation(thePlayer.location)
        disease = @findDisease(action.disease)
        number = 1
        number = location.infections[disease.name]  if disease.status is "cure_discovered" or thePlayer.role is "Medic"
        location.infections[disease.name] -= number
        disease.cubes += number
        eventSink.emit
          event_type: "treat_disease"
          location: location.name
          disease: disease.name
          number: number

      when "action_build_research_center"
        if thePlayer.role isnt "Operations Expert"
          card = @getCard(thePlayer.hand, "location", thePlayer.location)
          @discardPlayerCard player, card
        eventSink.emit
          event_type: "build_research_center"
          location: thePlayer.location

        @situation.research_centers.push location: thePlayer.location
        @situation.research_centers_available = @situation.research_centers_available - 1
      when "action_discover_cure"
        disease = @findDiseaseByLocation(action.cards[0].location)
        self = this
        cards = _.map(action.cards, (card) ->
          _.find thePlayer.hand, (handCard) ->
            _.isEqual handCard, card

        )
        _.each cards, (card) ->
          self.discardPlayerCard player, card
          return

        disease.status = "cure_discovered"
        eventSink.emit
          event_type: "discover_cure"
          disease: disease.name

      when "action_share_knowledge"
        from = @findPlayer(action.from_player)
        to = @findPlayer(action.to_player)
        card = @getCard(from.hand, "location", action.location)
        other = (if player is to.id then from.id else to.id)
        unless approved
          @situation.state =
            name: "approve_action"
            player: player
            approve_player: other
            approve_action: action
            parent: @situation.state
            terminal: false

          @emitStateChange()
          return true
        from.hand.splice _.indexOf(from.hand, card), 1
        to.hand.push card
        eventSink.emit
          event_type: "transfer_player_card"
          from_player: from.id
          to_player: to.id
          card: card

        return @handleHandLimitExceeded(to.id)  if to.hand.length > @situation.max_player_cards
      else
        return false
    null

  @performSpecialAction = (playerSelected, playerSelectedObject, card, player, action) ->
    if action.name is "special_airlift"
      @discardPlayerCard player, card
      playerSelectedObject.location = action.location
      eventSink.emit
        event_type: "move_pawn"
        player: playerSelected
        location: action.location

    else if action.name is "special_government_grant"
      @discardPlayerCard player, card
      eventSink.emit
        event_type: "build_research_center"
        location: action.location

      @situation.research_centers.push location: action.location
      @situation.research_centers_available = @situation.research_centers_available - 1
    else if action.name is "special_one_quiet_night"
      @discardPlayerCard player, card
      eventSink.emit event_type: "one_quiet_night"
      @situation.quiet_night = true
    else if action.name is "special_resilient_population"
      @discardPlayerCard player, card
      eventSink.emit
        event_type: "discard_discarded_city"
        location: action.location

      @situation.infection_cards_discard = _.filter(@situation.infection_cards_discard, (card) ->
        card.location isnt action.location
      )
    else
      return false
    true

  @isRegulatoryCardAction = (actionName) ->
    regulatoryCardActions = [
      "draw_player_card"
      "discard_player_card"
      "increase_infection_intensity"
      "draw_infection_card"
    ]
    _.contains regulatoryCardActions, actionName

  @performRegulatoryCardAction = (player, action) ->
    thePlayer = @findPlayer(player)
    switch action.name
      when "draw_player_card"
        if @situation.state.draws_remaining is 0
          @startInfectionPhase player
        else if @situation.state.name is "draw_player_cards"
          @enterDrawState player, @situation.state.draws_remaining
        else
          @emitStateChange()
      when "discard_player_card"
        card = _.find(thePlayer.hand, (card) ->
          _.isEqual card, action.card
        )
        @discardPlayerCard player, card
        if (@situation.state.name is "hand_limit_exceeded") and (@situation.state.player is player) and (thePlayer.hand.length <= @situation.max_player_cards)
          if @situation.state.parent.name is "player_actions"
            @resumePlayerActions()
          else
            @resumeDrawPlayerCards()
      when "increase_infection_intensity"
        cards = randy.shuffle(@situation.infection_cards_discard)
        eventSink.emit
          event_type: "infection_cards_restack"
          cards: cards

        @situation.infection_cards_discard = []
        @situation.infection_cards_draw = cards.concat(@situation.infection_cards_draw)
        @resumeDrawPlayerCards()
      when "draw_infection_card"
        @situation.state.draws_remaining = @situation.state.draws_remaining - 1
        if @situation.state.draws_remaining is 0
          players = @situation.players
          index = _.indexOf(players, _.find(players, (p) ->
            p.id is player
          ))
          nextPlayer = (if index + 1 is players.length then players[0] else players[index + 1])
          @situation.state =
            name: "player_actions"
            player: nextPlayer.id
            actions_remaining: 4
            terminal: false
        @emitStateChange()

  @act = (player, action) ->
    return false  unless @check_action_prerequisites(player, action)
    if action.name is "refuse_action"
      @situation.state = @situation.state.parent
      @emitStateChange()
      return true
    approved = (action.name is "approve_action")
    if action.name is "approve_action"
      action = @situation.state.approve_action
      player = @situation.state.player
      @situation.state = @situation.state.parent
      eventSink.emit event_type: "approve_action"
    thePlayer = @findPlayer(player)
    return true  if @situation.state.name.match(/^defeat/)
    if action.name.match(/^action_/)
      playerSelected = action.player
      playerSelectedObject = @findPlayer(playerSelected)
      if not approved and (playerSelected isnt player) and @eventRequriesApproval(action.name)
        @requestApproval player, playerSelected, action
        return true
      action_result = @performRegularAction(thePlayer, playerSelected, approved, player, action)
      return action_result  unless action_result is null
      @situation.state.actions_remaining = @situation.state.actions_remaining - 1
      if @situation.state.actions_remaining is 0
        @enterDrawState player, 2
      else
        @emitStateChange()
    else if action.name.match(/^special_/)
      playerSelected = action.player
      playerSelectedObject = @findPlayer(playerSelected)
      if not approved and (playerSelected isnt player) and @eventRequriesApproval(action.name)
        @requestApproval player, playerSelected, action
        return true
      card = @getCard(thePlayer.hand, "special", action.name)
      return false  unless @performSpecialAction(playerSelected, playerSelectedObject, card, player, action)
    else if @isRegulatoryCardAction(action.name)
      @performRegulatoryCardAction player, action
    else
      return false
    @medicEndMoveSpecialEffect()
    @updateEradicatedDiseaseList()
    activeDisease = _.find(@situation.diseases, (disease) ->
      disease.status isnt "eradicated"
    )
    unless activeDisease
      @situation.state =
        name: "victory"
        terminal: true

      @emitStateChange()
    true

  this
_ = require("underscore")
clone = require("clone")
module.exports = Game
