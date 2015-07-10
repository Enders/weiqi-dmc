defmodule WeiqiDMC.Player.MCRave do
  alias WeiqiDMC.Board
  alias WeiqiDMC.Board.State

  @constant_bias        1
  @heuristic_confidence 5

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

  #Useful for testing
  def state_hash(state) when is_atom(state) do state end
  def state_hash(state) do
    state.board
  end

  def generate_move(state, think_time_ms) do
    :random.seed(:os.timestamp)
    {mega, secs, micro} = :os.timestamp
    {mc_rave_state, stats} = mc_rave state,
                             {mega, secs, micro+think_time_ms*1000}, think_time_ms*1000,
                             %WeiqiDMC.Player.MCRave.State{},
                             0

    #IO.puts "Simulation: #{stats}"

    select_move state, mc_rave_state
  end

  def mc_rave(_, _, remaining_time, mc_rave_state, stats) when remaining_time < 0 do
    {mc_rave_state, stats}
  end

  def mc_rave(state, target_time, _, mc_rave_state, stats) do
    mc_rave state, target_time, :timer.now_diff(target_time, :os.timestamp), simulate(state, mc_rave_state), stats + 1
  end

  def simulate(state, mc_rave_state) do
    {known_states, known_actions, mc_rave_state} = sim_tree [state], [], mc_rave_state
    {missing_actions, outcome} = sim_default List.last(known_states), []
    backup mc_rave_state, known_states, known_actions, missing_actions, outcome
  end

  def backup(mc_rave_state, [], _, _, _) do mc_rave_state end
  def backup(mc_rave_state, [known_state|known_states], [known_action|known_actions], missing_actions, outcome) do
    state_hash = state_hash(known_state)
    key = {state_hash, known_action}
    updated_n = Dict.get(mc_rave_state.n, key, 0) + 1
    updated_q = Dict.get(mc_rave_state.q, key, 0) + (outcome - Dict.get(mc_rave_state.q, key, 0))/updated_n

    mc_rave_state = %{mc_rave_state | n: Dict.put(mc_rave_state.n, key, updated_n),
                                      q: Dict.put(mc_rave_state.q, key, updated_q) }

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
        updated_q_tilde = Dict.get(mc_rave_state.q_tilde, key, 0) + (outcome - Dict.get(mc_rave_state.q_tilde, key, 0))/updated_n_tilde
        mc_rave_state = %{mc_rave_state | n_tilde: Dict.put(mc_rave_state.n_tilde, key, updated_n_tilde),
                                          q_tilde: Dict.put(mc_rave_state.q_tilde, key, updated_q_tilde) }

      end
    end
    backup_tilde mc_rave_state, state_hash, all_actions, index - 2, outcome
  end

  def sim_tree([state|states], actions, mc_rave_state) do
    if game_over?(state) do
      {Enum.reverse(states), Enum.reverse(actions), mc_rave_state}
    else
      state_hash = state_hash state
      if !tree_member?(mc_rave_state.tree, state_hash) do
        parent_hash = states |> List.first |> state_hash
        new_action = default_policy(state)
        {Enum.reverse([state|states]), Enum.reverse([new_action|actions]), new_node(state, parent_hash, mc_rave_state)}
      else
        new_action = select_move(state, mc_rave_state)
        {:ok, new_state} = Board.compute_move(state, new_action, state.next_player)
        sim_tree [new_state|[state|states]], [new_action|actions], mc_rave_state
      end
    end
  end

  def sim_default(from_state, moves) do
    if game_over?(from_state) do
      {moves, outcome?(from_state)}
    else
      new_action = default_policy(from_state)
      {:ok, new_state} = Board.compute_move(from_state, new_action, from_state.next_player)
      sim_default new_state, moves ++ [new_action]
    end
  end

  def select_move(state, mc_rave_state) do
    legal_moves = legal_moves state
    state_hash = state_hash state

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
    interesting_moves = legal_moves(state)
      |> Enum.filter(fn coordinate -> !ruin_perfectly_good_eye?(state, coordinate) end)

    if Enum.empty?(interesting_moves) do
      :pass
    else
      Enum.at interesting_moves, :random.uniform(length(interesting_moves)) - 1
    end
  end

  def ruin_perfectly_good_eye?(state, coordinate) do
    if Enum.empty?(state.groups) do
      false
    else
      coordinate_set = Set.put(HashSet.new, coordinate)

      #Would this move save from an atari? (it's assumed it's a legal move == not a suicide)
      last_liberty_own_group = Enum.any?(state.groups, fn {color, _, liberties} ->
        color == state.next_player and liberties == coordinate_set
      end)

      !last_liberty_own_group and Board.is_eyeish_for?(state.next_player, state, coordinate)
    end
  end

  def eval(state_hash, action, mc_rave_state) do
    n       = Dict.get(mc_rave_state.n, {state_hash, action}, 0)
    q       = Dict.get(mc_rave_state.q, {state_hash, action}, 0)
    n_tilde = Dict.get(mc_rave_state.n_tilde, {state_hash, action}, 0)
    q_tilde = Dict.get(mc_rave_state.q_tilde, {state_hash, action}, 0)

    beta_denom = (n + n_tilde + 4*n_tilde*n*@constant_bias*@constant_bias)
    if beta_denom > 0 do
      beta = n_tilde / beta_denom
    else
      beta = 0
    end

    (1.0-beta) * q + beta * q_tilde
  end

  def new_node(state, parent_hash, mc_rave_state) do
    state_hash  = state_hash state
    legal_moves = legal_moves state

    #TODO: extract that 0.5 to a function, it's the heuristic H(s,a), 0.5 -> Qeven
    new_q_tilde = set_base_values mc_rave_state.q_tilde, legal_moves, state_hash, 0.5
    new_q       = set_base_values mc_rave_state.q,       legal_moves, state_hash, 0.5
    new_n_tilde = set_base_values mc_rave_state.n_tilde, legal_moves, state_hash, @heuristic_confidence
    new_n       = set_base_values mc_rave_state.n,       legal_moves, state_hash, @heuristic_confidence

    %{ mc_rave_state | q_tilde: new_q_tilde, q: new_q, n: new_n, n_tilde: new_n_tilde,
                       tree: tree_insert(mc_rave_state.tree, parent_hash, state_hash) }
  end

  def set_base_values(state_component, [], _, _) do state_component end
  def set_base_values(state_component, [action|actions], state_hash, value) do
    set_base_values Dict.put(state_component, {state_hash, action}, value), actions, state_hash, value
  end

  #Tree processing
  #---------------

  def tree_insert(nil, _, node) do {node, []} end
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

  def tree_member?(nil, _) do false end
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
    count_stones(state, :black)  > count_stones(state, :white) + state.komi
  end

  def count_stones(state, color) do
    state.groups
      |> Enum.map(fn({value, coordinates, _}) -> (value == color and coordinates) || HashSet.new end)
      |> Enum.reduce(HashSet.new, fn (coordinates, acc) -> Set.union(acc, coordinates) end)
      |> Set.size
  end

  def game_over?(state) do
    state.consecutive_pass
  end

  def legal_moves(state) do
    state
      |> State.empty_coordinates
      |> Enum.filter(&Board.valid_move?(state, &1))
  end
end