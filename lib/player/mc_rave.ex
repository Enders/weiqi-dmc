defmodule WeiqiDMC.Player.MCRave do
  alias WeiqiDMC.Board
  alias WeiqiDMC.Board.State

  import WeiqiDMC.Board.Outcome, only: [outcome?: 1, game_over?: 1]
  import WeiqiDMC.Board.Reading, only: [ruin_perfectly_good_eye?: 2, self_atari?: 2]

  @workers              10
  @random_per_sim       20
  @constant_bias        0.5
  @heuristic_confidence 10

  #Useful for testing
  def state_hash(state) when is_atom(state) do state end
  def state_hash(state) do state.board end

  def generate_move(state, think_time_ms, show_stats \\ false) do
    :random.seed(:os.timestamp)

    workers  = spawn_mc_rave_workers @workers, []
    {:ok, mc_rave_state_agent} = Agent.start_link(fn -> %WeiqiDMC.Player.MCRave.State{} end)

    Enum.each workers, fn (worker) ->
      send worker, {:compute, self, mc_rave_state_agent, state}
    end

    generate_move_loop state, mc_rave_state_agent, :erlang.system_time(:micro_seconds) + think_time_ms*1000, think_time_ms*1000, show_stats
  end

  def generate_move_loop(state, mc_rave_state_agent, _, remaining_time, show_stats) when remaining_time <= 0 do
    mc_rave_state = Agent.get(mc_rave_state_agent, &(&1))
    if show_stats do
      show_stats(state, mc_rave_state)
    end
    select_move state, mc_rave_state, true
  end

  def generate_move_loop(state, mc_rave_state_agent, target_time, remaining_time, show_stats) do
    receive do
      {:computed, worker, {known_states, known_actions, missing_actions, new_node, outcome}} ->
        Agent.update(mc_rave_state_agent, fn (mc_rave_state) ->
          unless new_node == nil do
            {state, parent_hash} = new_node
            mc_rave_state = new_node(state, parent_hash, mc_rave_state)
          end
          backup mc_rave_state, known_states, known_actions, missing_actions, outcome
        end)
        send worker, {:compute, self, mc_rave_state_agent, state}
        generate_move_loop state, mc_rave_state_agent, target_time, target_time - :erlang.system_time(:micro_seconds), show_stats
      received ->
        IO.inspect {:supervisor, self, :received_unknown, received}
        generate_move_loop state, mc_rave_state_agent, target_time, remaining_time - 100, show_stats
      after
        remaining_time ->
          generate_move_loop state, mc_rave_state_agent, target_time, 0, show_stats
    end
  end

  def spawn_mc_rave_workers(0, spawned) do spawned end
  def spawn_mc_rave_workers(to_spawn, spawned) do
    pid = spawn_link &WeiqiDMC.Player.MCRave.Worker.compute/0
    spawn_mc_rave_workers to_spawn - 1, [pid|spawned]
  end

  def show_stats(state, mc_rave_state) do
    IO.puts "\nMove generation"
    IO.puts "---------------"

    IO.puts State.to_string(state)

    state_hash = state_hash state

    Dict.keys(mc_rave_state.q) |> Enum.each(fn {hash, move} ->
      if hash == state_hash do
        n    = Dict.get(mc_rave_state.n, {hash, move}, 0)
        q    = Dict.get(mc_rave_state.q, {hash, move}, 0)
        eval = eval(hash, move, mc_rave_state)
        IO.puts "#{WeiqiDMC.Helpers.coordinate_tuple_to_string(move)} -> N=#{n}, Q=#{q}, Eval=#{eval}"
      end
    end)

    move = select_move state, mc_rave_state, true
    IO.puts "Total simulation: #{mc_rave_state.simulations}"
    IO.puts "Selected moved: #{WeiqiDMC.Helpers.coordinate_tuple_to_string(move)} \n\n"
  end

  def simulate(state, mc_rave_state) do
    {known_states, known_actions, new_node} = sim_tree [state], [], mc_rave_state
    {missing_actions, outcome}              = multiple_sim_default List.last(known_states), HashSet.new, @random_per_sim, @random_per_sim, 0
    {known_states, known_actions, Set.to_list(missing_actions), new_node, outcome}
  end

  def backup(mc_rave_state, [], _, _, _) do
    %{mc_rave_state | simulations: mc_rave_state.simulations + 1}
  end

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
      {Enum.reverse(states), Enum.reverse(actions), nil}
    else
      state_hash = state_hash state
      if !tree_member?(mc_rave_state.tree, state_hash) do
        parent_hash = states |> List.first |> state_hash
        {new_action, _} = default_policy(state)
        {Enum.reverse([state|states]), Enum.reverse([new_action|actions]), {state, parent_hash}}
      else
        new_action = select_move(state, mc_rave_state, false)
        {:ok, new_state} = Board.compute_move(state, new_action, state.next_player)
        sim_tree [new_state|[state|states]], [new_action|actions], mc_rave_state
      end
    end
  end

  def multiple_sim_default(_, moves, total_simulation, 0, total_outcome) do
    {moves, round(total_outcome/total_simulation)}
  end

  def multiple_sim_default(from_state, moves, total_simulation, remaining_simulation, total_outcome) do
    {new_moves, outcome} = sim_default from_state, []
    multiple_sim_default from_state, Set.union(moves, Enum.into(new_moves, HashSet.new)),
                         total_simulation, remaining_simulation - 1, total_outcome + outcome
  end

  def sim_default(from_state, moves) do
    if game_over?(from_state) do
      {moves, outcome?(from_state)}
    else
      {coordinate, precomputed} = default_policy(from_state)
      {:ok, new_state} = case {coordinate, precomputed} do
        {:pass, _} -> Board.compute_move(from_state, :pass)
        {coordinate, precomputed} -> Board.compute_valid_move(from_state, coordinate, precomputed)
      end
      sim_default new_state, moves ++ [coordinate]
    end
  end

  def select_move(state, mc_rave_state, allow_resign) do
    state_hash = state_hash state
    considered_moves = Dict.keys(mc_rave_state.q)
      |> Enum.filter_map(fn {hash, _} -> hash == state_hash end,
                         fn {_, move} -> move end)

    if Enum.empty?(considered_moves) do
      :pass
    else
      state_hash = state_hash state
      if state.next_player == :black do
        move = Enum.max_by(considered_moves, fn(move) -> eval(state_hash, move, mc_rave_state) end)
        if allow_resign and eval(state_hash, move, mc_rave_state) < 0.3 do
          :resign
        else
          move
        end
      else
        move = Enum.min_by(considered_moves, fn(move) -> eval(state_hash, move, mc_rave_state) end)
        if allow_resign and eval(state_hash, move, mc_rave_state) > 0.7 do
          :resign
        else
          move
        end
      end
    end
  end

  def default_policy(state) do
    default_policy state, State.empty_coordinates(state)
  end

  def default_policy(_, []) do {:pass, nil} end
  def default_policy(state, candidates) do
    move = Enum.at candidates, :random.uniform(length(candidates)) - 1
    if !self_atari?(state, move) and !ruin_perfectly_good_eye?(state, move) do
      case Board.pre_compute_valid_move(state, move, true) do
        {:ok, computed} -> {move, computed}
        {:ko, nil} -> default_policy(state, candidates -- [move])
      end
    else
      default_policy state, candidates -- [move]
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

    #TODO: maybe just use empty coordinates
    legal_moves = state
      |> State.empty_coordinates
      |> Enum.filter(&Board.valid_move?(state, &1))

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
end