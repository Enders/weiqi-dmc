defmodule WeiqiDMC.Player.MCRave do
  alias WeiqiDMC.Board
  alias WeiqiDMC.Board.State

  @constant_bias        0
  @heuristic_confidence 10

  defmodule WeiqiDMC.Player.MCRave.State do
    defstruct n: HashDict.new,
              q: HashDict.new,
              n_tilde: HashDict.new,
              q_tilde: HashDict.new,
              tree: nil
  end

  def board_hash(board) do
    #Copied from State.to_list ...
    #TODO: any other idea?
    board
      |> Dict.to_list
      |> Enum.map(fn ({row, column_dict}) ->
        column_dict
          |> Dict.to_list
          |> Enum.map(fn ({column, value}) ->
            {row, column, value}
          end)
      end)
  end

  def state_hash(state) do
    board_hash state.board
  end

  def generate_move(state, color, think_time_ms) do
    {mega, secs, micro} = :os.timestamp
    mc_rave_state = mc_rave {state, color},
                            {mega, secs, micro+think_time_ms*1000}, think_time_ms*1000,
                            %WeiqiDMC.Player.MCRave.State{tree: {state_hash(state), []}}
    select_move state, mc_rave_state
  end

  def mc_rave({initial_state, initial_color}, target_time, remaining_time, mc_rave_state) when remaining_time < 0 do
    mc_rave_state
  end

  def mc_rave(initial, target_time, remaining_time, mc_rave_state) do
    mc_rave initial, target_time, :timer.now_diff(target_time, :os.timestamp), simulate(initial, mc_rave_state)
  end

  def simulate({initial_state, initial_color}, mc_rave_state) do
    {known_states, known_actions, mc_rave_state} = sim_tree    [initial_state], [], mc_rave_state
    {missing_states, missing_actions, outcome}   = sim_default [(known_states|>List.first)], []
    backup mc_rave_state, known_states, known_actions, missing_actions, outcome
  end

  def backup(mc_rave_state, [], _, _, _) do mc_rave_state end
  def backup(mc_rave_state, [known_state|known_states], [known_action|known_actions], missing_actions, outcome) do
    state_hash = state_hash(known_state)
    key = {state_hash, known_action}
    updated_n = Dict.get(mc_rave_state.n, key, 0) + 1
    updated_q = (outcome - Dict.get(mc_rave_state.q, key, 0))/updated_n
    mc_rave_state = %{mc_rave_state | n: Dict.put(mc_rave_state.n, key, updated_n),
                                      q: Dict.put(mc_rave_state.n, key, updated_q) }

    all_actions = ([known_action|known_actions]++missing_actions)
    mc_rave_state = backup_tilde mc_rave_state, state_hash, all_actions, length(all_actions), outcome

    backup mc_rave_state, known_states, known_actions, missing_actions, outcome
  end

  #TODO: what does this do? Once you know, find a better name than the names
  #      from the algorithm.
  def backup_tilde(mc_rave_state, _, _, index, _) when index <= 0 do mc_rave_state end
  def backup_tilde(mc_rave_state, state_hash, all_actions, index, outcome) do
    u = length(all_actions) - index
    if u > 2 do
      action_u = Enum.at(all_actions, u)
      action_subset = all_actions |> Enum.slice(0..u-2) |> Enum.take_every 2
      if !Enum.member?(action_subset, action_u) do
        key = {state_hash, action_u}
        updated_n_tilde = Dict.get(mc_rave_state.n_tilde, key, 0) + 1
        updated_q_tilde = (outcome - Dict.get(mc_rave_state.q_tilde, key, 0))/updated_n_tilde
        mc_rave_state = %{mc_rave_state | n_tilde: Dict.put(mc_rave_state.n, key, updated_n_tilde),
                                          q_tilde: Dict.put(mc_rave_state.n, key, updated_q_tilde) }

      end
    end
    backup_tilde mc_rave_state, state_hash, all_actions, index - 2, outcome
  end

  def sim_tree([state|states], actions, mc_rave_state) do
    if game_over?(state) do
      {states, actions, mc_rave_state}
    else
      state_hash = state_hash state
      if !tree_member?(mc_rave_state.tree, state_hash) do
        parent_hash = states |> List.first |> state_hash
        new_action = default_policy(state)
        {[state|states], [new_action|actions], %{mc_rave_state | tree: tree_insert(mc_rave_state.tree, parent_hash, state_hash)}}
      else
        new_action = select_move(state, mc_rave_state)
        {:ok, new_state} = Board.compute_move(state, new_action, state.next_player)
        sim_tree [new_state|[state|states]], [new_action|actions], mc_rave_state
      end
    end
  end

  def sim_default([state|states], moves) do
    if game_over?(state) do
      {[state|states], moves, outcome?(state)}
    else
      new_action = default_policy(state)
      {:ok, new_state} = Board.compute_move(state, new_action, state.next_player)
      sim_default [new_state|[state|states]], [new_action|moves]
    end
  end

  def select_move(state, mc_rave_state) do
    legal_moves = legal_moves state, state.next_player
    if Enum.empty?(legal_moves) do
      :pass
    else
      state_hash = state_hash state
      if state.next_player == :black do
        Enum.max_by(legal_moves, fn(move) -> eval(state_hash, move, mc_rave_state) end)
      else
        Enum.min_by(legal_moves, fn(move) -> eval(state_hash, move, mc_rave_state) end)
      end
    end
  end

  def default_policy(state) do
    legal_moves = legal_moves state, state.next_player
    if Enum.empty?(legal_moves) do
      :pass
    else
      :random.seed(:os.timestamp)
      Enum.at legal_moves, :random.uniform(length(legal_moves)) - 1
    end
  end

  def eval(state_hash, action, mc_rave_state) do
    n_tilde = Dict.get(mc_rave_state.n_tilde, {state_hash, action}, 0)
    n = Dict.get(mc_rave_state.n, {state_hash, action}, 0)
    q = Dict.get(mc_rave_state.q, {state_hash, action}, 0)
    q_tilde = Dict.get(mc_rave_state.q_tilde, {state_hash, action}, 0)

    beta_denom = (n + n_tilde + 4*n_tilde*n*@constant_bias*@constant_bias)
    if beta_denom > 0 do
      beta = n_tilde / beta_denom
    else
      beta = 0
    end

    (1.0-beta) * q + beta * q_tilde
  end

  def new_node({state, color}, parent, mc_rave_state) do
    board_hash  = board_hash state.board
    legal_moves = legal_moves(state, color)

    #TODO: extract that 0.5 to a function, it's the heuristic H(s,a), 0.5 -> Qeven
    new_q_tilde = set_base_values mc_rave_state.q_tilde, legal_moves, board_hash, 0.5
    new_q       = set_base_values mc_rave_state.q,       legal_moves, board_hash, 0.5
    new_n_tilde = set_base_values mc_rave_state.n_tilde, legal_moves, board_hash, @heuristic_confidence
    new_n       = set_base_values mc_rave_state.n,       legal_moves, board_hash, @heuristic_confidence

    %{ mc_rave_state | q_tilde: new_q_tilde, q: new_q, n: new_n, n_tilde: new_n_tilde,
                       tree: tree_insert(mc_rave_state.tree, parent, {board_hash, state.board}) }
  end

  def set_base_values(state_component, [], _, _) do state_component end
  def set_base_values(state_component, [action|actions], state_hash, value) do
    set_base_values Dict.put(state_component, {state_hash, action}, value), actions, state_hash, value
  end

  #Tree processing
  #---------------

  def tree_insert({root, children}, parent, node) do
    if root == parent do
      {root, [{node, []}|children]}
    else
      children = children |> Enum.map(fn (child) ->
        tree_insert(child, parent, node)
      end)
      {root, children}
    end
  end

  def tree_member?({state_hash, []}, needle) do state_hash == needle end
  def tree_member?({state_hash, children}, needle) do
    state_hash == needle or Enum.any?(children, fn (child) -> tree_member?(child, needle) end)
  end

  #Game utilities
  #--------------

  def outcome?(state) do
    if black_wins?(state) do 1 else 0 end
  end

  def black_wins?(state) do
    count_stones(state, :black) > count_stones(state, :white) + state.komi
  end

  def count_stones(state, color) do
    State.to_list(state.board)
      |> Enum.filter(fn({_,_,value}) -> value == color end)
      |> Enum.count
  end

  def game_over?(state) do
    #The game finishes when all the groups are alive
    #Here, alive is simplified to -> 2 non-contiguous liberties ("eyes")
    #TODO: prove it!
    state.groups |> Enum.all?(fn({_, _, liberties}) ->
      length(liberties) == 2 and !Board.contiguous?(Enum.at(liberties, 0), Enum.at(liberties, 1))
    end)
  end

  def legal_moves(state, color) do
    state.board
      |> State.empty_coordinates
      |> Enum.filter(&Board.valid_move?(state, &1, color))
  end
end