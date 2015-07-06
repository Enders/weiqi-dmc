defmodule WeiqiDMC.Board do

  alias WeiqiDMC.Board.State
  alias WeiqiDMC.Helpers

  def start_link do
    Agent.start_link fn -> %State{size: 19, board: State.empty_board(19)} end
  end

  #GTP API
  #--------

  #TODO: move into gtp_commands instead?

  def state(board_agent) do
    Agent.get(board_agent, &(&1))
  end

  def showboard(board_agent) do
    WeiqiDMC.Board.State.to_string Agent.get(board_agent, &(&1))
  end

  def clear_board(board_agent) do
    Agent.update board_agent, fn state -> %State{ board: State.empty_board(state.size),
                                                  size:  state.size } end
  end

  def change_size(board_agent, size) do
    cond do
      Enum.member?([9,13,19], size) ->
        Agent.update board_agent, fn _ -> %State{ board: State.empty_board(size),
                                                  size:  size } end
      true -> :ko
    end
  end

  def generate_move(board_agent, color) do
    state = Agent.get(board_agent, &(&1))
    case WeiqiDMC.Player.generate_move(state, Helpers.normalize_color(color)) do
      :resign -> "resign"
      :pass ->
        play_move(board_agent, "pass", color)
        "pass"
      {row, column} ->
        coordinate = Helpers.coordinate_tuple_to_string {row, column}
        case play_move(board_agent, coordinate, color) do
          {:ok, _} -> coordinate
          {:ko, _} -> "resign"
        end
    end
  end

  def change_komi(board_agent, komi) do
    Agent.update board_agent, fn state -> %{state | komi: komi } end
  end

  def set_handicap(_, handicap) when handicap < 2 or handicap > 9 do
    :ko
  end

  def set_handicap(board_agent, handicap) do
    %WeiqiDMC.Board.State{size: size} = Agent.get(board_agent, &(&1))
    play_moves board_agent, Helpers.handicap_coordinates(size, handicap), :black
  end

  def play_moves(board_agent, moves, color) do
    state = Agent.get(board_agent, &(&1))
    coordinates = moves |> Enum.map(&Helpers.coordinate_string_to_tuple(&1))
    case compute_moves(state, coordinates, Helpers.normalize_color(color)) do
      {:ok, state} -> Agent.update board_agent, fn _ -> state end
      {:ko, _ }    -> :ko
    end
  end

  def play_move(board_agent, "pass", color) do
    state = Agent.get(board_agent, &(&1))
    updated_state = %{state | moves: state.moves ++ [(color |> String.downcase |> String.first) <> " pass"]}
    Agent.update board_agent, fn _ -> updated_state end
    {:ok, updated_state}
  end

  def play_move(board_agent, coordinate, color) do
    state = Agent.get(board_agent, &(&1))
    case compute_move(state, Helpers.coordinate_string_to_tuple(coordinate), Helpers.normalize_color(color)) do
      {:ok, state} ->
        Agent.update board_agent, fn _ -> %{state | moves: state.moves ++ [coordinate]} end
        {:ok, state}
      {:ko, _ }    -> {:ko, state}
    end
  end

  #Board API
  #---------

  def compute_moves(state, [], _) do
    {:ok, state}
  end

  def compute_moves(state, [coordinate|rest], color) do
    case compute_move(state, coordinate, color) do
      {:ok, state} -> compute_moves(state, rest, color)
      {:ko, _ }    -> {:ko, state }
    end
  end

  def compute_move(state, coordinate, color) do
    if State.board_value(state.board, coordinate) != :empty do
      {:ko, state}
    else
      compute_valid_move state, coordinate, color
    end
  end

  def compute_valid_move(state, coordinate, color) do

    surroundings = surroundings coordinate, state.size

    empty        = surroundings |> Enum.filter(fn (surrounding) -> State.board_value(state.board, surrounding) == :empty end)

    other_player = surroundings |> Enum.filter(fn (surrounding) -> State.board_value(state.board, surrounding) == Helpers.opposite_color(color) end)
                                |> Enum.map(&group_containing(&1, state.groups))
                                |> Enum.uniq

    same_player  = surroundings |> Enum.filter(fn (surrounding) -> State.board_value(state.board, surrounding) == color end)
                                |> Enum.map(&group_containing(&1, state.groups))
                                |> Enum.uniq

    liberties_same_player_group = Enum.map(same_player, fn ({_, _, liberties}) ->
        length Enum.filter(liberties, fn (liberty) -> liberty != coordinate end)
      end) |> Enum.sum

    capturing = Enum.filter(other_player, fn({_, _, liberties}) ->
      liberties == [coordinate]
    end)

    cond do
      liberties_same_player_group < 1 and length(empty) == 0 and length(capturing) == 0 ->
        {:ko, state}
      true ->
        {board, groups}           = process_move(state.board, state.groups, coordinate, color, empty)
        {board, groups, captured} = process_capture(board, groups, capturing, 0)

        #TODO: extract so it can also be called when passing
        if state.coordinate_ko do
          board = State.update_board board, state.coordinate_ko, :empty
        end
        if captured == 1 do
          coordinate_ko = capturing |> List.first |> elem(1) |> List.first
          board = State.update_board board, coordinate_ko, :ko
        else
          coordinate_ko = nil
        end

        {:ok,  %{state | board: board,
                         groups: groups,
                         coordinate_ko: coordinate_ko,
                         captured_white: state.captured_white + (if color == :black do captured else 0 end),
                         captured_black: state.captured_black + (if color == :white do captured else 0 end) } }
    end
  end

  def group_containing(coordinate, groups) do
    Enum.find groups, fn ({_, coordinates, _}) ->
      Enum.member? coordinates, coordinate
    end
  end

  def process_move(board, groups, coordinate, color, move_liberties) do
    #Remove the move in the list of liberties for opposite color groups
    groups = groups |>
      Enum.map(fn ({group_color, coordinates, liberties}) ->
        if group_color == Helpers.opposite_color(color) and Enum.member?(liberties, coordinate) do
            {group_color, coordinates, liberties -- [coordinate]}
        else
          {group_color, coordinates, liberties }
        end
      end)

    #For same group color, find all the groups that have this move as liberty
    #and put them in a list to be merged.
    to_merge = groups |> Enum.filter(fn ({group_color, _, liberties}) ->
      group_color == color and Enum.member?(liberties, coordinate)
    end)

    if !Enum.empty?(to_merge) do
      coordinates = to_merge |> Enum.map(fn ({_, coordinates, _}) -> coordinates end)
                             |> List.flatten
                             |> Enum.uniq
      liberties   = to_merge |> Enum.map(fn ({_, _, liberties}) -> liberties end)
                             |> List.flatten
                             |> Enum.uniq

      merged = {color, [coordinate|coordinates], Enum.uniq((liberties ++ move_liberties) -- [coordinate])}
      groups = (groups -- to_merge) ++ [merged]
    else
      groups = groups ++ [{color, [coordinate], move_liberties}]
    end

    { State.update_board(board, coordinate, color), groups }
  end

  def process_capture(board, groups, [], captured) do
    {board, groups, captured}
  end

  def process_capture(board, groups, [{_, coordinates, _}|rest], captured) do
    {board, groups} = process_capture_group(board, groups, coordinates)
    process_capture board, groups, rest, captured + length(coordinates)
  end

  def process_capture_group(board, groups, []) do
    {board, groups}
  end

  def process_capture_group(board, groups, [capture|rest]) do
    #Remove all the groups containing the removed stone
    groups = groups |> Enum.reject(fn ({_, coordinates, _}) ->
      Enum.member?(coordinates, capture)
    end)

    surroundings = surroundings capture, State.board_size(board)

    #Add liberties to the surrounding groups
    groups = groups |> Enum.map(fn ({color, coordinates, liberties}) ->
      if coordinates -- surroundings != coordinates do
        {color, coordinates, Enum.uniq(liberties ++ [capture])}
      else
        {color, coordinates, liberties}
      end
    end)

    process_capture_group State.update_board(board, capture, :empty), groups, rest
  end

  defp surroundings(coordinate, size) do
    [{-1, 0}, {1, 0}, {0, 1}, {0, -1}]
      |> Enum.map(&compute_coordinate_from_delta(&1, coordinate, size))
      |> Enum.filter(fn (surrounding) -> surrounding != :invalid end)
  end

  defp compute_coordinate_from_delta({delta_row, delta_column}, {row, column}, size) do
    cond do
      row+delta_row < 1 or row+delta_row > size             -> :invalid
      column+delta_column < 1 or column+delta_column > size -> :invalid
      true -> {row+delta_row, column+delta_column}
    end
  end
end